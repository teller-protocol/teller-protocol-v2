import { skipUnlessChainSupports } from '../../config/chains/features'
import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  const { deployer } = await hre.getNamedAccounts()
  const uniswapPricingLibraryV2 = await hre.deployments.deploy('UniswapPricingLibraryV2', {
    from: deployer,
        skipIfAlreadyDeployed: true,
  })
}

// tags and deployment
deployFn.id = 'teller-v2:uniswap-pricing-library-v2'
deployFn.tags = ['teller-v2', 'teller-v2:uniswap-pricing-library-v2']
deployFn.dependencies = ['']


deployFn.skip = skipUnlessChainSupports('uniswapPricingLibraryV2')
export default deployFn