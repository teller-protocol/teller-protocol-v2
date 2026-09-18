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
  // happened to get first.
  //
  // That alone does not get a chain off a bad quoter, though. `deploy` only
  // redeploys when hardhat-deploy reports the deployment as different, and it
  // works that out from the bytecode or the deploy transaction recorded in
  // deployments/<network>/Quoter.json. The artifacts this repo saves carry
  // neither - address, abi, args and numDeployments, nothing else - so there
  // is nothing to compare, every build looks identical to the last, and the
  // existing address is reused however much the source changed. That is why
  // the first attempt at replacing the pre-fix quoter logged
  // "reusing 0x8B7b8490..." and deployed nothing.
  //
  // REDEPLOY_QUOTER drops the record so the next deploy is a fresh one. It is
  // opt-in rather than automatic because the alternative - treating "cannot
  // prove it is the same" as "redeploy" - would hand every chain a new quoter
  // on every run, and rebind BorrowSwap to it each time.
  //
  // Anything pointing at the old address keeps pointing at it until it is
  // rebound; on this protocol that is BorrowSwap's immutable, which
  // 42_rebind_borrow_swap_quoter handles.
  if (process.env.REDEPLOY_QUOTER === 'true') {
    const existing = await hre.deployments.getOrNull('Quoter')
    if (existing) {
      hre.log(
        `REDEPLOY_QUOTER: discarding the Quoter record at ${existing.address} so this build deploys a new one`
      )
      await hre.deployments.delete('Quoter')
    }
  }

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
