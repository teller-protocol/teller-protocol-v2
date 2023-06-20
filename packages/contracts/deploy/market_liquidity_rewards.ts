import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  const tellerV2 = await hre.contracts.get('TellerV2')
  const marketRegistry = await hre.contracts.get('MarketRegistry')
  const collateralManager = await hre.contracts.get('CollateralManager')

  const marketLiquidityRewards = await hre.deployProxy(
    'MarketLiquidityRewards',
    {
      constructorArgs: [
        tellerV2.address,
        marketRegistry.address,
        collateralManager.address,
      ],
      redeployImplementation: 'never',
    }
  )

  return true
}

// tags and deployment
deployFn.tags = ['liquidity-rewards']
deployFn.dependencies = ['teller-v2', 'market-registry', 'collateral']
export default deployFn
