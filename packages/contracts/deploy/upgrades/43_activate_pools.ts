import { DeployFunction } from 'hardhat-deploy/dist/types'
import { HardhatRuntimeEnvironment } from 'hardhat/types'
import fs from 'fs'
import path from 'path'

import { ChainBootstrapConfig } from '../../config/chain-bootstrap/types'

/**
 * Make a chain's pools depositable.
 *
 * A LenderCommitmentGroup pool rejects every deposit until its first one, and
 * that first one has to come from the pool's owner:
 *
 *     if (!poolWasActivated) {
 *         require(msg.sender == owner(), "FD");
 *         require(poolIsActivated(), "IS");
 *     }
 *
 * That is the ERC4626 first-depositor guard - the owner sets the share price
 * before anyone else can, so nobody can open a pool with one wei and inflate
 * the rate against the next lender. It also means launching a pool is two
 * steps, not one: creating it leaves something no one can use, including the
 * lenders the front end is showing it to. Every Robinhood pool sat at
 * totalSupply 0 and answered "FD" to anyone who tried, which is what a lender
 * saw as a failed deposit with no explanation.
 *
 * Which pools get opened comes from the chain's own bootstrap config -
 * `activateMarkets`, defaulting to the thirty-day market. Opening a pool costs
 * real principal, so a market the front end does not list is not worth the
 * deposit.
 *
 * Shares are 1:1 with assets on the first deposit (sharesExchangeRate returns
 * the expansion factor while totalSupply is 0), and poolIsActivated wants
 * totalSupply >= 1e6, so the floor is 1e6 of the principal's own units: one
 * whole dollar at six decimals, and a millionth of a millionth of a token at
 * eighteen. The amounts below clear that by a wide margin in the first case
 * and enormously in the second.
 */

const MIN_SHARES = 10n ** 6n

// One whole unit is the floor for a six-decimal principal, so two is the
// smallest amount that is not sitting on the boundary.
const STABLE_DEPOSIT = 2_000_000n

/** Markets whose pools get opened when the chain's config does not say. */
const DEFAULT_ACTIVATE_MARKETS = ['long']

const POOL_ABI = [
  'function principalToken() view returns (address)',
  'function totalSupply() view returns (uint256)',
  'function owner() view returns (address)',
  'function deposit(uint256 assets, address receiver) returns (uint256)',
]
const ERC20_ABI = [
  'function balanceOf(address) view returns (uint256)',
  'function allowance(address,address) view returns (uint256)',
  'function approve(address,uint256) returns (bool)',
  'function symbol() view returns (string)',
  'function decimals() view returns (uint8)',
]

/** Markets this chain wants opened, from its bootstrap config. */
const activateMarkets = async (network: string): Promise<string[]> => {
  try {
    const mod = await import(`../../config/chain-bootstrap/${network}`)
    const config = (mod.default ?? mod) as ChainBootstrapConfig
    return config.activateMarkets ?? DEFAULT_ACTIVATE_MARKETS
  } catch {
    // A chain with no bootstrap config has no pools of ours to open either,
    // and `listedPools` will come back empty regardless.
    return DEFAULT_ACTIVATE_MARKETS
  }
}

/** The pools this chain lists, read from the bootstrap receipt. */
const listedPools = async (
  hre: HardhatRuntimeEnvironment
): Promise<[string, string][]> => {
  // Resolved against the project root rather than the working directory, so
  // it does not depend on where the deploy was invoked from.
  const receiptPath = path.join(
    (hre.config.paths as { deployments?: string }).deployments ??
      path.join(hre.config.paths.root, 'deployments'),
    hre.network.name,
    'market-bootstrap.json'
  )
  if (!fs.existsSync(receiptPath)) return []
  const receipt = JSON.parse(fs.readFileSync(receiptPath, 'utf8'))

  // ACTIVATE_ONLY names pools rather than markets, and naming a pool is the
  // more specific instruction, so it overrides the market filter below.
  //
  // It exists because the deposit is spent, not just authorised. This script
  // walks the receipt in order and stops at each pool it cannot afford, which
  // is fine when there is enough of the principal for all of them and wrong
  // when there is not: opening one new pool on a chain with thirty-odd
  // already listed means the first unopened pool in the file takes the money,
  // whichever pool that happens to be. Mirrors `--only` on
  // set-pool-price-caps, and matches on the receipt key the same way.
  const only = (process.env.ACTIVATE_ONLY ?? '').trim()
  const entries = Object.entries(receipt?.pools ?? {})

  if (only) {
    return entries
      .filter(([key]) => key.includes(only))
      .map(([key, pool]) => [key, (pool as { address: string }).address])
  }

  // Receipt keys are `<market>:<symbol>`. Pools on a market this chain does
  // not surface are still on chain and still borrowable against; they are not
  // shown, so opening them is not this script's business.
  const markets = await activateMarkets(hre.network.name)
  return entries
    .filter(([key]) => markets.includes(key.split(':')[0]))
    .map(([key, pool]) => [key, (pool as { address: string }).address])
}

