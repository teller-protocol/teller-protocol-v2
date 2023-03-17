import { DeployFunction } from 'hardhat-deploy/dist/types'
import { deploy } from 'helpers/deploy-helpers'
import { LenderManager } from 'types/typechain'

const deployFn: DeployFunction = async (hre) => {
  const { implName, init } = {
    implName: 'LenderManager',
    init: {
      methodName: 'initialize',
      args: [],
    },
  }

  const marketRegistry = await hre.contracts.get('MarketRegistry')
  const lenderManager = await deploy<LenderManager>({
    name: 'LenderManager',
    contract: implName,
    args: [marketRegistry.address],
    proxy: {
      proxyContract: 'OpenZeppelinTransparentProxy',
      execute: {
        init,
      },
    },
    skipIfAlreadyDeployed: true,
    hre,
  })
}

// tags and deployment
deployFn.tags = ['lender-manager']
deployFn.dependencies = ['market-registry']
export default deployFn
