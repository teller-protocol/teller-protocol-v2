import { task, types } from 'hardhat/config'
import { HardhatRuntimeEnvironment } from 'hardhat/types'
import fs from 'fs'
import path from 'path'

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
 * can treat the exit code as the alert - and prints a final
 * `audit-verdict: critical <n> | unreadable <n>/<m> | clean` line, so a
 * scheduler sweeping several chains can tell an alert apart from a chain it
 * never managed to read. A run that dies before that line printed nothing
 * because it never got to look.
 *
 * WHEN THE CHAIN WILL NOT BE ENUMERATED. HyperEVM's providers cap eth_getLogs
 * at 1000 blocks with no tier that lifts it, and its head is past 46 million:
 * the scan is tens of thousands of requests and the first attempt died of a
 * timeout. So the scan runs on a request budget, and a chain that blows it (or
 * fails outright) falls back to a checked-in list at
 * config/pool-census/<network>.json.
 *
 * That fallback is a weaker guarantee and the report says so on every run. A
 * log scan is complete by construction; a census is complete only while
 * somebody maintains it, and a pool missing from it is a pool nothing watches.
 *
 *   yarn hh audit-pool-caps --network hyperevm
 *   yarn hh audit-pool-caps --network arc --json true
 */

interface Census {
  pools?: Array<{ address?: string } | string>
}

/**
 * The checked-in pool list for a chain, if there is one.
 *
 * Resolved from this file rather than from the working directory, so it does
 * not depend on where hardhat was invoked from.
 */
const readCensus = (network: string): string[] => {
  const file = path.join(
    __dirname,
    '..',
    '..',
    'config',
    'pool-census',
    `${network}.json`
  )
  if (!fs.existsSync(file)) return []
  const parsed = JSON.parse(fs.readFileSync(file, 'utf8')) as Census
  return (parsed.pools ?? [])
    .map((entry) => (typeof entry === 'string' ? entry : entry.address))
    .filter((a): a is string => Boolean(a))
}

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
  /**
   * True when the pool could not be read at all. Kept apart from severity
   * because "I could not look" is not a finding about the pool - it is a
   * finding about the report.
   */
  unreadable?: boolean
}

/**
 * The endpoint refusing the WIDTH of a query, as opposed to its rate.
 *
 * Both arrive as an error on the same call, and the right answer to each is the
 * opposite of the right answer to the other: a range refusal wants a narrower
 * window, a rate refusal wants the same window a moment later. Narrowing in
 * answer to a rate limit makes the scan longer, which makes the throttling
 * worse. So this insists on the words that actually name a range, and anything
 * vaguer is left to isTransient.
 */
const isRangeShaped = (err: unknown): boolean =>
  // Both word orders, because endpoints use both: katana answers "getLogs
  // request exceeded max allowed range" and hyperliquid "query exceeds max
  // block range 1000". What every one of them has in common, and what bare
  // "limit exceeded" does not, is that it names the thing being measured -
  // a range, a count of blocks, a size of response.
  /block range|allowed range|exceeds? max block|range[^.]*(too|exceed|limit)|(exceed|too large|too wide|too big|smaller)[^.]*range|too many blocks|more than \d+ blocks|query returned more than|log response size|response size exceeded|too many results/i.test(
    String((err as Error)?.message ?? err ?? '')
  )

/**
 * A transport failure, as opposed to the chain saying no.
 *
 * The distinction is the whole of this file's honesty. A revert is an answer -
 * the array ended, the oracle cannot price - and a rate limit is not an answer
 * at all. Reading the second as the first is how a monitor reports a healthy
 * chain it never managed to look at, and it is not hypothetical: the first
 * scheduled sweep of hyperevm came back "0 critical, 16 warn" where fifteen of
 * those warns were "rate limited" and the sixteenth said a capped pool had no
 * oracle routes - which it has, but the call asking for them was throttled.
 */
