import fs from 'fs'
import path from 'path'

import { task, types } from 'hardhat/config'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

import { ChainBootstrapConfig } from '../../config/chain-bootstrap/types'

/**
 * Caps every pool's principal-per-collateral ratio at the price it sees today.
 *
 * A pool with no cap prices collateral purely off its Uniswap TWAP:
 *
 *   principalPerCollateral = maxPrincipalPerCollateralAmount == 0
 *     ? oracle
 *     : min(oracle, maxPrincipalPerCollateralAmount)
 *
 * So the cap is a ceiling, never a floor. Below it the oracle still governs and
 * a falling price still reduces what a borrower may draw; above it the pool
 * stops believing the oracle. That is the protection worth having, because the
 * direction an attacker wants to push a TWAP is up: a collateral token quoted
 * too high is one that borrows more than it is worth.
 *
 * The value written is the pool's own current reading, taken through the pool's
 * own oracle routes and its own pricing library, not a price recomputed here.
 * Reading it back from the contract keeps the units exactly what the comparison
 * expects - expanded by STANDARD_EXPANSION_FACTOR, in whichever direction that
 * pool's route runs - rather than depending on this task to rebuild that
 * arithmetic correctly for pools whose principal and collateral are the other
 * way round.
 *
 * The read goes to UNISWAP_PRICING_HELPER rather than to the pool. The pool
 * declares `getUniswapPriceRatioForPoolRoutes` `internal`, so there is no such
 * selector on it and the call reverts with empty data. Its external sibling
 * `getPrincipalForCollateralForPoolRoutes` does answer, but it returns
 * min(oracle, cap) - which is the cap itself once one is set, so a second run
 * would re-cap at the old ceiling and could never raise it. The library gives
 * the unclamped oracle, which is what a cap should be measured against.
 *
 * Setting the cap at spot means an honest rally grants no extra borrowing
 * power until someone re-runs this. That is the deliberate cost: the cap only
 * has teeth if it is close to the real price.
 *
 * `--buffer-bps` loosens it by a margin if that is too tight to live with.
 * Ownership is the pool's, which is the deployer for a chain it launched.
 */

interface BootstrapReceipt {
  chainId: number
  principal: string
  markets: Record<string, { marketId: string }>
  pools: Record<string, { address: string }>
}

const loadConfig = async (
  network: string
): Promise<ChainBootstrapConfig | undefined> => {
  try {
    const mod = await import(`../../config/chain-bootstrap/${network}`)
    return (mod.default ?? mod) as ChainBootstrapConfig
  } catch {
    return undefined
  }
}

const POOL_ABI = [
  'function owner() view returns (address)',
  'function principalToken() view returns (address)',
  'function collateralToken() view returns (address)',
  'function collateralRatio() view returns (uint16)',
  'function maxPrincipalPerCollateralAmount() view returns (uint256)',
  'function poolOracleRoutes(uint256) view returns (address pool, bool zeroForOne, uint32 twapInterval, uint256 token0Decimals, uint256 token1Decimals)',
  'function UNISWAP_PRICING_HELPER() view returns (address)',
  'function setMaxPrincipalPerCollateralAmount(uint256 _maxPrincipalPerCollateralAmount)',
]

const PRICING_LIBRARY_ABI = [
  'function getUniswapPriceRatioForPoolRoutes((address,bool,uint32,uint256,uint256)[] poolRoutes) view returns (uint256)',
]

