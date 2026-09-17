import fs from 'fs'
import path from 'path'

import { ContractTransactionResponse, Interface } from 'ethers'
import { task, types } from 'hardhat/config'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

import {
  ChainBootstrapConfig,
  MARKET_FEE_PERCENT,
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
  .setAction(async (args, hre): Promise<void> => {
    const { network, ethers } = hre

    const config = await loadConfig(network.name)
    if (!config) {
      throw new Error(
        `No bootstrap config for network "${network.name}". Add packages/contracts/config/chain-bootstrap/${network.name}.ts`
      )
    }

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
    const forwarder = await (
      await hre.contracts.get('SmartCommitmentForwarder')
    ).getAddress()

    const protocolOwner: string = await tellerV2.owner()
    console.log(`  protocol owner   ${protocolOwner}`)

    const receipt = readReceipt(hre, config)

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

    // ---- Pools -------------------------------------------------------------
    //
    // One pool per collateral per market: a pool pins a single marketId and a
    // single maxLoanDuration, so a 7 day and a 30 day offer against the same
    // collateral are two separate pools.
    for (const market of config.markets) {
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

      // A pool's initialize() calls approveMarketForwarder on TellerV2, which
      // reverts with "Forwarder must be trusted by the market" unless the
      // market already trusts the SmartCommitmentForwarder. Only the market
      // owner can grant that, and creating a market does not grant it, so
      // every pool deploy fails until this runs. Checked rather than assumed,
      // so a market created by an earlier run is repaired rather than skipped.
      if (created) {
        const trusted = await tellerV2.isTrustedMarketForwarder(
          created.marketId,
          forwarder
        )
        if (!trusted) {
          console.log(
            `\n  trusting the forwarder for market ${created.marketId}`
          )
          console.log(`    forwarder        ${forwarder}`)
          const trustTx = await tellerV2.setTrustedMarketForwarder(
            created.marketId,
            forwarder
          )
          const trustRcpt = await trustTx.wait()
          console.log(`    -> ${trustRcpt?.hash ?? trustTx.hash}`)
        }
      }

      for (const collateral of config.collateral) {
        if (collateral.markets && !collateral.markets.includes(market.key)) {
          console.log(
            `\n  skipping ${collateral.symbol} on ${market.key}: not in its markets list`
          )
          continue
        }
        const key = `${market.key}:${collateral.symbol}`
        if (receipt.pools[key]) {
          console.log(
            `\n  pool ${key} already deployed: ${receipt.pools[key].address}`
          )
          continue
        }

        console.log(
          `\n  deploying pool ${key} (${config.principal.symbol} / ${collateral.symbol})`
        )
        console.log(`    market id        ${marketId}`)
        console.log(`    max duration     ${market.durationSeconds}s`)
        console.log(
          `    collateral ratio ${collateral.collateralRatio} (${(
            (10000 / collateral.collateralRatio) *
            100
          ).toFixed(1)}% LTV)`
        )
        console.log(`    oracle pool      ${collateral.pool}`)
        console.log(`    twap interval    ${config.twapInterval}s`)

        if (args.dryRun) continue

        const groupConfig = {
          principalTokenAddress: config.principal.address,
          collateralTokenAddress: collateral.token,
          marketId,
          maxLoanDuration: market.durationSeconds,
          interestRateLowerBound: config.interestRateLowerBound,
          interestRateUpperBound: config.interestRateUpperBound,
          liquidityThresholdPercent: config.liquidityThresholdPercent,
          collateralRatio: collateral.collateralRatio,
        }

        const routes = [
          {
            pool: collateral.pool,
            zeroForOne: collateral.zeroForOne,
            twapInterval: config.twapInterval,
            token0Decimals: collateral.token0Decimals,
            token1Decimals: collateral.token1Decimals,
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
