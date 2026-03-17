import { DeployFunction } from 'hardhat-deploy/dist/types'
import { deploy } from 'helpers/deploy-helpers'


const deployFn: DeployFunction = async (hre) => {

  
    const deployer = await hre.getNamedSigner('deployer')
    const deployerAddress = await deployer.getAddress()


  const hypernativeOracle = await  deploy({
    contract: 'HypernativeOracle',
    args: [ deployerAddress ] ,
    skipIfAlreadyDeployed: true,
    hre,
  })

  return true
}

// tags and deployment
deployFn.id = 'hypernative-oracle-mock:deploy'
deployFn.tags = ['hypernative-oracle-mock:deploy']
deployFn.dependencies = []
deployFn.skip = async (hre) => {
    return !hre.network.live || !['polygon', 'arbitrum','base','mainnet','bsc','apechain','xdc'].includes(hre.network.name)
  }
export default deployFn
