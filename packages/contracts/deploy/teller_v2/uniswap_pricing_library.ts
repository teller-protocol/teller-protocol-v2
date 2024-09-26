import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  const { deployer } = await hre.getNamedAccounts()
  const uniswapPricingLibrary = await hre.deployments.deploy('UniswapPricingLibrary', {
    from: deployer,
  })
}

// tags and deployment
deployFn.id = 'teller-v2:uniswap-pricing-library'
deployFn.tags = ['teller-v2', 'teller-v2:uniswap-pricing-library']
deployFn.dependencies = ['']
export default deployFn