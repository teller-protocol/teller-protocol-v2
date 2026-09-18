import { ContractTransactionResponse } from 'ethers'
import { task, types } from 'hardhat/config'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

/**
 * Reconciles `paymentDefaultDuration` on markets that already exist.
 *
 * `bootstrap-markets` cannot do this. It skips any market already recorded in
 * deployments/<network>/market-bootstrap.json, so it only ever sets this value
 * at creation time and never reconciles it on a live market. The receipt is
 * also an incomplete picture of a chain: markets created before the receipt
 * existed - or on a chain that was never bootstrapped through it at all, which
 * is every chain older than that task - appear nowhere in it. So this task is
 * driven by market ids read from the registry, not by the receipt, and needs
 * neither a receipt nor a config/chain-bootstrap entry to run.
 *
 * What the value does, precisely, because it is easy to assume something
 * worse: TellerV2 snapshots the market's duration into `bidDefaultDuration`
 * when a bid is *submitted*, and `_isLoanDefaulted` reads that per-bid
 * snapshot forever after. Changing it here therefore governs bids submitted
 * from now on and cannot retroactively shorten the grace on a loan that is
 * already live - which is what MarketRegistry's own NatSpec means by "changing
 * this value does not change the terms of existing loans".
 *
 * For a bid submitted after this runs, `duration` seconds past the due date
 * makes the loan defaultable by the lender. Liquidation by a third party is
 * further behind TellerV2's `LIQUIDATION_DELAY`, a hardcoded 24 hours, so a
 * five minute grace means defaultable at +5m and liquidateable at +24h05m.
 *
 * Ownership is per-market and belongs to whoever created it, which is the
 * deployer for a market this chain's bootstrap created. A market owned by
 * anyone else is reported and skipped rather than attempted and reverted.
 *
 *   yarn hh set-market-payment-default --network robinhood \
 *     --seconds 300 --markets 1,2,3,4 --dry-run true
 */

/**
 * Minimal shape for the one contract this task drives. Typechain bindings only
 * exist after a compile and `hre.contracts.get` is otherwise untyped, so the
 * handful of methods used here are declared inline - the same reason
 * bootstrap-markets declares its own.
 */
interface MarketRegistryLike {
  marketCount: () => Promise<bigint>
  getMarketOwner: (marketId: bigint) => Promise<string>
  getPaymentDefaultDuration: (marketId: bigint) => Promise<bigint>
  setPaymentDefaultDuration: (
    marketId: bigint,
    duration: number
  ) => Promise<ContractTransactionResponse>
}

const UINT32_MAX = 4294967295

/** "1,2, 3" -> [1n, 2n, 3n], rejecting anything that is not a market id. */
const parseMarketIds = (raw: string): bigint[] => {
  const ids = raw
    .split(',')
    .map((part) => part.trim())
    .filter((part) => part.length > 0)
    .map((part) => {
      if (!/^\d+$/.test(part)) {
        throw new Error(`"${part}" is not a market id. Expected e.g. 1,2,3,4`)
      }
      return BigInt(part)
    })

  return [...new Set(ids)].sort((a, b) => (a < b ? -1 : a > b ? 1 : 0))
}

task(
  'set-market-payment-default',
  "Sets a market's payment default duration (the grace period before a new loan can be defaulted)"
)
  .addParam(
    'seconds',
    'New payment default duration, in seconds',
    undefined,
    types.int
  )
  .addOptionalParam(
    'markets',
    'Comma-separated market ids. Omitted means every market on the registry.',
    '',
    types.string
  )
  .addOptionalParam(
    'dryRun',
    'Print what would be written without sending transactions',
    false,
    types.boolean
  )
  .setAction(async (args, hre: HardhatRuntimeEnvironment): Promise<void> => {
    const { network, ethers } = hre

    const duration = Number(args.seconds)
    if (!Number.isInteger(duration) || duration < 0 || duration > UINT32_MAX) {
      throw new Error(
        `--seconds must be a whole number of seconds that fits a uint32 (0..${UINT32_MAX}), got "${args.seconds}"`
      )
    }

    const registry = (await hre.contracts.get(
      'MarketRegistry'
    )) as unknown as MarketRegistryLike
    const registryAddress = await (
      await hre.contracts.get('MarketRegistry')
    ).getAddress()

    const [signer] = await ethers.getSigners()
    const sender = await signer.getAddress()

    // Enumerating from the registry rather than from a receipt is what lets
    // this run on a chain the bootstrap task never touched. Ids start at 1:
    // MarketRegistry increments marketCount before using it as the new id.
    const count = await registry.marketCount()
    const requested = parseMarketIds(args.markets as string)
    const marketIds =
      requested.length > 0
        ? requested
        : Array.from({ length: Number(count) }, (_, i) => BigInt(i + 1))

    console.log(`network   ${network.name} (${network.config.chainId})`)
    console.log(`registry  ${registryAddress}`)
    console.log(`signer    ${sender}`)
    console.log(`target    ${duration}s`)
    console.log(
      `markets   ${marketIds.join(', ') || '(none)'} of ${count} on the registry`
    )

    // An id past marketCount reads back as an unset market - owner
    // 0x0, duration 0 - and writing to it would revert on the owner check
    // anyway. Saying so plainly beats letting it look like a permissions
    // problem.
    const outOfRange = marketIds.filter((id) => id > count || id === 0n)
    if (outOfRange.length > 0) {
      throw new Error(
        `Market id(s) ${outOfRange.join(', ')} do not exist on ${
          network.name
        }: the registry has ${count} market(s), numbered 1..${count}.`
      )
    }

    let written = 0
    let skipped = 0

    for (const marketId of marketIds) {
      const owner = await registry.getMarketOwner(marketId)
      const existing = await registry.getPaymentDefaultDuration(marketId)

      console.log(`\n  market ${marketId}`)
      console.log(`    owner        ${owner}`)
      console.log(`    current      ${existing}s`)
      console.log(`    new          ${duration}s`)

      if (owner.toLowerCase() !== sender.toLowerCase()) {
        console.log('    owned by another address - skipping')
        skipped++
        continue
      }

      if (existing === BigInt(duration)) {
        console.log('    unchanged - skipping')
        skipped++
        continue
      }

      if (args.dryRun) continue

      const tx = await registry.setPaymentDefaultDuration(marketId, duration)
      const rcpt = await tx.wait()
      console.log(`    -> ${rcpt?.hash ?? tx.hash}`)

      // Read it back. The setter is a silent no-op when the value already
      // matches and reverts on the owner check otherwise, so a receipt alone
      // does not prove the registry now holds what was asked for.
      const after = await registry.getPaymentDefaultDuration(marketId)
      console.log(`    confirmed    ${after}s`)
      if (after !== BigInt(duration)) {
        throw new Error(
          `Market ${marketId} still reads ${after}s after the write. Expected ${duration}s.`
        )
      }
      written++
    }

    console.log(
      `\ndone: ${written} market(s) written, ${skipped} skipped${
        args.dryRun ? ' (dry run: nothing sent)' : ''
      }`
    )
  })
