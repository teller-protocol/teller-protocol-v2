import { DeployFunction } from 'hardhat-deploy/dist/types'

import { logTxLink } from 'helpers/logTxLink'


const deployFn: DeployFunction = async (hre) => {
  hre.log('----------')
  hre.log('')
  hre.log('  --- RUNNING DEPLOYMENT VALIDATIONS ---  ')




  const tellerV2 = await hre.contracts.get('TellerV2')
 
  const marketRegistry = await hre.contracts.get('MarketRegistry')

  	

  
  const pausingManager = await hre.contracts.get(
    'ProtocolPausingManager'
  )
  
  const lenderGroupsFactory = await hre.contracts.get(
    'LenderCommitmentGroupFactory_V2'
  )


  const lenderGroupsBeacon = await hre.contracts.get(
    'LenderCommitmentGroupBeaconV2'
  )

  const smartCommitmentForwarder = await hre.contracts.get(
    'SmartCommitmentForwarder'
  )
 


  //make sure the SCF has been initialized  and has an owner 

  //make sure tellerV2 has been re-initialized  and has a pausing manager 

  //make sure lender groups factory has been initialized and has an owner 

  const zeroAddress = "0x0000000000000000000000000000000000000000";

 




  const scfOwner = await smartCommitmentForwarder.owner()

  
  hre.log( " ------- "  )
  hre.log( "SCF owner: "  )
  hre.log(  scfOwner  )
  hre.log( " ------- "  )
 
  if (scfOwner == zeroAddress) {
  	throw "Validation Error : SCF owner not defined " 
  }





  const lenderGroupsFactoryOwner = await lenderGroupsFactory.owner()



  hre.log( " ------- "  )
  hre.log( "lenderGroupsFactoryOwner: "  )
  hre.log(  lenderGroupsFactoryOwner  )
  hre.log( " ------- "  )
 
  if (lenderGroupsFactoryOwner == zeroAddress) {
  	throw "Validation Error : lenderGroupsFactoryOwner not defined " 
  }

 

  const lenderGroupsBeaconOwner = await lenderGroupsBeacon.owner()

 
  hre.log( " ------- "  )
  hre.log( "lenderGroupsBeaconOwner: "  )
  hre.log(  lenderGroupsBeaconOwner  )
  hre.log( " ------- "  )
 
  if (lenderGroupsBeaconOwner == zeroAddress) {
  	throw "Validation Error : lenderGroupsBeaconOwner not defined " 
  }


 


  const tellerV2Owner = await tellerV2.owner()



  hre.log( " ------- "  )
  hre.log( "tellerV2Owner: "  )
  hre.log(  tellerV2Owner  )
  hre.log( " ------- "  )
 
  if (tellerV2Owner == zeroAddress) { 
  		throw new Error("Validation Error : Teller Owner not defined ")
  }






  const tellerV2EscrowVault = await tellerV2.getEscrowVault()



  hre.log( " ------- "  )
  hre.log( "tellerV2EscrowVault: "  )
  hre.log(  tellerV2EscrowVault  )
  hre.log( " ------- "  )
 
  if (tellerV2EscrowVault == zeroAddress) { 
      throw new Error("Validation Error : tellerV2EscrowVault not defined ")
  }

 





  const pausingManagerOwner = await pausingManager.owner()



  hre.log( " ------- "  )
  hre.log( "pausingManagerOwner: "  )
  hre.log(  pausingManagerOwner  )
  hre.log( " ------- "  )
 
  if (pausingManagerOwner == zeroAddress) {
  	 console.error('Validation Error :  Pausing Manager Owner not defined  ');
  	  	throw new Error("Validation Error :  Pausing Manager Owner not defined ")
  }

 


try {
  const tellerV2PausingManager = await tellerV2.getProtocolPausingManager()




  hre.log( " ------- "  )
  hre.log( "tellerV2PausingManager: "  )
  hre.log(  tellerV2PausingManager  )
  hre.log( " ------- "  )
 


  if (tellerV2PausingManager == zeroAddress) {
    console.error(' Validation Error : Teller Protocol Pausing Manager not defined ');
    throw new Error("Validation Error : Teller Protocol Pausing Manager not defined ") 
  }





  
 } catch (error) {
  console.error('Error calling getProtocolPausingManager:', error);
  throw new Error('Validation Error: Unable to fetch Protocol Pausing Manager');
}




  hre.log(' ---  DEPLOYMENT VALIDATIONS FINISHED ---  ')
 

  return true
}

// tags and deployment
deployFn.id = 'validate-deployments'
deployFn.tags = ['proposal', 'upgrade', 'validate-deployments']
deployFn.dependencies = ['lender-groups:upgrade']
deployFn.skip = async (hre) => {
   return false 
  //return !hre.network.live || !['sepolia','polygon','base','arbitrum','mainnet' ].includes(hre.network.name)
}
export default deployFn