task(
  'set-pool-price-caps',
  "Caps each pool's principal-per-collateral ratio at its current oracle reading"
)
  .addOptionalParam(
    'dryRun',
    'Print what would be written without sending transactions',
    false,
    types.boolean
  )
  .addOptionalParam(
    'bufferBps',
    'Headroom above the current reading, in bps. 0 caps exactly at spot, and a ' +
      'negative value caps below it - which is the case that matters when the ' +
      'pool being read is not where the asset actually trades.',
    '0',
    // A string, not types.int, because hardhat's int refuses a leading minus:
    // `--buffer-bps -410` dies with HH301 before the task is entered. The value
    // is parsed with BigInt below, which does accept one. Please do not "tidy"
    // this back to types.int.
    types.string
  )
  .addOptionalParam(
    'only',
    'Only pools whose receipt key contains this substring',
    '',
    types.string
  )
  .setAction(async (args, hre: HardhatRuntimeEnvironment): Promise<void> => {
    const { network, ethers } = hre

    const config = await loadConfig(network.name)
    if (!config) {
      throw new Error(`No bootstrap config for network "${network.name}"`)
    }

    const file = path.join(
      hre.config.paths.deployments ?? 'deployments',
      network.name,
      'market-bootstrap.json'
    )
    if (!fs.existsSync(file)) {
      throw new Error(
        `No bootstrap receipt at ${file}. Run bootstrap-markets first.`
      )
    }
    const receipt = JSON.parse(
      fs.readFileSync(file, 'utf8')
    ) as BootstrapReceipt

    const [signer] = await ethers.getSigners()
    // BigInt throws on anything that is not an integer literal, which is the
    // validation this needs: a buffer that silently became NaN would write a
    // cap of 0 to every pool in the receipt, and a cap of 0 is not "no cap" -
    // `principalPerCollateral` takes min(oracle, cap), so it would halt every
    // one of them.
    let buffer: bigint
    try {
      buffer = BigInt(String(args.bufferBps ?? '0').trim())
    } catch {
      throw new Error(
        `--buffer-bps must be an integer number of bps, got "${String(
          args.bufferBps
        )}"`
      )
    }
    if (buffer <= -10000n) {
      throw new Error(
        `--buffer-bps ${buffer} would cap at or below zero, which halts every pool it touches rather than capping it`
      )
    }

    console.log(`network   ${network.name} (${config.chainId})`)
    console.log(`signer    ${await signer.getAddress()}`)
    console.log(`buffer    ${buffer} bps`)
    console.log(`pools     ${Object.keys(receipt.pools).length} in receipt`)

    let written = 0
    let skipped = 0

    for (const [key, entry] of Object.entries(receipt.pools)) {
      if (args.only && !key.includes(args.only as string)) continue

      const pool = new ethers.Contract(entry.address, POOL_ABI, signer)

      const owner: string = await pool.owner()
      if (owner.toLowerCase() !== (await signer.getAddress()).toLowerCase()) {
        console.log(`\n  ${key}: owned by ${owner}, not this signer - skipping`)
        skipped++
        continue
      }

      // The pool stores its routes as an array; read them back so the price we
      // cap at is the one this pool actually quotes.
      const routes: Array<[string, boolean, number, bigint, bigint]> = []
      for (let i = 0; ; i++) {
        try {
          const r = await pool.poolOracleRoutes(i)
          routes.push([r[0], r[1], Number(r[2]), r[3], r[4]])
        } catch {
          break
        }
      }
      if (!routes.length) {
        console.log(`\n  ${key}: no oracle routes - skipping`)
        skipped++
        continue
      }

      const helperAddress: string = await pool.UNISWAP_PRICING_HELPER()
      const library = new ethers.Contract(
        helperAddress,
        PRICING_LIBRARY_ABI,
        signer
      )
      const current: bigint =
        await library.getUniswapPriceRatioForPoolRoutes(routes)
      if (current === 0n) {
        console.log(`\n  ${key}: oracle reads zero - skipping rather than
          writing a cap that would halt the pool`)
        skipped++
        continue
      }

      const existing: bigint = await pool.maxPrincipalPerCollateralAmount()
      const target = (current * (10000n + buffer)) / 10000n

      console.log(`\n  ${key} (${entry.address})`)
      console.log(`    oracle now   ${current}`)
      console.log(
        `    existing cap ${existing}${existing === 0n ? ' (uncapped)' : ''}`
      )
      console.log(`    new cap      ${target}`)

      if (existing === target) {
        console.log('    unchanged - skipping')
        skipped++
        continue
      }

      if (args.dryRun) continue

      const tx = await pool.setMaxPrincipalPerCollateralAmount(target)
      const rcpt = await tx.wait()
      console.log(`    -> ${rcpt?.hash ?? tx.hash}`)
      written++
    }

    console.log(
      `\ndone: ${written} pool(s) written, ${skipped} skipped${
        args.dryRun ? ' (dry run: nothing sent)' : ''
      }`
    )
  })
