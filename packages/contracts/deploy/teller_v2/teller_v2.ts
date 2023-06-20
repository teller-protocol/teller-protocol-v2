import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  const protocolFee = await hre.contracts.get('ProtocolFee')
  const marketRegistry = await hre.contracts.get('MarketRegistry')
  const reputationManager = await hre.contracts.get('ReputationManager')
  const lenderCommitmentForwarder = await hre.contracts.get(
    'LenderCommitmentForwarder'
  )
  const collateralManager = await hre.contracts.get('CollateralManager')
  const lenderManager = await hre.contracts.get('LenderManager')
  const trustedForwarder = await hre.contracts.get('MetaForwarder')

  const tellerV2 = await hre.deployProxy('TellerV2', {
    constructorArgs: [trustedForwarder.address],
    initArgs: [
      protocolFee.address,
      marketRegistry.address,
      reputationManager.address,
      lenderCommitmentForwarder.address,
      collateralManager.address,
      lenderManager.address,
    ],
    redeployImplementation: 'never',
  })

  return true
}

// tags and deployment
deployFn.tags = ['teller-v2']
deployFn.dependencies = [
  'protocol-fee',
  'market-registry',
  'reputation-manager',
  'lender-commitment-forwarder',
  'collateral',
  'lender-manager',
  'meta-forwarder',
]
export default deployFn