const isTransient = (err: unknown): boolean => {
  const message = String((err as Error)?.message ?? err ?? '')
  // A message that names a range is a range refusal whatever else it says, and
  // some say both: infura's "query timeout exceeded, retry with a smaller block
  // range" is a width complaint wearing the word timeout. Retrying that five
  // times over eight seconds and then halving anyway is the slow way round to
  // the same window.
  if (isRangeShaped(message)) return false
  if (
    /rate.?limit|429|too many requests|timeout|timed out|ECONNRESET|ETIMEDOUT|socket hang up|SERVER_ERROR|bad response|network error|fetch failed|bad gateway|service unavailable|gateway time-?out/i.test(
      message
    )
  ) {
    return true
  }
  // A bare "limit exceeded", with nothing in it about blocks or ranges, is the
  // endpoint saying "not so fast" - not "not so wide". bsc-dataseed answers a
  // burst with exactly those two words, and reading them as a range refusal is
  // how the scan that should have paused instead halved its window eighteen
  // times, from 500000 down to 1, and then gave up on a chain it had not
  // managed to read a single block of.
  // "block range limit exceeded" never reaches here - isRangeShaped above
  // short-circuits it - so a remaining "limit exceeded" is an allowance, not a
  // width. Past tense and an allowance word both required, so a contract that
  // reverts with "exceeds capacity" stays an answer rather than a fault.
  return /\blimit exceeded\b|\b(quota|capacity|credits?|compute units?)\b[^.]{0,40}\bexceeded\b|\bexceeded\b[^.]{0,60}\b(quota|capacity|credits?|compute units?)\b/i.test(
    message
  )
}

/**
 * Consecutive clean windows before the scan tries a wider one again. Small
 * enough that a chain does not crawl for millions of blocks on the strength of
 * one refusal, large enough that it is not re-probing after every request.
 */
const WIDEN_AFTER = 8

