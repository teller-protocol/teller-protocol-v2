import { DeployFunction } from 'hardhat-deploy/dist/types'
import { deploy } from 'helpers/deploy-helpers'

/*

 yarn contracts deploy --network hyperevm --tags timelock-controller 


*/

const deployFn: DeployFunction = async (hre) => {


	  const { protocolOwnerSafe } = await hre.getNamedAccounts()

	  let protocolOwnerSafeAddress =   protocolOwnerSafe; 

	  let minDelay = 180;

	  let proposers = [ protocolOwnerSafeAddress ];
	  let executors = [  protocolOwnerSafeAddress  ];
	  let admin = protocolOwnerSafeAddress ; 


   hre.log('----------')
  hre.log('')
  hre.log('Deploying Timelock Controller ...')

  



  const timelock = await deploy({
    contract: 'TimelockController',
    args: [

    	minDelay,
    	proposers,
    	executors,
    	admin, 

    ] ,
    skipIfAlreadyDeployed: true,
    hre,
  })
  

   
  return true
}

// tags and deployment
deployFn.id = 'timelock-controller:deploy'
deployFn.tags = ['timelock-controller', 'timelock-controller:deploy']
deployFn.dependencies = []

deployFn.skip = async (hre) => {

  // return true;   //for now 
  return !(
    hre.network.live &&
    [ 'hyperevm', 'bsc', 'apechain', 'xdc' ].includes(
      hre.network.name
    )
  ) 


}

export default deployFn
