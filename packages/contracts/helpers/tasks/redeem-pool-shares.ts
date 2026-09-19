import { task, types } from 'hardhat/config'
import fs from 'fs'
import path from 'path'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

/**
 * Redeem the deployer's shares out of a LenderCommitmentGroup pool.
 *
 * WHY THIS EXISTS. `activate-pools` puts the owner's first deposit into every
 * pool a chain lists, because a pool rejects every deposit until that one is
 * made. Nothing took it back out. That did not matter until a pool had to be
 * replaced: a pool's rate band is written in `initialize` and no implementation
 * exposes a setter, so repricing one means deploying another - and the deposit
 * that opened the old one is then sitting in a pool nothing lists any more.
 *
 * It is the counterpart of activate-pools, and it is deliberately the owner's
 * own shares only. Redeeming is `msg.sender == owner` on the pool, so this can
 * never reach a lender's position; it is the deposit this repo made, coming
 * back to the address that made it.
 *
 * WHAT IT REFUSES TO DO. Nothing about a retired pool stops working - that is
 * the point of retiring rather than destroying one - so the pool may still be
 * lending. Redeeming shares while principal is out on loan is legitimate for a
 * lender but wrong for this: it would take the liquidity a borrower's
 * repayment path depends on out of the pool. So `--all` refuses when the
 * redemption would draw on principal that is currently lent, unless the amount
 * is named explicitly.
 *
 *   yarn hh redeem-pool-shares --network arc --key short:ARGUS --dry-run true
 *   yarn hh redeem-pool-shares --network arc --key short:ARGUS
 */

const POOL_ABI = [
  'function principalToken() view returns (address)',
  'function totalSupply() view returns (uint256)',
  'function balanceOf(address) view returns (uint256)',
  'function totalPrincipalTokensLended() view returns (uint256)',
  'function totalPrincipalTokensRepaid() view returns (uint256)',
  'function withdrawDelayTimeSeconds() view returns (uint256)',
  'function getSharesLastTransferredAt(address) view returns (uint256)',
  'function redeem(uint256 shares, address receiver, address owner) returns (uint256)',
]
const ERC20_ABI = [
  'function symbol() view returns (string)',
  'function decimals() view returns (uint8)',
  'function balanceOf(address) view returns (uint256)',
]

const units = (raw: bigint, decimals: number): string => {
  const d = BigInt(10) ** BigInt(decimals)
  const frac = (raw % d).toString().padStart(decimals, '0').replace(/0+$/, '')
  return frac ? `${raw / d}.${frac}` : `${raw / d}`
}

/**
 * Resolve a receipt key to an address, looking in `retiredPools` as well as
 * `pools`. A pool that was just replaced is exactly the one whose deposit needs
 * collecting, and by then the key no longer names it.
 */
const addressForKey = (hre: HardhatRuntimeEnvironment, key: string): string => {
  const receiptPath = path.join(
    hre.config.paths.deployments ?? 'deployments',
    hre.network.name,
    'market-bootstrap.json'
  )
  if (!fs.existsSync(receiptPath)) {
    throw new Error(`No ${receiptPath}. Nothing to look a pool key up in.`)
  }
  const receipt = JSON.parse(fs.readFileSync(receiptPath, 'utf8'))
  const live = receipt?.pools?.[key]?.address
  const retired: Array<{ address: string }> = receipt?.retiredPools?.[key] ?? []

  if (live && retired.length === 0) return live
  if (live && retired.length > 0) {
    throw new Error(
      `${key} names ${live} now and previously named ${retired
        .map((r) => r.address)
        .join(', ')}. Pass --address to say which one, so a redemption is ` +
        `never aimed at a pool by accident.`
    )
  }
  if (retired.length === 1) return retired[0].address
  throw new Error(
    `No pool for key "${key}" in ${receiptPath}. Known: ${Object.keys(
      receipt?.pools ?? {}
    ).join(', ')}`
  )
}

