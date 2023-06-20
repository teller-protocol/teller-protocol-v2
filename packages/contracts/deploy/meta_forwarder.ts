import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  const trustedForwarder = await hre.deployProxy('MetaForwarder', {
    redeployImplementation: 'never',
  })

  return true
}

// tags and deployment
deployFn.tags = ['meta-forwarder']
deployFn.dependencies = []
export default deployFn
