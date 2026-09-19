import { task, types } from 'hardhat/config'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

/**
 * Report every lender pool on a chain that can be over-borrowed against.
 *
 * WHAT THE CAP DOES. A pool prices collateral off its Uniswap TWAP, clamped:
 *
 *   principalPerCollateral = maxPrincipalPerCollateralAmount == 0
 *     ? oracle
 *     : min(oracle, maxPrincipalPerCollateralAmount)
 *
 * Zero is not "no opinion", it is "believe the oracle without limit". The
 * direction an attacker pushes a TWAP is up, because collateral quoted too
 * high borrows more than it is worth, so an uncapped pool holding real
 * principal is the shape of the loss. The cap is the only thing standing
 * between a thin oracle pool and the lenders' money.
 *
 * WHY IT ENUMERATES FROM THE FACTORY. set-pool-price-caps walks
 * market-bootstrap.json, which exists only for the chains bootstrapped through
 * that task - so it cannot see a pool it did not create. HyperEVM has fourteen
 * live pools and no receipt at all, which is exactly the blind spot a monitor
 * must not inherit. The factory's DeployedLenderGroupContract log is the one
 * list that is complete by construction.
 *
 * WHY IT REPORTS THE OWNER. setMaxPrincipalPerCollateralAmount is onlyOwner,
 * and the pools on a chain are not all owned by us - HyperEVM's xHYPE pool
 * belongs to a partner. An alert that says "uncapped" without saying whose job
 * it is to fix is an alert nobody acts on.
 *
 * SEVERITY. `critical` is a pool with principal available to borrow and no cap.
 * `warn` is a cap far enough from the live oracle to be worth a look - too high
 * to bind, or so low it is quietly refusing honest borrowers. Everything else
 * is `ok`. The task exits non-zero when anything is critical, so a scheduler
 * can treat the exit code as the alert.
 *
 *   yarn hh audit-pool-caps --network hyperevm
 *   yarn hh audit-pool-caps --network arc --json true
 */

const POOL_ABI = [
  'function principalToken() view returns (address)',
  'function collateralToken() view returns (address)',
  'function owner() view returns (address)',
  'function maxPrincipalPerCollateralAmount() view returns (uint256)',
  'function getPrincipalAmountAvailableToBorrow() view returns (uint256)',
  'function totalPrincipalTokensCommitted() view returns (uint256)',
  'function collateralRatio() view returns (uint16)',
  'function UNISWAP_PRICING_HELPER() view returns (address)',
  // `poolOracleRoutes` is a public array, so the generated getter answers one
  // entry at a time and reverts past the end - there is no whole-array getter.
  // Read until it reverts, exactly as set-pool-price-caps does.
  'function poolOracleRoutes(uint256) view returns (address pool, bool zeroForOne, uint32 twapInterval, uint256 token0Decimals, uint256 token1Decimals)',
]
const ERC20_ABI = [
  'function symbol() view returns (string)',
  'function decimals() view returns (uint8)',
]
const PRICING_ABI = [
  'function getUniswapPriceRatioForPoolRoutes((address,bool,uint32,uint256,uint256)[] poolRoutes) view returns (uint256)',
]

type Severity = 'critical' | 'warn' | 'ok'

interface Finding {
  pool: string
  pair: string
  owner: string
  availableRaw: string
  available: string
  principalSymbol: string
  cap: string
  oracle: string | null
  capOverOracle: number | null
  severity: Severity
  note: string
}

const units = (raw: bigint, decimals: number): string => {
  const d = BigInt(10) ** BigInt(decimals)
  const frac = (raw % d).toString().padStart(decimals, '0').replace(/0+$/, '')
  return frac ? `${raw / d}.${frac.slice(0, 6)}` : `${raw / d}`
}

