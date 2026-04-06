import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {

    

  const { deployer } = await hre.getNamedAccounts()
  const UniswapPricingHelper = await hre.deployments.deploy('UniswapPricingHelper', {
    from: deployer,
  })

  hre.log('Deploying UniswapPricingHelper')


}

// tags and deployment
deployFn.id = 'uniswap-pricing-helper:deploy'
deployFn.tags = ['teller-v2', 'uniswap-pricing-helper:deploy']
deployFn.dependencies = ['']

deployFn.skip = async (hre) => {
    return !hre.network.live || !['polygon','bsc','apechain','xdc'].includes(hre.network.name)
  }

export default deployFn