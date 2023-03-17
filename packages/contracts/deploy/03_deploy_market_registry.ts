import { DeployFunction } from 'hardhat-deploy/dist/types'
import { deploy } from 'helpers/deploy-helpers'
import { MarketRegistry } from 'types/typechain'

const deployFn: DeployFunction = async (hre) => {
  // TellerASRegistry
  const tellerAS = await hre.contracts.get('TellerAS')

  await deploy({
    contract: 'MarketRegistry',
    args: [],
    proxy: {
      proxyContract: 'OpenZeppelinTransparentProxy',
      execute: {
        init: {
          args: [tellerAS.address],
          methodName: 'initialize',
        },
      },
    },
    skipIfAlreadyDeployed: true,
    hre,
  })
}

// tags and deployment
deployFn.tags = ['market-registry']
deployFn.dependencies = ['teller-as']
export default deployFn
