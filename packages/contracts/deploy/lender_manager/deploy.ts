import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  const marketRegistry = await hre.contracts.get('MarketRegistry')

  const lenderManagerArt = await hre.contracts.get('LenderManagerArt')

  const lenderManager = await hre.deployProxy('LenderManager', {
    constructorArgs: [await marketRegistry.getAddress()],
    unsafeAllow: ['constructor', 'state-variable-immutable'],
    libraries: {
      LenderManagerArt: lenderManagerArt.address,
    },
  })

  return true
}

// tags and deployment
deployFn.id = 'lender-manager:deploy'
deployFn.tags = ['lender-manager', 'lender-manager:deploy']
deployFn.dependencies = [
  'market-registry:deploy',
  'lender-manager:lender-manager-art',
]
export default deployFn
