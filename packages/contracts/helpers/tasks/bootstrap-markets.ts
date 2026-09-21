import fs from 'fs'
import path from 'path'

import { ContractTransactionResponse, Interface } from 'ethers'
import { task, types } from 'hardhat/config'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

import {
  ChainBootstrapConfig,
  MARKET_FEE_PERCENT,
  MarketConfig,
  MarketPurpose,
  PROTOCOL_FEE_BPS,
} from '../../config/chain-bootstrap/types'

/**
 * Brings a freshly deployed chain up to a usable state: the markets borrowers
 * bid into, and the lender pools that fund them.
 *
 * Markets and pools are both permissionless to create, so the deployer signs
 * those directly. The protocol fee settings live behind TellerV2's owner, which
 * on a live chain is the multisig, so those are written out as a Safe
 * Transaction Builder batch instead of attempted and reverted.
 *
 * Re-running is safe. Everything already created is read back from the receipt
 * at deployments/<network>/market-bootstrap.json and skipped.
 */

const BULLET = 1 // PaymentType.Bullet
const SECONDS = 0 // PaymentCycleType.Seconds

interface BootstrapReceipt {
  chainId: number
  principal: string
  markets: Record<string, { marketId: string; owner: string; txHash: string }>
  pools: Record<string, { address: string; txHash: string }>
  /**
   * Pools that held a key and no longer do, newest last.
   *
   * A replaced pool is not destroyed and does not stop working - its lenders
   * can still redeem, and anything holding its address keeps functioning. It
   * is only no longer the pool this key names. Keeping the address here is
   * what lets that redemption be found later, and what stops a replacement
   * from reading as an unexplained change of address in the diff.
   */
  retiredPools?: Record<
    string,
    Array<{
      address: string
      txHash: string
      retiredAt: string
      /**
       * Why this pool is not the one the key names, when "it was replaced" is
       * not the answer. A duplicate created by a re-run against a stale
       * receipt belongs here too: it is a pool at this key that is not the
       * live one, which is what this list means, but it was never live and a
       * reader should not go looking for lenders in it.
       */
      note?: string
    }>
  >
}

/**
 * Minimal shapes for the three contracts this task drives. Typechain bindings
 * only exist after a compile, and `hre.contracts.get` is otherwise untyped, so
 * the handful of methods used here are declared inline.
 */
interface MarketRegistryLike {
  marketCount: () => Promise<bigint>
  [signature: string]: unknown
}

interface TellerV2Like {
  owner: () => Promise<string>
  isTrustedMarketForwarder: (
    marketId: string,
    forwarder: string
  ) => Promise<boolean>
  setTrustedMarketForwarder: (
    marketId: string,
    forwarder: string
  ) => Promise<ContractTransactionResponse>
  protocolFee: () => Promise<bigint>
  getProtocolFeeRecipient: () => Promise<string>
  getAddress: () => Promise<string>
}

interface PoolFactoryLike {
  deployLenderCommitmentGroupPool: (
    initialPrincipalAmount: number,
    commitmentGroupConfig: Record<string, unknown>,
    poolOracleRoutes: Array<Record<string, unknown>>
  ) => Promise<ContractTransactionResponse>
  interface: Interface
}

const receiptPath = (hre: HardhatRuntimeEnvironment): string =>
  path.join(
    hre.config.paths.deployments ?? 'deployments',
    hre.network.name,
    'market-bootstrap.json'
  )

const readReceipt = (
  hre: HardhatRuntimeEnvironment,
  config: ChainBootstrapConfig
): BootstrapReceipt => {
  const file = receiptPath(hre)
  if (fs.existsSync(file)) {
    return JSON.parse(fs.readFileSync(file, 'utf8')) as BootstrapReceipt
  }
  return {
    chainId: config.chainId,
    principal: config.principal.address,
    markets: {},
    pools: {},
  }
}

