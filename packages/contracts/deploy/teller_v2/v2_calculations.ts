import { DeployFunction } from 'hardhat-deploy/dist/types'
import { deploy } from 'helpers/deploy-helpers'

const deployFn: DeployFunction = async (hre) => {
  const v2Calculations = await deploy({
    contract: 'V2Calculations',
    hre,
  })
}

// tags and deployment
deployFn.id = 'teller-v2:v2-calculations'
deployFn.tags = ['teller-v2', 'teller-v2:v2-calculations']
deployFn.dependencies = ['']
export default deployFn
