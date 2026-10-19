import { DeployFunction } from 'hardhat-deploy/dist/types'

import { isOffersOnlyChain } from '../../config/chains/features'

const deployFn: DeployFunction = async (hre) => {
  const { deployer } = await hre.getNamedAccounts()
  const uniswapPricingLibrary = await hre.deployments.deploy('UniswapPricingLibrary', {
    from: deployer,
      skipIfAlreadyDeployed: true,

  })
}

// tags and deployment
deployFn.id = 'teller-v2:uniswap-pricing-library'
deployFn.tags = ['teller-v2', 'teller-v2:uniswap-pricing-library']
deployFn.dependencies = []

// Only the LenderCommitmentGroup (pools) contracts link UniswapPricingLibrary.
// The offers-only Rome chains have no pools, and every byte of code there
// costs Solana rent.
deployFn.skip = async (hre) => isOffersOnlyChain(hre.network)

export default deployFn