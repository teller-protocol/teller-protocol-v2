import { getNamedAccounts } from 'hardhat'
import { DeployFunction } from 'hardhat-deploy/dist/types'
import { deploy } from 'helpers/deploy-helpers'

const deployFn: DeployFunction = async (hre) => {




  let {deployer} = await getNamedAccounts()

  console.log('deployer',deployer)

  const trustedForwarder = await deploy({
    contract: 'MetaForwarder',
    skipIfAlreadyDeployed: true,
    proxy: {
      proxyContract: 'OpenZeppelinTransparentProxy',
      execute: {
        init: {
          methodName: 'initialize',
          args: [],
        },
      },
    },
    hre,
  })
}

// tags and deployment
deployFn.tags = ['meta-forwarder']
deployFn.dependencies = []
export default deployFn
