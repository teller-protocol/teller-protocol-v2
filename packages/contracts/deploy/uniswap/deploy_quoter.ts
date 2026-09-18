import { DeployFunction } from 'hardhat-deploy/dist/types'
import { deploy } from 'helpers/deploy-helpers'
import { get_ecosystem_contract_address } from "../../helpers/ecosystem-contracts-lookup" 
import { skipUnlessChainSupports } from '../../config/chains/features'



const deployFn: DeployFunction = async (hre) => {

  
    const deployer = await hre.getNamedSigner('deployer')
    const deployerAddress = await deployer.getAddress()



    let uniswapV3FactoryAddress =  get_ecosystem_contract_address( hre.network.name, "uniswapV3Factory" ) ;
   


  // Not skipIfAlreadyDeployed. The quoter is a stateless view contract - it
  // holds no funds, no positions and no storage anyone else points at - so
  // there is nothing to preserve by pinning a chain to the bytecode it
  // happened to get first. Skipping did preserve exactly that: the quoter
  // deployed before FullMath's 512-bit path was fixed reverted on any pool
  // priced high enough to need it, and no redeploy could replace it.
  //
  // hardhat-deploy still no-ops when the bytecode and args are unchanged, so
  // this redeploys on a real change and stays quiet otherwise.
  const quoter = await  deploy({
    contract: 'Quoter',
    args: [ uniswapV3FactoryAddress ] ,
    hre,
  })

  return true
}

// tags and deployment
deployFn.id = 'uniswapv3-quoter:deploy'
deployFn.tags = ['uniswapv3-quoter:deploy']
deployFn.dependencies = []
deployFn.skip = skipUnlessChainSupports('uniswapV3Quoter')
export default deployFn
