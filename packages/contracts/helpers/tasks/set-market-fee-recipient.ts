import { ContractTransactionResponse, getAddress, ZeroAddress } from 'ethers'
import { task, types } from 'hardhat/config'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

/**
 * Sets where a market's fee goes.
 *
 * TellerV2 pays the marketplace fee out of every loan it funds, to
 * `MarketRegistry.getMarketFeeRecipient(marketId)`. A market created without
 * one set - which is every market `bootstrap-markets` creates - falls back to
 * the market owner, i.e. the deployer. This points it somewhere else.
 *
 * It governs loans funded from now on. A fee already paid stays where it went.
 *
 * Same shape as `set-market-payment-default`: ids come off the registry, not
 * the bootstrap receipt, so it runs on any chain; a market owned by another
 * address is reported and skipped rather than attempted and reverted; and the
 * value is read back after the write, because `getMarketFeeRecipient` falls
 * back to the owner when unset and a receipt alone proves nothing.
 *
 *   yarn hh set-market-fee-recipient --network robinhood \
 *     --recipient 0x... --markets 3 --dry-run true
 */

interface MarketRegistryLike {
  marketCount: () => Promise<bigint>
  getMarketOwner: (marketId: bigint) => Promise<string>
  getMarketFeeRecipient: (marketId: bigint) => Promise<string>
  getMarketplaceFee: (marketId: bigint) => Promise<bigint>
  setMarketFeeRecipient: (
    marketId: bigint,
    recipient: string
  ) => Promise<ContractTransactionResponse>
}

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
  'set-market-fee-recipient',
  "Sets the address a market's marketplace fee is paid to"
)
  .addParam('recipient', 'Address to receive the market fee', undefined, types.string)
  .addParam(
    'markets',
    'Comma-separated market ids. Required: a fee recipient is never swept across every market by default.',
    undefined,
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

    // getAddress throws on a malformed address and on a wrong EIP-55 checksum,
    // which is the point: this is where the money goes.
    const recipient = getAddress(String(args.recipient).trim())
    if (recipient === ZeroAddress) {
      throw new Error(
        '--recipient is the zero address. MarketRegistry reads that as "unset" and pays the owner.'
      )
    }

    const marketIds = parseMarketIds(args.markets as string)
    if (marketIds.length === 0) {
      throw new Error('--markets is empty. Name the market ids to change.')
    }

    const registryContract = await hre.contracts.get('MarketRegistry')
    const registry = registryContract as unknown as MarketRegistryLike
    const registryAddress = await registryContract.getAddress()

    const [signer] = await ethers.getSigners()
    const sender = await signer.getAddress()
    const count = await registry.marketCount()

    console.log(`network   ${network.name} (${network.config.chainId})`)
    console.log(`registry  ${registryAddress}`)
    console.log(`signer    ${sender}`)
    console.log(`recipient ${recipient}`)
    console.log(`markets   ${marketIds.join(', ')} of ${count} on the registry`)

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
      const existing = await registry.getMarketFeeRecipient(marketId)
      const fee = await registry.getMarketplaceFee(marketId)

      console.log(`\n  market ${marketId}`)
      console.log(`    owner        ${owner}`)
      console.log(`    fee          ${fee} bps`)
      console.log(`    current      ${existing}`)
      console.log(`    new          ${recipient}`)

      if (owner.toLowerCase() !== sender.toLowerCase()) {
        console.log('    owned by another address - skipping')
        skipped++
        continue
      }

      if (existing.toLowerCase() === recipient.toLowerCase()) {
        console.log('    unchanged - skipping')
        skipped++
        continue
      }

      if (args.dryRun) continue

      const tx = await registry.setMarketFeeRecipient(marketId, recipient)
      const rcpt = await tx.wait()
      console.log(`    -> ${rcpt?.hash ?? tx.hash}`)

      const after = await registry.getMarketFeeRecipient(marketId)
      console.log(`    confirmed    ${after}`)
      if (after.toLowerCase() !== recipient.toLowerCase()) {
        throw new Error(
          `Market ${marketId} still pays ${after} after the write. Expected ${recipient}.`
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
