import { getCurrentChainConfig } from '@nomicfoundation/hardhat-verify/dist/src/chain-config'
import { DeployFunction } from 'hardhat-deploy/dist/types'
import { HARDHAT_NETWORK_NAME } from 'hardhat/plugins'
import { TellerV2 } from 'types/typechain'

const deployFn: DeployFunction = async (hre) => {
  const protocolFee = await hre.contracts.get('ProtocolFee')
  const marketRegistry = await hre.contracts.get('MarketRegistry')
  const reputationManager = await hre.contracts.get('ReputationManager')
  const lenderCommitmentForwarder = await hre.contracts.get(
    'LenderCommitmentForwarder'
  )
  const collateralManager = await hre.contracts.get('CollateralManager')
  const lenderManager = await hre.contracts.get('LenderManager')

  hre.log('')
  hre.log('Initializing TellerV2 contract... ', { nl: false })

  const tellerV2 = await hre.contracts.get<TellerV2>('TellerV2')
  const tx = await tellerV2.initialize(
    protocolFee.address,
    marketRegistry.address,
    reputationManager.address,
    lenderCommitmentForwarder.address,
    collateralManager.address,
    lenderManager.address
  )

  let txLink = tx.hash
  if (hre.network.name !== HARDHAT_NETWORK_NAME) {
    const chainConfig = await getCurrentChainConfig(
      hre.network,
      hre.config.etherscan.customChains
    )
    txLink = `${chainConfig.urls.browserURL}/tx/${tx.hash}`
  }

  hre.log('done.')
  hre.log(`TellerV2 initialized at tx: ${txLink}`, { star: true, indent: 1 })

  return true
}

// tags and deployment
deployFn.tags = ['teller-v2', 'teller-v2:initialize']
deployFn.dependencies = [
  'teller-v2:deploy',
  'market-registry',
  'reputation-manager',
  'lender-commitment-forwarder',
  'collateral',
  'lender-manager',
]
export default deployFn
