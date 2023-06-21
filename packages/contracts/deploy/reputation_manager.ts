import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  const tellerV2 = await hre.contracts.get('TellerV2')

  const reputationManager = await hre.deployProxy('ReputationManager', {
    redeployImplementation: 'never',
    initArgs: [tellerV2.address],
  })

  return true
}

// tags and deployment
deployFn.tags = ['reputation-manager']
deployFn.dependencies = ['teller-v2:deploy']
export default deployFn
