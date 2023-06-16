import { DeployFunction } from 'hardhat-deploy/dist/types'
import { deploy } from 'helpers/deploy-helpers'

const deployFn: DeployFunction = async (hre) => {
  await deploy({
    contract: 'EscrowVault',
    args: [],
    proxy: {
      proxyContract: 'OpenZeppelinTransparentProxy',
      execute: {
        init: {
          args: [],
          methodName: 'initialize'
        }
      }
    },
    skipIfAlreadyDeployed: true,
    hre
  })
}

// tags and deployment
deployFn.tags = ['escrow-vault']
export default deployFn
