import { DeployFunction } from 'hardhat-deploy/dist/types'
import { deploy } from 'helpers/deploy-helpers'
import { get_ecosystem_contract_address } from "../../helpers/ecosystem-contracts-lookup" 



const deployFn: DeployFunction = async (hre) => {

  
    const deployer = await hre.getNamedSigner('deployer')
    const deployerAddress = await deployer.getAddress()



    let uniswapV3FactoryAddress =  get_ecosystem_contract_address( hre.network.name, "uniswapV3Factory" ) ;
   


  const quoter = await  deploy({
    contract: 'Quoter',
    args: [ uniswapV3FactoryAddress ] ,
    skipIfAlreadyDeployed: true,
    hre,
  })

  return true
}

// tags and deployment
deployFn.id = 'uniswapv3-quoter:deploy'
deployFn.tags = ['uniswapv3-quoter:deploy']
deployFn.dependencies = []
deployFn.skip = async (hre) => {
    return !hre.network.live || ![  'polygon', 'katana', 'hyperevm' ].includes(hre.network.name)
  }
export default deployFn
