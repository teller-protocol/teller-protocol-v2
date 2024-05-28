 
 import { log, Address, BigInt ,Timestamp , Bytes } from "@graphprotocol/graph-ts";
 import { Events } from "./pb/contract/v1/Events";

 import { Protobuf } from 'as-proto/assembly';


 


 import { 
  
  factory_deployed_lender_group_contract,

  //group_initialized,
  group_pool_metrics,
  group_lender_metrics,


  group_lender_added_principal,
  group_earnings_withdrawn,

  group_borrower_accepted_funds,
  group_loan_repaid,
  group_defaulted_loan_liquidated,
   


} from "../generated/schema";
 
export function handleSubstreamGraphOutTrigger(bytes: Uint8Array): void {
  
  const events: Events = Protobuf.decode<Events>(bytes, Events.decode);
  
  log.info("Decoded an event from substream trigger" , []  );
  
  //group pool deployed events 
  for (let i = 0; i < events.facDeployedLenderGroupContracts.length; i++) {
    let deployedLenderGroupContractEvent = events.facDeployedLenderGroupContracts[i];

    let entity_id = deployedLenderGroupContractEvent.evtTxHash
    .concat( "_" )
    .concat( deployedLenderGroupContractEvent.evtIndex.toString() );   
    let entity = new factory_deployed_lender_group_contract( entity_id );

    if (deployedLenderGroupContractEvent.evtBlockTime) {

      entity.evt_tx_hash = deployedLenderGroupContractEvent.evtTxHash;
      entity.evt_block_number = BigInt.fromU64( deployedLenderGroupContractEvent.evtBlockNumber );
      
      entity.evt_index =  BigInt.fromI32(deployedLenderGroupContractEvent.evtIndex);

  
      entity.group_contract = Address.fromString(deployedLenderGroupContractEvent.groupContract.toString());
      

      entity.save();

    }
   
  } 

  //group pool initialized events 
  for (let i = 0; i < events.grouppPoolInitializeds.length; i++) {

    let initializedLenderGroupPool = events.grouppPoolInitializeds[i];

    let group_pool_address = initializedLenderGroupPool.evtAddress  ;

    let entity_id = group_pool_address.toString() ;
 
    let entity = new group_pool_metrics( entity_id );
    entity.group_pool_address =  Address.fromString( initializedLenderGroupPool.evtAddress );
   
    //cast to bytes ? 
    entity.principal_token_address = initializedLenderGroupPool.principalTokenAddress.toString();
    entity.collateral_token_address = initializedLenderGroupPool.collateralTokenAddress.toString();


    ///fill in all the stuff we need 

    entity.save();


  }


  for (let i = 0; i < events.grouppLenderAddedPrincipals.length; i++) {

    let lenderAddPrincipal = events.grouppLenderAddedPrincipals[i];



  }


  for (let i = 0; i < events.grouppEarningsWithdrawns.length; i++) {

    let lenderWithdrawEarnings = events.grouppEarningsWithdrawns[i];



  }


  for (let i = 0; i < events.grouppBorrowerAcceptedFunds.length; i++) {

    let borrowerAcceptedFunds = events.grouppBorrowerAcceptedFunds[i];



  }


  for (let i = 0; i < events.grouppLoanRepaids.length; i++) {

    let borrowerRepaidLoan = events.grouppLoanRepaids[i];




  }


  for (let i = 0; i < events.grouppDefaultedLoanLiquidateds.length; i++) {

    let defaultedLoanLiquidation = events.grouppDefaultedLoanLiquidateds[i];




  }
 
}
