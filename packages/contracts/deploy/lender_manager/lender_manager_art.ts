import { DeployFunction } from 'hardhat-deploy/dist/types'
import { deploy } from 'helpers/deploy-helpers'

const deployFn: DeployFunction = async (hre) => {
  const lenderManagerArt = await deploy({
    contract: 'LenderManagerArt',
    hre,
  })
}

// tags and deployment
deployFn.id = 'lender-manager:lender-manager-art'
deployFn.tags = ['lender-manager', 'lender-manager:lender-manager-art']
deployFn.dependencies = ['']
export default deployFn
