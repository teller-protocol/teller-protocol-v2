 
 import { log, Address, BigInt ,Timestamp , Bytes, ByteArray } from "@graphprotocol/graph-ts";
 import { Events } from "./pb/contract/v1/Events";

 import { Protobuf } from 'as-proto/assembly';


 


 import { 
  
  factory_deployed_lender_group_contract,

  //group_initialized,
  group_pool_metrics,
  group_lender_metrics,

  group_pool_metrics_data_point, 


  group_lender_added_principal,
  group_earnings_withdrawn,

  group_borrower_accepted_funds,
  group_loan_repaid,
  group_defaulted_loan_liquidated,
   


} from "../generated/schema";
 
  
function stringToBytes(str: string): Bytes {
  let utf8Array = ByteArray.fromUTF8(str);
  return Bytes.fromByteArray(utf8Array);
}

export function handleSubstreamGraphOutTrigger(bytes: Uint8Array): void {
  
  const events: Events = Protobuf.decode<Events>(bytes, Events.decode);
  
  log.info("Decoded an event from substream trigger" , []  );
  
  //group pool deployed events 
  for (let i = 0; i < events.factoryDeployedLenderGroupContracts.length; i++) {
    let deployedLenderGroupContractEvent = events.factoryDeployedLenderGroupContracts[i];

    let entity_id = deployedLenderGroupContractEvent.evtTxHash
    .concat( "_" )
    .concat( deployedLenderGroupContractEvent.evtIndex.toString() );   
    let entity = new factory_deployed_lender_group_contract( entity_id );

    if (deployedLenderGroupContractEvent.evtBlockTime) {

      entity.evt_tx_hash = stringToBytes( deployedLenderGroupContractEvent.evtTxHash );
      entity.evt_block_number = BigInt.fromU64( deployedLenderGroupContractEvent.evtBlockNumber );
      
      entity.evt_index =  BigInt.fromU64(deployedLenderGroupContractEvent.evtIndex);

  
      entity.group_contract = Bytes.fromUint8Array(deployedLenderGroupContractEvent.groupContract );
      

      entity.save();

    }
   
  } 

  //group pool initialized events 
  for (let i = 0; i < events.lendergroupPoolInitializeds.length; i++) {

    let initializedLenderGroupPool = events.lendergroupPoolInitializeds[i];

    let group_pool_address = initializedLenderGroupPool.evtAddress  ;

    let entity_id = group_pool_address.toString() ;
 
    let entity = new group_pool_metrics( entity_id );
    entity.group_pool_address =  Address.fromString( initializedLenderGroupPool.evtAddress );
   
    
    entity.principal_token_address = Bytes.fromUint8Array( initializedLenderGroupPool.principalTokenAddress  );
    entity.collateral_token_address =  Bytes.fromUint8Array( initializedLenderGroupPool.collateralTokenAddress  );
    entity.shares_token_address =  Bytes.fromUint8Array (initializedLenderGroupPool.poolSharesToken );

    entity.uniswap_v3_pool_address = Bytes.fromUint8Array( initializedLenderGroupPool.uniswapV3PoolAddress );
    entity.teller_v2_address = Bytes.fromUint8Array( initializedLenderGroupPool.tellerV2Address  );
    entity.smart_commitment_forwarder_address = Bytes.fromUint8Array( initializedLenderGroupPool.smartCommitmentForwarderAddress  );


    entity.market_id = BigInt.fromString( initializedLenderGroupPool.marketId ) ;
    entity.uniswap_pool_fee = i32( initializedLenderGroupPool.uniswapPoolFee );
    
    entity.max_loan_duration = i32(initializedLenderGroupPool.maxLoanDuration ); 
    entity.twap_interval = i32(initializedLenderGroupPool.twapInterval);
    entity.interest_rate_lower_bound = i32(initializedLenderGroupPool.interestRateLowerBound);
    entity.interest_rate_upper_bound = i32(initializedLenderGroupPool.interestRateUpperBound);

    entity.liquidity_threshold_percent = i32(initializedLenderGroupPool.liquidityThresholdPercent);
    entity.collateral_ratio = i32(initializedLenderGroupPool.loanToValuePercent);

    entity.total_principal_tokens_committed = BigInt.zero() ;
    entity.total_principal_tokens_withdrawn = BigInt.zero() ;

    entity.total_principal_tokens_lended = BigInt.zero() ;
    entity.total_principal_tokens_repaid = BigInt.zero() ;
    entity.total_interest_collected = BigInt.zero() ;

    entity.token_difference_from_liquidations = BigInt.zero() ;
 

    entity.save();



    let block_number = BigInt.fromU64( initializedLenderGroupPool.evtBlockNumber );
    let block_time =  BigInt.fromU64( initializedLenderGroupPool.evtBlockTime );

    create_pool_metrics_data_point(  entity.group_pool_address.toString() , block_number , block_time);


  }


  for (let i = 0; i < events.lendergroupLenderAddedPrincipals.length; i++) {

    let lenderAddPrincipal = events.lendergroupLenderAddedPrincipals[i];

    let group_pool_address = lenderAddPrincipal.evtAddress ;

    // load the group pool metrics by id and modify it 

    let addedPrincipalAmount = BigInt.fromString(lenderAddPrincipal.amount);

    let group_pool_metrics_entity = group_pool_metrics.load(group_pool_address)!;
 
    group_pool_metrics_entity.total_principal_tokens_committed = group_pool_metrics_entity.total_principal_tokens_committed.plus(addedPrincipalAmount) ;


    group_pool_metrics_entity.save();




    let block_number = BigInt.fromU64( lenderAddPrincipal.evtBlockNumber );
    let block_time = BigInt.fromU64( lenderAddPrincipal.evtBlockTime );

    create_pool_metrics_data_point(   group_pool_address, block_number , block_time);



  }


  for (let i = 0; i < events.lendergroupEarningsWithdrawns.length; i++) {

    let lenderWithdrawEarnings = events.lendergroupEarningsWithdrawns[i];

    let group_pool_address = lenderWithdrawEarnings.evtAddress ;

    let group_pool_metrics_entity = group_pool_metrics.load(group_pool_address)!;
 
    

    group_pool_metrics_entity.save();


    let block_number = BigInt.fromU64( lenderWithdrawEarnings.evtBlockNumber );
    let block_time =  BigInt.fromU64( lenderWithdrawEarnings.evtBlockTime );

    create_pool_metrics_data_point(   group_pool_address, block_number , block_time);


  }


  for (let i = 0; i < events.lendergroupBorrowerAcceptedFunds.length; i++) {

    let borrowerAcceptedFunds = events.lendergroupBorrowerAcceptedFunds[i];

    let group_pool_address = borrowerAcceptedFunds.evtAddress ;


    let borrowAmount = BigInt.fromString(borrowerAcceptedFunds.principalAmount);


    let group_pool_metrics_entity = group_pool_metrics.load(group_pool_address)!;
 
    
    group_pool_metrics_entity.total_principal_tokens_withdrawn = group_pool_metrics_entity.total_principal_tokens_withdrawn.plus(borrowAmount) ;
  



    group_pool_metrics_entity.save();


    let block_number = BigInt.fromU64( borrowerAcceptedFunds.evtBlockNumber );
    let block_time = BigInt.fromU64( borrowerAcceptedFunds.evtBlockTime );

    create_pool_metrics_data_point(   group_pool_address, block_number , block_time);



  }


  for (let i = 0; i < events.lendergroupLoanRepaids.length; i++) {

    let borrowerRepaidLoan = events.lendergroupLoanRepaids[i];

    let group_pool_address = borrowerRepaidLoan.evtAddress ;

    let repaidAmountPrincipal = BigInt.fromString(borrowerRepaidLoan.principalAmount);
    let repaidAmountInterest = BigInt.fromString(borrowerRepaidLoan.interestAmount);


    let group_pool_metrics_entity = group_pool_metrics.load(group_pool_address)!;
 
    group_pool_metrics_entity.total_principal_tokens_repaid = group_pool_metrics_entity.total_principal_tokens_repaid.plus(repaidAmountPrincipal) ;
    group_pool_metrics_entity.total_interest_collected = group_pool_metrics_entity.total_interest_collected.plus(repaidAmountInterest) ;


    group_pool_metrics_entity.save();


  }


  for (let i = 0; i < events.lendergroupDefaultedLoanLiquidateds.length; i++) {

    let defaultedLoanLiquidation = events.lendergroupDefaultedLoanLiquidateds[i];

    let group_pool_address = defaultedLoanLiquidation.evtAddress ;


    //big int can be negative - yes. So this should be OK
    let differenceAmountPrincipal = BigInt.fromString(defaultedLoanLiquidation.tokenAmountDifference);



    let group_pool_metrics_entity = group_pool_metrics.load(group_pool_address)!;
 
    group_pool_metrics_entity.token_difference_from_liquidations = group_pool_metrics_entity.token_difference_from_liquidations.plus(differenceAmountPrincipal) ;



    group_pool_metrics_entity.save();

  }
 
}



function create_pool_metrics_data_point(

  group_pool_address: string,
  block_number: BigInt,
  block_time: BigInt 

) : void {


  let entity_id = group_pool_address.toString() .concat( "_"  ).concat(block_number.toString()) ;
  
  let group_entity = group_pool_metrics.load(  group_pool_address   )!  ;

  let data_point_entity = new group_pool_metrics_data_point( entity_id );


  data_point_entity.group_pool_address = Address.fromString( group_pool_address ) ;
  data_point_entity.block_number = block_number;

   
  data_point_entity.block_time = block_time ;
   
 

  data_point_entity.total_principal_tokens_committed = group_entity.total_principal_tokens_committed;
  data_point_entity.total_principal_tokens_withdrawn = group_entity.total_principal_tokens_withdrawn;
  data_point_entity.total_principal_tokens_lended = group_entity.total_principal_tokens_lended;
  data_point_entity.total_principal_tokens_repaid = group_entity.total_principal_tokens_repaid;
  data_point_entity.total_interest_collected = group_entity.total_interest_collected;



  data_point_entity.save() ;


}