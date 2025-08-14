import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {

    hre.log('Deploying UniswapPricingHelper')


  const { deployer } = await hre.getNamedAccounts()
  const UniswapPricingHelper = await hre.deployments.deploy('UniswapPricingHelper', {
    from: deployer,
  })
}

// tags and deployment
deployFn.id = 'uniswap-pricing-helper:deploy'
deployFn.tags = ['teller-v2', 'uniswap-pricing-helper:deploy']
deployFn.dependencies = ['']
export default deployFn