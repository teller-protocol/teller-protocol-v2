import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  const marketRegistry = await hre.contracts.get('MarketRegistry')

  const lenderManager = await hre.deployProxy('LenderManager', {
    constructorArgs: [marketRegistry.address],
    unsafeAllow: ['constructor', 'state-variable-immutable'],
    redeployImplementation: 'never',
  })

  return true
}

// tags and deployment
deployFn.tags = ['lender-manager']
deployFn.dependencies = ['market-registry']
export default deployFn
