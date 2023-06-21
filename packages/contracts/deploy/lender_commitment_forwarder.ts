import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  const tellerV2 = await hre.contracts.get('TellerV2')
  const marketRegistry = await hre.contracts.get('MarketRegistry')

  const lenderCommitmentForwarder = await hre.deployProxy(
    'LenderCommitmentForwarder',
    {
      constructorArgs: [tellerV2.address, marketRegistry.address],
      redeployImplementation: 'never',
    }
  )

  return true
}

// tags and deployment
deployFn.tags = ['lender-commitment-forwarder']
deployFn.dependencies = ['teller-v2:deploy', 'market-registry']
export default deployFn