task(
  'audit-pool-caps',
  'Report lender pools whose maxPrincipalPerCollateralAmount leaves them open to an inflated oracle'
)
  .addOptionalParam(
    'minAvailable',
    'Ignore pools with less than this much principal available to borrow, in whole units. ' +
      'A dust pool with no cap is untidy; one with real principal is an incident.',
    1,
    types.float
  )
  .addOptionalParam(
    'driftPct',
    'Flag a cap that sits further than this percentage from the live oracle reading',
    25,
    types.float
  )
  .addOptionalParam(
    'fromBlock',
    "First block to scan the factory from. Defaults to the factory's own " +
      'deployment block, the first block that could carry one of its logs.',
    0,
    types.int
  )
  .addOptionalParam(
    'chunk',
    'Largest block window to request logs for. Halved automatically when a ' +
      'provider refuses the range, so it is a starting guess rather than a limit.',
    500000,
    types.int
  )
  .addOptionalParam(
    'pools',
    'Comma-separated pool addresses to audit instead of scanning for them.',
    '',
    types.string
  )
  .addOptionalParam(
    'json',
    'Emit machine-readable JSON instead of a table',
    false,
    types.boolean
  )
  .setAction(async (args, hre: HardhatRuntimeEnvironment): Promise<void> => {
    const { ethers } = hre

    const factory = await hre.deployments.getOrNull(
      'LenderCommitmentGroupFactory_V2'
    )
    if (!factory) {
      throw new Error(
        `No LenderCommitmentGroupFactory_V2 deployment for ${hre.network.name}; nothing to enumerate.`
      )
    }

    // Every pool the factory ever made, which is the only list that is complete
    // by construction. A receipt only knows the pools its own task created, and
    // the factory's own `deployedLenderGroupContracts` is a mapping - it can say
    // whether an address is one of its pools but cannot list them.
    const iface = new ethers.Interface([
      'event DeployedLenderGroupContract(address indexed groupContract)',
    ])
    const topic = iface.getEvent('DeployedLenderGroupContract')!.topicHash
    const latest = await ethers.provider.getBlockNumber()

    const explicit = String(args.pools ?? '')
      .split(',')
      .map((p) => p.trim())
      .filter(Boolean)
      .map((p) => ethers.getAddress(p))

    let pools: string[] = explicit

    if (explicit.length === 0) {
      // Start where the factory started. Nothing before its deployment block can
      // carry one of its logs, and on a chain whose head is tens of millions of
      // blocks up that is most of the range gone for nothing.
      const deployedAt = (factory as { receipt?: { blockNumber?: number } })
        .receipt?.blockNumber
      const from = (args.fromBlock as number) || deployedAt || 0

      // Providers cap eth_getLogs differently and rarely advertise it -
      // hyperliquid's public RPC refuses anything over 1000 blocks, which is how
      // the first run of this died with "query exceeds max block range 1000".
      // Rather than carry a limit per chain, start wide and halve on refusal,
      // keeping whatever window works: a range-capable endpoint finishes in a
      // handful of requests, a strict one still finishes.
      const isRangeError = (err: unknown): boolean =>
        /range|too many blocks|block range|limit exceeded|more than/i.test(
          (err as Error)?.message ?? ''
        )

      let window = Math.max(1, args.chunk as number)
      let requests = 0
      let logCount = 0
      const seen = new Set<string>()
      let cursor = from
      while (cursor <= latest) {
        const to = Math.min(cursor + window - 1, latest)
        try {
          const found = await ethers.provider.getLogs({
            address: factory.address,
            topics: [topic],
            fromBlock: cursor,
            toBlock: to,
          })
          requests++
          logCount += found.length
          for (const l of found) {
            seen.add(ethers.getAddress('0x' + l.topics[1].slice(26)))
          }
          cursor = to + 1
        } catch (err) {
          if (!isRangeError(err) || window === 1) throw err
          window = Math.max(1, Math.floor(window / 2))
        }
      }
      pools = [...seen]

      if (!args.json) {
        hre.log(`Pool cap audit on ${hre.network.name}`, { star: true })
        hre.log(`  factory ${factory.address}`)
        hre.log(
          `  scanned ${from}..${latest} in ${requests} request(s), window ${window}`
        )
        hre.log(`  pools   ${pools.length} (from ${logCount} deployment logs)`)
        hre.log('')
      }
    } else if (!args.json) {
      hre.log(`Pool cap audit on ${hre.network.name}`, { star: true })
      hre.log(`  factory ${factory.address}`)
      hre.log(`  pools   ${pools.length} (given explicitly, no scan)`)
      hre.log('')
    }

    const symbolOf = async (address: string): Promise<[string, number]> => {
      try {
        const t = await ethers.getContractAt(ERC20_ABI, address)
        return [(await t.symbol()) as string, Number(await t.decimals())]
      } catch {
        return [address.slice(0, 8), 18]
      }
    }

    const findings: Finding[] = []
    for (const address of pools) {
      const pool = await ethers.getContractAt(POOL_ABI, address)
      let principal: string
      let collateral: string
      let owner: string
      let cap: bigint
      let available: bigint
      try {
        ;[principal, collateral, owner, cap, available] = await Promise.all([
          pool.principalToken() as Promise<string>,
          pool.collateralToken() as Promise<string>,
          pool.owner() as Promise<string>,
          pool.maxPrincipalPerCollateralAmount() as Promise<bigint>,
          pool.getPrincipalAmountAvailableToBorrow() as Promise<bigint>,
        ])
      } catch (err) {
        // A pool that cannot answer these is not a pool this audit understands;
        // say so rather than dropping it silently from a security report.
        findings.push({
          pool: address,
          pair: 'unreadable',
          owner: '?',
          availableRaw: '0',
          available: '?',
          principalSymbol: '?',
          cap: '?',
          oracle: null,
          capOverOracle: null,
          severity: 'warn',
          note: `could not read pool state: ${(err as Error).message.slice(0, 80)}`,
        })
        continue
      }

      const [ps, pd] = await symbolOf(principal)
      const [cs] = await symbolOf(collateral)

      // The unclamped reading, from the pricing library rather than the pool.
      // The pool's own getter returns min(oracle, cap), which once a cap is set
      // is the cap - so measuring drift against it would always read zero.
      let oracle: bigint | null = null
      try {
        const helper = await ethers.getContractAt(
          PRICING_ABI,
          (await pool.UNISWAP_PRICING_HELPER()) as string
        )
        const routes = await pool.getPoolRoutes()
        oracle = (await helper.getUniswapPriceRatioForPoolRoutes(
          routes
        )) as bigint
      } catch {
        oracle = null
      }

      const availableUnits = Number(units(available, pd))
      const ratio =
        oracle && oracle > BigInt(0) && cap > BigInt(0)
          ? Number((cap * BigInt(10000)) / oracle) / 10000
          : null

      let severity: Severity = 'ok'
      let note = ''
      if (cap === BigInt(0)) {
        if (availableUnits >= (args.minAvailable as number)) {
          severity = 'critical'
          note = `no cap, ${units(available, pd)} ${ps} borrowable against an unclamped oracle`
        } else {
          severity = 'warn'
          note = 'no cap, but nothing meaningful to borrow yet'
        }
      } else if (oracle === null) {
        severity = 'warn'
        note =
          'capped, but its oracle did not answer - the TWAP may be unreadable'
      } else if (ratio !== null) {
        const drift = Math.abs(ratio - 1) * 100
        if (drift > (args.driftPct as number)) {
          severity = 'warn'
          note =
            ratio > 1
              ? `cap is ${((ratio - 1) * 100).toFixed(0)}% above the oracle, so it does not bind`
              : `cap is ${((1 - ratio) * 100).toFixed(0)}% below the oracle, so it is refusing honest borrowers`
        } else {
          note = 'cap tracks the oracle'
        }
      }

      findings.push({
        pool: address,
        pair: `${cs}->${ps}`,
        owner,
        availableRaw: available.toString(),
        available: units(available, pd),
        principalSymbol: ps,
        cap: cap.toString(),
        oracle: oracle === null ? null : oracle.toString(),
        capOverOracle: ratio,
        severity,
        note,
      })
    }

    const rank: Record<Severity, number> = { critical: 0, warn: 1, ok: 2 }
    findings.sort((a, b) => rank[a.severity] - rank[b.severity])

    const critical = findings.filter((f) => f.severity === 'critical')

    if (args.json === true) {
      console.log(
        JSON.stringify(
          { network: hre.network.name, factory: factory.address, findings },
          null,
          2
        )
      )
    } else {
      for (const f of findings) {
        const tag =
          f.severity === 'critical'
            ? 'CRITICAL'
            : f.severity === 'warn'
              ? 'warn    '
              : 'ok      '
        hre.log(
          `${tag} ${f.pool} ${f.pair.padEnd(20)} avail=${f.available.padStart(16)} ${f.principalSymbol}`,
          { star: false }
        )
        hre.log(`         owner ${f.owner}`, { star: false })
        if (f.note) hre.log(`         ${f.note}`, { star: false })
      }
      hre.log('')
      hre.log(
        `${critical.length} critical, ${findings.filter((f) => f.severity === 'warn').length} warn, ` +
          `${findings.filter((f) => f.severity === 'ok').length} ok`
      )
    }

    if (critical.length > 0) {
      // Non-zero so a scheduler treats this as the alert. The message names the
      // owners, because the fix is theirs to sign and an alert that does not say
      // whose job it is gets read and dropped.
      const owners = [...new Set(critical.map((f) => f.owner))]
      throw new Error(
        `${critical.length} pool(s) on ${hre.network.name} hold borrowable principal with no ` +
          `maxPrincipalPerCollateralAmount: ${critical.map((f) => `${f.pool} (${f.pair})`).join(', ')}. ` +
          `Owners who must set it: ${owners.join(', ')}`
      )
    }
  })
