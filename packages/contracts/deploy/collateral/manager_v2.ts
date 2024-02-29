import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  const tellerV2 = await hre.contracts.get('TellerV2')

  const collateralManagerV2 = await hre.deployProxy('CollateralManagerV2', {
    initArgs: [await tellerV2.getAddress()] //for initializer
  })

  return true
}

// tags and deployment
deployFn.id = 'collateral:manager-v2:deploy'
deployFn.tags = [
  'collateral',
  'collateral:manager-v2',
  'collateral:manager-v2:deploy'
]
deployFn.dependencies = ['teller-v2:deploy']
deployFn.skip = async (hre) => {
  return !hre.network.live || !['sepolia'].includes(hre.network.name)
}

export default deployFn