task(
  'redeem-pool-shares',
  "Redeem the deployer's own shares out of a LenderCommitmentGroup pool"
)
  .addOptionalParam(
    'key',
    'Receipt key of the pool, e.g. "short:ARGUS". Looks in retiredPools too.',
    '',
    types.string
  )
  .addOptionalParam(
    'address',
    'Pool address, instead of a receipt key',
    '',
    types.string
  )
  .addOptionalParam(
    'shares',
    "Shares to redeem, in raw units. Omitted means the deployer's whole balance.",
    '',
    types.string
  )
  .addOptionalParam(
    'dryRun',
    'Print what would be redeemed without sending anything',
    false,
    types.boolean
  )
  .setAction(async (args, hre: HardhatRuntimeEnvironment): Promise<void> => {
    const { ethers } = hre
    const deployer = await hre.getNamedSigner('deployer')
    const sender = await deployer.getAddress()

    const key = String(args.key ?? '')
    const explicit = String(args.address ?? '')
    if (!key && !explicit) {
      throw new Error('Pass --key or --address.')
    }
    const poolAddress = explicit || addressForKey(hre, key)

    const pool = await ethers.getContractAt(POOL_ABI, poolAddress, deployer)
    const principalAddress: string = await pool.principalToken()
    const principal = await ethers.getContractAt(
      ERC20_ABI,
      principalAddress,
      deployer
    )

    const [symbol, decimals, shareBalance, totalSupply, lended, repaid, held] =
      await Promise.all([
        principal.symbol() as Promise<string>,
        principal.decimals() as Promise<bigint>,
        pool.balanceOf(sender) as Promise<bigint>,
        pool.totalSupply() as Promise<bigint>,
        pool.totalPrincipalTokensLended() as Promise<bigint>,
        pool.totalPrincipalTokensRepaid() as Promise<bigint>,
        principal.balanceOf(poolAddress) as Promise<bigint>,
      ])
    const dp = Number(decimals)
    const outstanding = lended > repaid ? lended - repaid : BigInt(0)

    hre.log(`Redeem from ${poolAddress}${key ? ` (${key})` : ''}`, {
      star: true,
    })
    hre.log(`  wallet          ${sender}`)
    hre.log(`  principal       ${symbol} (${dp} decimals)`)
    hre.log(`  shares held     ${shareBalance} of ${totalSupply}`)
    hre.log(`  pool balance    ${units(held, dp)} ${symbol}`)
    hre.log(`  out on loan     ${units(outstanding, dp)} ${symbol}`)

    if (shareBalance === BigInt(0)) {
      hre.log('  nothing to redeem', { star: true })
      return
    }

    const shares = args.shares ? BigInt(args.shares as string) : shareBalance
    if (shares > shareBalance) {
      throw new Error(
        `asked for ${shares} shares, deployer holds ${shareBalance}`
      )
    }

    // Redeeming more than the pool is holding idle would come out of principal
    // a borrower still has to be able to repay against.
    if (!args.shares && outstanding > BigInt(0)) {
      throw new Error(
        `${poolAddress} has ${units(outstanding, dp)} ${symbol} out on loan. ` +
          `Redeeming the whole balance would draw on it. Name an amount with ` +
          `--shares if that is what you mean.`
      )
    }

    // The pool enforces a delay from the last share transfer. Say so rather
    // than sending a transaction that reverts with "SR".
    const [delay, lastTransfer] = await Promise.all([
      pool.withdrawDelayTimeSeconds() as Promise<bigint>,
      pool.getSharesLastTransferredAt(sender) as Promise<bigint>,
    ])
    const now = BigInt(
      (await ethers.provider.getBlock('latest'))?.timestamp ?? 0
    )
    if (now < lastTransfer + delay) {
      throw new Error(
        `shares last moved at ${lastTransfer} and the pool's withdraw delay is ` +
          `${delay}s, so this is redeemable in ${
            lastTransfer + delay - now
          }s. Nothing sent.`
      )
    }

    hre.log(`  redeeming       ${shares} shares`)
    if (args.dryRun === true) {
      hre.log('dry run — nothing sent', { star: true })
      return
    }

    const before = (await principal.balanceOf(sender)) as bigint
    const tx = await (pool as any).redeem(shares, sender, sender)
    hre.log(`  sent            ${tx.hash}`)
    const rcpt = await tx.wait()
    if (!rcpt || rcpt.status !== 1) {
      throw new Error(`redeem reverted: ${tx.hash}`)
    }

    // Asserted rather than assumed: the only honest confirmation is the
    // principal this wallet actually gained.
    const after = (await principal.balanceOf(sender)) as bigint
    const gained = after - before
    hre.log(`  received        ${units(gained, dp)} ${symbol}`)
    if (gained <= BigInt(0)) {
      throw new Error(
        `redeem confirmed in ${tx.hash} but the wallet's ${symbol} balance did not rise`
      )
    }
    hre.log(`  shares left     ${await pool.balanceOf(sender)}`)
    hre.log(`Done — redeemed from ${poolAddress}`, { star: true })
  })
