import { DeployFunction } from 'hardhat-deploy/dist/types'
import { deploy } from 'helpers/deploy-helpers'


const deployFn: DeployFunction = async (hre) => {
  

  const tokenContractOne = await deploy({
    contract: 'WethMock',
    args: [],
    skipIfAlreadyDeployed: true,
    hre,
  })

  hre.log(`deploying tokenContractOne ${tokenContractOne}`)

  const tokenContractTwo = await deploy({
    contract: 'WethMock',
    args: [],
    skipIfAlreadyDeployed: true,
    hre,
  })
  hre.log(`deploying tokenContractTwo ${tokenContractOne}`)

  return true
}

// tags and deployment
deployFn.id = 'deploy-mock-tokens'
deployFn.tags = [
  'mock-tokens',
  'deploy-mock-tokens'
 
]
deployFn.dependencies = []
deployFn.skip = async (hre) => {
 
    return (
      !hre.network.live ||
      ![
        'clarity',
        
        
      ].includes(hre.network.name)
    )
  }
export default deployFn
