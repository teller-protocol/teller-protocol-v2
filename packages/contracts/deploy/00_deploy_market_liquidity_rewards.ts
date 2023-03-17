import { DeployFunction } from 'hardhat-deploy/dist/types'
import { deploy } from 'helpers/deploy-helpers'

const deployFn: DeployFunction = async (hre) => {
  const tellerV2 = await hre.contracts.get('TellerV2')
  const marketRegistry = await hre.contracts.get('MarketRegistry')
  const collateralManager = await hre.contracts.get('CollateralManager')

  await deploy({
    contract: 'MarketLiquidityRewards',
    args: [tellerV2.address, marketRegistry.address, collateralManager.address],
    proxy: {
      proxyContract: 'OpenZeppelinTransparentProxy',
      execute: {
        init: {
          args: [],
          methodName: 'initialize',
        },
      },
    },
    skipIfAlreadyDeployed: true,
    hre,
  })
}

// tags and deployment
deployFn.tags = ['liquidity-rewards']
deployFn.dependencies = ['teller-v2', 'market-registry', 'collateral-manager']
export default deployFn