/** Retry only what is worth retrying, with a widening gap. */
const withRetry = async <T>(fn: () => Promise<T>, attempts = 5): Promise<T> => {
  let last: unknown
  for (let attempt = 0; attempt < attempts; attempt++) {
    try {
      return await fn()
    } catch (err) {
      last = err
      if (!isTransient(err)) throw err
      await new Promise((resolve) => setTimeout(resolve, 300 * 2 ** attempt))
    }
  }
  throw last
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
    'pause',
    'Milliseconds to wait between pools. A public endpoint that throttles a ' +
      'burst will serve the same calls spread out, and this run is never in a ' +
      'hurry.',
    0,
    types.int
  )
  .addOptionalParam(
    'maxRequests',
    'Give up on scanning the factory log after this many requests and fall back ' +
      'to config/pool-census/<network>.json. A range-capable endpoint finishes ' +
      'in a handful; a 1000-block cap on a 46M-block chain never finishes at all.',
    500,
    types.int
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
    // Set when the pool list did not come from the factory's own log, which is
    // a fact about how much this report is worth and travels with it.
    let degraded = ''

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
      const startWindow = Math.max(1, args.chunk as number)
      let window = startWindow
      // The narrowest window any endpoint has already refused. Nothing at or
      // above it is worth asking for twice, and holding onto it is what stops
      // the widening below from oscillating between a width that works and a
      // width that does not.
      let refusedAt = Number.POSITIVE_INFINITY
      let okStreak = 0
      let requests = 0
      let attempts = 0
      let logCount = 0
      const seen = new Set<string>()
      let cursor = from
      const budget = Math.max(1, args.maxRequests as number)
      try {
        while (cursor <= latest) {
          const to = Math.min(cursor + window - 1, latest)
          attempts++
          try {
            // The same five-attempt backoff every other read in this file gets.
            // Without it a throttled endpoint's refusal arrives below looking
            // like a verdict on the window, and the loop answers a rate limit
            // by making more requests than it was already making.
            const found = await withRetry(() =>
              ethers.provider.getLogs({
                address: factory.address,
                topics: [topic],
                fromBlock: cursor,
                toBlock: to,
              })
            )
            requests++
            logCount += found.length
            for (const l of found) {
              seen.add(ethers.getAddress('0x' + l.topics[1].slice(26)))
            }
            cursor = to + 1
            // Widen again once the narrow window has proved itself. One refusal
            // used to set the width for the rest of the scan however early it
            // came: katana halved to 15625 and then spent its entire budget
            // there, covering 6.25M of 43.2M blocks without a single further
            // refusal to justify the width it was crawling at.
            if (++okStreak >= WIDEN_AFTER && window * 2 < refusedAt) {
              window = Math.min(window * 2, startWindow)
              okStreak = 0
            }
          } catch (err) {
            if (!isRangeShaped(err) || window === 1) throw err
            refusedAt = Math.min(refusedAt, window)
            window = Math.max(1, Math.floor(window / 2))
            okStreak = 0
          }
          // Counted in attempts rather than in answers, so an endpoint that
          // refuses every width still reaches an end. Refusals used to be free
          // against the budget, which is a loop that halves forever on a chain
          // nobody is watching.
          if (attempts >= budget && cursor <= latest) {
            throw new Error(
              `scan budget spent: ${attempts} attempt(s), ${requests} answered, covered ` +
                `${cursor - from} of ${latest - from} blocks at window ${window}`
            )
          }
        }
        pools = [...seen]
      } catch (err) {
        // The census is the fallback, never the preference. A scan is complete
        // by construction; a checked-in list is complete only while somebody
        // maintains it, so this path says loudly what it is and what it costs.
        const census = readCensus(hre.network.name)
        if (census.length === 0) throw err
        pools = census.map((p) => ethers.getAddress(p))
        degraded = `factory scan failed (${(err as Error).message.slice(0, 120)})`
      }

      if (!args.json) {
        hre.log(`Pool cap audit on ${hre.network.name}`, { star: true })
        hre.log(`  factory ${factory.address}`)
        if (degraded) {
          hre.log(`  !! ${degraded}`)
          hre.log(
            `  !! falling back to config/pool-census/${hre.network.name}.json: ${pools.length} pool(s).`
          )
          hre.log(
            '  !! a pool on this chain that is not in that file is not being watched.'
          )
        } else {
          hre.log(
            `  scanned ${from}..${latest} in ${requests} request(s)` +
              (attempts > requests
                ? ` (${attempts - requests} refused)`
                : '') +
              `, window ${window}`
          )
          hre.log(
            `  pools   ${pools.length} (from ${logCount} deployment logs)`
          )
        }
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
    const pause = Math.max(0, args.pause as number)
    for (const [index, address] of pools.entries()) {
      if (pause > 0 && index > 0) {
        await new Promise((resolve) => setTimeout(resolve, pause))
      }
      const pool = await ethers.getContractAt(POOL_ABI, address)
      let principal: string
      let collateral: string
      let owner: string
      let cap: bigint
      let available: bigint
      try {
        ;[principal, collateral, owner, cap, available] = await withRetry(() =>
          Promise.all([
            pool.principalToken() as Promise<string>,
            pool.collateralToken() as Promise<string>,
            pool.owner() as Promise<string>,
            pool.maxPrincipalPerCollateralAmount() as Promise<bigint>,
            pool.getPrincipalAmountAvailableToBorrow() as Promise<bigint>,
          ])
        )
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
          unreadable: true,
        })
        continue
      }

      const [ps, pd] = await symbolOf(principal)
      const [cs] = await symbolOf(collateral)

      // The unclamped reading, from the pricing library rather than the pool.
      // The pool's own getter returns min(oracle, cap), which once a cap is set
      // is the cap - so measuring drift against it would always read zero.
      //
      // `poolOracleRoutes` is a public array: the generated getter answers one
      // entry at a time and reverts past the end, and there is no whole-array
      // getter. Reading them one by one is what set-pool-price-caps does, and
      // getting it wrong is not a quiet failure - an earlier draft called a
      // `getPoolRoutes()` that does not exist, so every pool on hyperevm came
      // back "oracle did not answer". That reads as fourteen broken oracles
      // rather than as one broken audit, which is the worse way for a security
      // report to be wrong. The reason is carried into the note now, so the
      // next such failure names itself.
      let oracle: bigint | null = null
      let oracleNote = ''
      try {
        const routes: Array<[string, boolean, number, bigint, bigint]> = []
        for (let i = 0; ; i++) {
          try {
            const r = await withRetry(() => pool.poolOracleRoutes(i))
            routes.push([r[0], r[1], Number(r[2]), r[3], r[4]])
          } catch (err) {
            // Only a revert ends the array. A throttled or dropped request is
            // not the chain saying "no more routes", and treating it as one
            // truncates the list silently - which is how a pool with a working
            // oracle gets reported as having none.
            if (isTransient(err)) throw err
            break
          }
        }
        if (routes.length === 0) {
          oracleNote = 'pool has no oracle routes'
        } else {
          const helper = await ethers.getContractAt(
            PRICING_ABI,
            (await pool.UNISWAP_PRICING_HELPER()) as string
          )
          oracle = (await helper.getUniswapPriceRatioForPoolRoutes(
            routes
          )) as bigint
        }
      } catch (err) {
        oracle = null
        oracleNote = isTransient(err)
          ? `could not reach the chain: ${(err as Error)?.message?.slice(0, 50) ?? 'unknown'}`
          : ((err as Error)?.message?.slice(0, 70) ?? 'unknown')
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
        note = `capped, but its oracle did not answer (${oracleNote}) - the TWAP may be unreadable`
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
    const unreadable = findings.filter((f) => f.unreadable === true)
    // A quarter. One pool that would not answer is a bad moment on a public
    // endpoint; a quarter of them is a chain this run did not see, and a
    // monitor that reports "0 critical" for a chain it could not read has told
    // you the opposite of what it knows.
    const blind =
      unreadable.length > 0 && unreadable.length * 4 >= findings.length

    if (args.json === true) {
      console.log(
        JSON.stringify(
          {
            network: hre.network.name,
            factory: factory.address,
            // Carried into the JSON as well as the table: a sweep that posts
            // these to Slack has to be able to say "and this chain's list was
            // checked in, not scanned".
            source: degraded
              ? 'census'
              : explicit.length
                ? 'explicit'
                : 'factory-log',
            degraded: degraded || null,
            unreadable: unreadable.length,
            blind,
            // The same fact the table's `audit-verdict:` line carries, so a
            // caller reading either form can tell an uncapped pool from a
            // chain nobody could read without re-deriving it from severities.
            verdict: blind
              ? 'unreadable'
              : critical.length > 0
                ? 'critical'
                : 'clean',
            findings,
          },
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
          `${findings.filter((f) => f.severity === 'ok').length} ok` +
          (unreadable.length > 0 ? ` (${unreadable.length} unreadable)` : '')
      )
    }

    // One machine-readable line, last, on every path that got far enough to
    // have an opinion. A caller sweeping several chains reads the exit code and
    // gets one bit: non-zero. That bit has to carry both "this chain has
    // uncapped pools holding money" and "this chain would not answer the
    // phone", and a sweep that cannot tell them apart reports the second as the
    // first - which is a page naming chains with no finding on them, and no
    // mention of the ones that were never read. A run that dies before here
    // prints nothing, and the absence is itself the answer: it could not look.
    if (args.json !== true) {
      hre.log(
        blind
          ? `audit-verdict: unreadable ${unreadable.length}/${findings.length}`
          : critical.length > 0
            ? `audit-verdict: critical ${critical.length}`
            : 'audit-verdict: clean',
        { star: false }
      )
    }

    if (blind) {
      // Before the critical check, deliberately: a run that could not read a
      // quarter of the chain has no business reporting on the rest of it as if
      // the silence meant something.
      throw new Error(
        `could not read ${unreadable.length} of ${findings.length} pool(s) on ${hre.network.name} - ` +
          `${unreadable[0]?.note ?? 'no reason given'}. This run cannot say whether the chain is capped; ` +
          `point ${hre.network.name.toUpperCase()}_RPC_URL at an endpoint that will answer.`
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
