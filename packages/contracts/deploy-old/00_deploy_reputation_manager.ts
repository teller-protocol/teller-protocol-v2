import { DeployFunction } from 'hardhat-deploy/dist/types'
import { deploy } from 'helpers/deploy-helpers'

const deployFn: DeployFunction = async (hre) => {
  const reputationManager = await deploy({
    contract: 'ReputationManager',
    args: [],
    proxy: {
      proxyContract: 'OpenZeppelinTransparentProxy',
    },
    hre,
  })
}

// tags and deployment
deployFn.tags = ['reputation-manager']
deployFn.dependencies = []
export default deployFn