const deployFn: DeployFunction = async (hre) => {
  const deployer = await hre.getNamedSigner('deployer')
  const deployerAddress = await deployer.getAddress()

  hre.log('----------')
  hre.log('')
  hre.log(`Activating ${hre.network.name} pools as ${deployerAddress}`)
  const only = (process.env.ACTIVATE_ONLY ?? '').trim()
  if (only) hre.log(`  only pools matching "${only}"`)

  const activated: string[] = []
  const skipped: string[] = []

  for (const [key, address] of await listedPools(hre)) {
    const pool = await hre.ethers.getContractAt(POOL_ABI, address, deployer)

    if ((await pool.totalSupply()) >= MIN_SHARES) {
      skipped.push(`${key} (already activated)`)
      continue
    }

    const owner: string = await pool.owner()
    if (owner.toLowerCase() !== deployerAddress.toLowerCase()) {
      // Only the owner can open a pool, so say whose job it is rather than
      // sending a transaction that reverts with "FD".
      skipped.push(`${key} (owned by ${owner})`)
      continue
    }

    const principalAddress: string = await pool.principalToken()
    const principal = await hre.ethers.getContractAt(
      ERC20_ABI,
      principalAddress,
      deployer
    )
    const [symbol, decimals, balance] = await Promise.all([
      principal.symbol() as Promise<string>,
      principal.decimals() as Promise<bigint>,
      principal.balanceOf(deployerAddress) as Promise<bigint>,
    ])

    // A six-decimal principal is the chain's dollar, shared by every pool
    // lending it, so it takes a fixed amount. Anything else is an asset that
    // is the principal of exactly one listed pool, so that pool takes the
    // whole balance - there is nothing else here to spend it on.
    const amount = decimals === 6n ? STABLE_DEPOSIT : balance

    if (amount === 0n || balance < amount) {
      skipped.push(
        `${key} (needs ${amount} ${symbol}, deployer holds ${balance})`
      )
      continue
    }
    if (amount < MIN_SHARES) {
      skipped.push(
        `${key} (${amount} ${symbol} mints fewer than ${MIN_SHARES} shares)`
      )
      continue
    }

    if ((await principal.allowance(deployerAddress, address)) < amount) {
      await (await principal.approve(address, amount)).wait()
    }
    await (await pool.deposit(amount, deployerAddress)).wait()

    const supply: bigint = await pool.totalSupply()
    if (supply < MIN_SHARES) {
      throw new Error(
        `${key} (${address}) is still not activated after depositing ${amount} ${symbol}: totalSupply ${supply}`
      )
    }
    activated.push(`${key} <- ${amount} ${symbol}`)
    hre.log(`  activated ${key.padEnd(22)} ${amount} ${symbol}`, {
      star: false,
    })
  }

  for (const line of skipped) hre.log(`  skipped   ${line}`, { star: false })
  hre.log('')
  hre.log(`${activated.length} activated, ${skipped.length} skipped`)
  hre.log('----------')
}

// Deliberately no `deployFn.id`, and deliberately no `return true` above.
//
// An id plus a truthy return is how hardhat-deploy records a script as done,
// and this script must not be: the set of pools it opens is not fixed at the
// first run. A chain that adds a pool later has no way to open it, because the
// one script that can is skipped on a record written before that pool existed.
// Arc hit this - `activate-pools` ran on 2026-09-19 and opened the ARGUS pool,
// then #322 added the inverse pool, and the re-run that would have opened it
// was skipped silently against a receipt that lists it.
//
// Nothing is lost by re-running. The body already treats each pool
// independently and skips any whose totalSupply clears MIN_SHARES, so a second
// run over an open pool sends nothing, and skip() below stops the script before
// it needs a signer when every listed pool is open.
deployFn.tags = ['activate-pools']
deployFn.dependencies = []
deployFn.skip = async (hre) => {
  if (!hre.network.live) return true

  const pools = await listedPools(hre)
  if (pools.length === 0) return true

  // Reading totalSupply here rather than trusting a migration record: the
  // question is whether any listed pool is still shut, and the pools answer it.
  for (const [, address] of pools) {
    const pool = await hre.ethers.getContractAt(POOL_ABI, address)
    if ((await pool.totalSupply()) < MIN_SHARES) return false
  }
  return true
}

export default deployFn
