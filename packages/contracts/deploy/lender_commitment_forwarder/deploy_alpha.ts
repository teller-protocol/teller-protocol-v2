import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  const tellerV2 = await hre.contracts.get('TellerV2')
  const marketRegistry = await hre.contracts.get('MarketRegistry')

  const lenderCommitmentForwarderAlpha = await hre.deployProxy(
    'LenderCommitmentForwarderAlpha',
    {
      unsafeAllow: ['constructor', 'state-variable-immutable'],
      constructorArgs: [
        await tellerV2.getAddress(),
        await marketRegistry.getAddress()
      ]
    }
  )

  return true
}

// tags and deployment
deployFn.id = 'lender-commitment-forwarder:alpha:deploy'
deployFn.tags = [
  'lender-commitment-forwarder',
  'lender-commitment-forwarder:alpha',
  'lender-commitment-forwarder:alpha:deploy'
]
deployFn.dependencies = ['teller-v2:deploy', 'market-registry:deploy']
export default deployFn
