import { DeployFunction } from 'hardhat-deploy/dist/types'

import { getNetworkName } from '../../config'
import { isOffersOnlyChain } from '../../config/chains/features'

/**
 * LenderCommitmentForwarderStaged: accepts Alpha commitments in two
 * transactions (submit bid, then accept bid) so each one stays inside Rome's
 * per-transaction Solana account limit. Lenders keep creating offers on Alpha.
 *
 * Plain constructor deploy, no proxy: every proxy hop costs accounts on Rome.
 *
 * CHECK_LENDER_ON_ACCEPT defaults to true. Set
 * STAGED_CHECK_LENDER_ON_ACCEPT=false to deploy the variant whose accept does
 * not read Alpha at all.
 *
 * After deploying, per market:
 *  - market owner: TellerV2.setTrustedMarketForwarder(marketId, staged)
 *  - lender and borrower: TellerV2.approveMarketForwarder(marketId, staged)
 */
const deployFn: DeployFunction = async (hre) => {
  const { deployer } = await hre.getNamedAccounts()

  const tellerV2 = await hre.contracts.get('TellerV2')
  const marketRegistry = await hre.contracts.get('MarketRegistry')
  const alpha = await hre.contracts.get('LenderCommitmentForwarderAlpha')

  const flag = (process.env.STAGED_CHECK_LENDER_ON_ACCEPT ?? 'true')
    .trim()
    .toLowerCase()
  if (flag !== 'true' && flag !== 'false') {
    throw new Error(
      `STAGED_CHECK_LENDER_ON_ACCEPT must be "true" or "false", got "${flag}"`
    )
  }
  const checkLenderOnAccept = flag === 'true'

  const args = [
    await tellerV2.getAddress(),
    await marketRegistry.getAddress(),
    await alpha.getAddress(),
    checkLenderOnAccept,
  ]
  hre.log(
    `LenderCommitmentForwarderStaged on ${getNetworkName(
      hre.network
    )}: args ${JSON.stringify(args)}`
  )

  await hre.deployments.deploy('LenderCommitmentForwarderStaged', {
    from: deployer,
    args,
    log: true,
  })

  return true
}

// tags and deployment
deployFn.id = 'lender-commitment-forwarder:staged:deploy'
deployFn.tags = [
  'lender-commitment-forwarder:staged',
  'lender-commitment-forwarder:staged:deploy',
]
deployFn.dependencies = [
  'teller-v2:deploy',
  'market-registry:deploy',
  'lender-commitment-forwarder:alpha:deploy',
]

// Only the offers-only Rome chains need the split accept.
deployFn.skip = async (hre) => !isOffersOnlyChain(hre.network)

export default deployFn