const writeReceipt = (
  hre: HardhatRuntimeEnvironment,
  receipt: BootstrapReceipt
): void => {
  const file = receiptPath(hre)
  fs.mkdirSync(path.dirname(file), { recursive: true })
  fs.writeFileSync(file, `${JSON.stringify(receipt, null, 2)}\n`)
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

task(
  'bootstrap-markets',
  'Creates the standard markets and lender pools for a newly launched chain'
)
  .addOptionalParam(
    'dryRun',
    'Print what would be created without sending transactions',
    false,
    types.boolean
  )
  .addOptionalParam(
    'replace',
    'Comma-separated receipt keys to deploy a replacement pool for, e.g. "short:ARGUS". ' +
      'The existing pool keeps working and moves to retiredPools; the key points at the new one.',
    '',
    types.string
  )
  .addOptionalParam(
    'forceReplace',
    'Replace even a pool with loans outstanding. Delisting one strands a position ' +
      'someone still has to repay or liquidate, so this is never the default.',
    false,
    types.boolean
  )
  .setAction(async (args, hre): Promise<void> => {
    const { network, ethers } = hre

    const config = await loadConfig(network.name)
    if (!config) {
      throw new Error(
        `No bootstrap config for network "${network.name}". Add packages/contracts/config/chain-bootstrap/${network.name}.ts`
      )
    }

    // Replacement is opt-in per key and never inferred from config drift:
    // deploying a pool spends principal and splits liquidity across two
    // addresses, which is not something an edit to a config file should cause
    // as a side effect.
    const replaceKeys = new Set(
      String(args.replace ?? '')
        .split(',')
        .map((k) => k.trim())
        .filter(Boolean)
    )

    const chainId = Number((await ethers.provider.getNetwork()).chainId)
    if (chainId !== config.chainId) {
      throw new Error(
        `Connected to chain ${chainId} but ${network.name}.ts declares ${config.chainId}`
      )
    }

    const [signer] = await ethers.getSigners()
    const deployer = await signer.getAddress()
    console.log(`\nBootstrapping ${network.name} (chain ${chainId})`)
    console.log(`  deployer         ${deployer}`)
    console.log(
      `  balance          ${ethers.formatEther(
        await ethers.provider.getBalance(deployer)
      )} ETH`
    )

    const marketRegistry = (await hre.contracts.get(
      'MarketRegistry'
    )) as unknown as MarketRegistryLike
    const tellerV2 = (await hre.contracts.get(
      'TellerV2'
    )) as unknown as TellerV2Like
    const factory = (await hre.contracts.get(
      'LenderCommitmentGroupFactory_V2'
    )) as unknown as PoolFactoryLike
    // One forwarder per purpose. A market's slot holds a single address and
    // setTrustedMarketForwarder overwrites it, so which one a market gets is
    // decided once, at creation, and is the whole of what separates an
    // offers market from a pools market. See MarketPurpose.
    const forwarders: Record<MarketPurpose, string> = {
      pools: await (
        await hre.contracts.get('SmartCommitmentForwarder')
      ).getAddress(),
      offers: await (
        await hre.contracts.get('LenderCommitmentForwarderAlpha')
      ).getAddress(),
    }
    const purposeOf = (market: MarketConfig): MarketPurpose =>
      market.purpose ?? 'pools'
    console.log(`  pools forwarder  ${forwarders.pools}`)
    console.log(`  offers forwarder ${forwarders.offers}`)

    const protocolOwner: string = await tellerV2.owner()
    console.log(`  protocol owner   ${protocolOwner}`)

    const receipt = readReceipt(hre, config)

    // A --replace key that names no pool would otherwise pass silently: the
    // key is simply created as if new, and the pool it was meant to replace
    // stays listed. That reads as a no-op run rather than a typo.
    const unknownReplaceKeys = [...replaceKeys].filter((k) => !receipt.pools[k])
    if (unknownReplaceKeys.length > 0) {
      throw new Error(
        `--replace names ${unknownReplaceKeys.join(', ')}, which ${
          unknownReplaceKeys.length === 1 ? 'is not a pool' : 'are not pools'
        } in deployments/${hre.network.name}/market-bootstrap.json. ` +
          `Known keys: ${Object.keys(receipt.pools).join(', ') || '(none)'}`
      )
    }

    // ---- Markets -----------------------------------------------------------
    //
    // The deployer holds market ownership. Handing it straight to the multisig
    // would mean a Safe round trip for every future parameter tweak, and the
    // market owner cannot move funds, only set terms.
    for (const market of config.markets) {
      if (receipt.markets[market.key]) {
        console.log(
          `\n  market ${market.key} already created: id ${
            receipt.markets[market.key].marketId
          }`
        )
        continue
      }

      const uri = `teller-${network.name}-${market.key}`
      console.log(`\n  creating ${market.label} market`)
      console.log(`    payment cycle    ${market.durationSeconds}s`)
      console.log(`    default after    ${market.paymentDefaultDuration}s`)
      console.log(`    bid expiration   ${market.bidExpirationTime}s`)
      console.log(
        `    marketplace fee  ${MARKET_FEE_PERCENT} (${
          MARKET_FEE_PERCENT / 100
        }%)`
      )

      if (args.dryRun) continue

      const createMarket = marketRegistry[
        'createMarket(address,uint32,uint32,uint32,uint16,bool,bool,uint8,uint8,string)'
      ] as (...callArgs: unknown[]) => Promise<ContractTransactionResponse>

      const tx = await createMarket(
        deployer,
        market.durationSeconds,
        market.paymentDefaultDuration,
        market.bidExpirationTime,
        MARKET_FEE_PERCENT,
        false, // lender attestation not required
        false, // borrower attestation not required
        BULLET,
        SECONDS,
        uri
      )
      const rcpt = await tx.wait()

      const marketId: bigint = await marketRegistry.marketCount()
      receipt.markets[market.key] = {
        marketId: marketId.toString(),
        owner: deployer,
        txHash: rcpt?.hash ?? tx.hash,
      }
      writeReceipt(hre, receipt)
      console.log(`    -> market id ${marketId} (${rcpt?.hash ?? tx.hash})`)
    }

    // ---- Forwarder trust ---------------------------------------------------
    //
    // Creating a market does not grant it, and only the market owner can, so
    // until this runs every pool deploy into a pools market reverts with
    // `Forwarder must be trusted by the market` — and so does every lending
    // offer published into an offers market.
    //
    // Checked rather than assumed, so a market created by an earlier run is
    // repaired rather than skipped. Never re-granted when already correct:
    // the slot holds one address, so writing it again on a market that has
    // the right forwarder is a no-op, and writing the wrong one would take
    // a working market off line.
    for (const market of config.markets) {
      const created = receipt.markets[market.key]
      if (!created) continue
      const purpose = purposeOf(market)
      const forwarder = forwarders[purpose]
      const trusted = await tellerV2.isTrustedMarketForwarder(
        created.marketId,
        forwarder
      )
      if (trusted) continue
      console.log(
        `\n  trusting the ${purpose} forwarder for market ${created.marketId}`
      )
      console.log(`    forwarder        ${forwarder}`)
      if (args.dryRun) continue
      const trustTx = await tellerV2.setTrustedMarketForwarder(
        created.marketId,
        forwarder
      )
      const trustRcpt = await trustTx.wait()
      console.log(`    -> ${trustRcpt?.hash ?? trustTx.hash}`)
    }

    // ---- Pools -------------------------------------------------------------
    //
    // One pool per collateral per market: a pool pins a single marketId and a
    // single maxLoanDuration, so a 7 day and a 30 day offer against the same
    // collateral are two separate pools.
    for (const market of config.markets) {
      // An offers market trusts Alpha, not the SmartCommitmentForwarder, so a
      // pool's initialize() would revert in it. It exists to be published
      // into, not deployed into.
      if (purposeOf(market) === 'offers') {
        console.log(`\n  no pools for ${market.key}: it is an offers market`)
        continue
      }
      const created = receipt.markets[market.key]
      if (!created && !args.dryRun) {
        console.log(`\n  skipping pools for ${market.key}: market not created`)
        continue
      }
      // A dry run creates no markets, so there is no id to pin a pool to. Keep
      // going anyway with a placeholder: the point of a dry run is to review
      // the parameters every pool will be built from, and skipping the whole
      // section leaves the riskiest half of the config unprinted.
      const marketId = created?.marketId ?? '<pending>'


      // Both directions in one list. An ordinary pool lends the chain's
      // principal against an asset; an inverse pool lends the asset against the
      // principal. Everything after this point is identical for the two, so
      // they differ here and nowhere else.
      const specs = [
        ...config.collateral.map((c) => ({
          key: `${market.key}:${c.symbol}`,
          label: `${config.principal.symbol} / ${c.symbol}`,
          principalToken: config.principal.address,
          collateralToken: c.token,
          collateralRatio: c.collateralRatio,
          pool: c.pool,
          zeroForOne: c.zeroForOne,
          token0Decimals: c.token0Decimals,
          token1Decimals: c.token1Decimals,
          markets: c.markets,
          symbol: c.symbol,
          interestRateLowerBound: c.interestRateLowerBound,
          interestRateUpperBound: c.interestRateUpperBound,
        })),
        ...(config.inverse ?? []).map((i) => ({
          key: `${market.key}:inverse:${i.symbol}`,
          label: `${i.symbol} / ${config.principal.symbol}`,
          principalToken: i.token,
          collateralToken: config.principal.address,
          collateralRatio: i.collateralRatio,
          pool: i.pool,
          zeroForOne: i.zeroForOne,
          token0Decimals: i.token0Decimals,
          token1Decimals: i.token1Decimals,
          markets: i.markets,
          symbol: i.symbol,
          interestRateLowerBound: i.interestRateLowerBound,
          interestRateUpperBound: i.interestRateUpperBound,
        })),
      ]

      for (const spec of specs) {
        if (spec.markets && !spec.markets.includes(market.key)) {
          console.log(
            `\n  skipping ${spec.label} on ${market.key}: not in its markets list`
          )
          continue
        }
        const key = spec.key
        const existing = receipt.pools[key]
        if (existing && !replaceKeys.has(key)) {
          console.log(`\n  pool ${key} already deployed: ${existing.address}`)
          continue
        }

        if (existing) {
          // Replacing is for the parameters that cannot be changed on a live
          // pool - the rate band above all, which `initialize` writes and no
          // implementation exposes a setter for. The pool being replaced is
          // not destroyed: it keeps working and its lenders keep their claim.
          // What changes is which pool this key names, and therefore what the
          // front ends list.
          //
          // The one case that is not safe is a pool with loans outstanding.
          // Delisting that hides a position someone still has to repay or
          // liquidate, and the borrower does not stop owing it because a
          // config file moved on. So it is refused unless asked for twice.
          const pool = await ethers.getContractAt(
            [
              'function totalPrincipalTokensLended() view returns (uint256)',
              'function totalPrincipalTokensRepaid() view returns (uint256)',
              'function totalSupply() view returns (uint256)',
            ],
            existing.address
          )
          const [lended, repaid, shares] = await Promise.all([
            pool.totalPrincipalTokensLended() as Promise<bigint>,
            pool.totalPrincipalTokensRepaid() as Promise<bigint>,
            pool.totalSupply() as Promise<bigint>,
          ])
          const outstanding = lended > repaid ? lended - repaid : BigInt(0)

          console.log(`\n  replacing pool ${key}: ${existing.address}`)
          console.log(`    shares outstanding   ${shares}`)
          console.log(`    principal on loan    ${outstanding}`)

          if (outstanding > BigInt(0) && args.forceReplace !== true) {
            throw new Error(
              `Refusing to replace ${key} (${existing.address}): ${outstanding} principal is still out on loan. ` +
                `Retiring it delists a position that still has to be repaid or liquidated. ` +
                `Wait for those loans to close, or pass --force-replace if you have a reason.`
            )
          }
          if (shares > BigInt(0)) {
            console.log(
              `    note: lenders still hold shares here and can redeem them at ${existing.address} ` +
                `after it stops being listed.`
            )
          }
        }

        console.log(`\n  deploying pool ${key} (${spec.label})`)
        console.log(`    market id        ${marketId}`)
        console.log(`    max duration     ${market.durationSeconds}s`)
        console.log(
          `    collateral ratio ${spec.collateralRatio} (${(
            (10000 / spec.collateralRatio) *
            100
          ).toFixed(1)}% LTV)`
        )
        console.log(`    oracle pool      ${spec.pool}`)
        console.log(`    zeroForOne       ${spec.zeroForOne}`)
        console.log(`    twap interval    ${config.twapInterval}s`)

        // A pool's rate band is written in its `initialize` and has no setter
        // on any implementation, so this is the only moment it can be chosen.
        const rateLowerBound =
          spec.interestRateLowerBound ?? config.interestRateLowerBound
        const rateUpperBound =
          spec.interestRateUpperBound ?? config.interestRateUpperBound
        if (rateLowerBound > rateUpperBound) {
          throw new Error(
            `Pool ${key}: interestRateLowerBound ${rateLowerBound} is above interestRateUpperBound ${rateUpperBound}`
          )
        }
        const rateSource =
          spec.interestRateLowerBound !== undefined ||
          spec.interestRateUpperBound !== undefined
            ? 'this pool'
            : `the chain`
        console.log(
          `    interest rate    ${(rateLowerBound / 100).toFixed(2)}% - ${(
            rateUpperBound / 100
          ).toFixed(2)}% (from ${rateSource})`
        )

        if (args.dryRun) continue

        const groupConfig = {
          principalTokenAddress: spec.principalToken,
          collateralTokenAddress: spec.collateralToken,
          marketId,
          maxLoanDuration: market.durationSeconds,
          interestRateLowerBound: rateLowerBound,
          interestRateUpperBound: rateUpperBound,
          liquidityThresholdPercent: config.liquidityThresholdPercent,
          collateralRatio: spec.collateralRatio,
        }

        const routes = [
          {
            pool: spec.pool,
            zeroForOne: spec.zeroForOne,
            twapInterval: config.twapInterval,
            token0Decimals: spec.token0Decimals,
            token1Decimals: spec.token1Decimals,
          },
        ]

        // Lenders deposit after launch, so the pool opens with no principal.
        const tx = await factory.deployLenderCommitmentGroupPool(
          0,
          groupConfig,
          routes
        )
        const rcpt = await tx.wait()

        const event = rcpt?.logs
          ?.map((log) => {
            try {
              return factory.interface.parseLog({
                topics: [...log.topics],
                data: log.data,
              })
            } catch {
              return null
            }
          })
          .find((parsed) => parsed?.name === 'DeployedLenderGroupContract')

        const address = event?.args?.[0] as string | undefined
        if (!address) {
          throw new Error(
            `Pool ${key} deployed in ${rcpt?.hash ?? tx.hash} but no DeployedLenderGroupContract event was found`
          )
        }

        if (existing) {
          receipt.retiredPools = receipt.retiredPools ?? {}
          receipt.retiredPools[key] = [
            ...(receipt.retiredPools[key] ?? []),
            { ...existing, retiredAt: new Date().toISOString() },
          ]
        }
        receipt.pools[key] = { address, txHash: rcpt?.hash ?? tx.hash }
        writeReceipt(hre, receipt)
        console.log(`    -> ${address} (${rcpt?.hash ?? tx.hash})`)
      }
    }

    // ---- Protocol fee (owner gated) ----------------------------------------
    const currentFee: bigint = await tellerV2.protocolFee()
    const currentRecipient: string = await tellerV2.getProtocolFeeRecipient()

    const safeTxs: Array<{
      to: string
      value: string
      data: string | null
      contractMethod: unknown
      contractInputsValues: unknown
    }> = []

    if (currentFee !== BigInt(PROTOCOL_FEE_BPS)) {
      safeTxs.push({
        to: await tellerV2.getAddress(),
        value: '0',
        data: null,
        contractMethod: {
          name: 'setProtocolFee',
          payable: false,
          inputs: [{ name: 'newFee', type: 'uint16', internalType: 'uint16' }],
        },
        contractInputsValues: { newFee: String(PROTOCOL_FEE_BPS) },
      })
    }

    if (
      currentRecipient.toLowerCase() !==
      config.protocolFeeRecipient.toLowerCase()
    ) {
      safeTxs.push({
        to: await tellerV2.getAddress(),
        value: '0',
        data: null,
        contractMethod: {
          name: 'setProtocolFeeRecipient',
          payable: false,
          inputs: [
            { name: '_recipient', type: 'address', internalType: 'address' },
          ],
        },
        contractInputsValues: { _recipient: config.protocolFeeRecipient },
      })
    }

    console.log(
      `\n  protocol fee     ${currentFee} bps (target ${PROTOCOL_FEE_BPS})`
    )
    console.log(`  fee recipient    ${currentRecipient}`)
    console.log(`                   target ${config.protocolFeeRecipient}`)

    if (safeTxs.length === 0) {
      console.log(
        '\n  protocol fee settings already correct, no Safe batch needed'
      )
    } else {
      const batch = {
        version: '1.0',
        chainId: String(config.chainId),
        createdAt: Date.now(),
        meta: {
          name: `Protocol fee settings for ${network.name}`,
          description:
            'Sets the TellerV2 protocol fee and fee recipient. Both are owner gated.',
          txBuilderVersion: '1.16.5',
        },
        transactions: safeTxs,
      }
      const file = path.join(
        hre.config.paths.deployments ?? 'deployments',
        network.name,
        'protocol-fee-safe-batch.json'
      )
      fs.mkdirSync(path.dirname(file), { recursive: true })
      fs.writeFileSync(file, `${JSON.stringify(batch, null, 2)}\n`)
      console.log(
        `\n  ${safeTxs.length} owner-gated call(s) written for the multisig:`
      )
      console.log(`    ${file}`)
      console.log(
        `    Import into the Safe Transaction Builder for ${protocolOwner}`
      )
    }

    console.log(`\n  receipt written to ${receiptPath(hre)}\n`)
  })
