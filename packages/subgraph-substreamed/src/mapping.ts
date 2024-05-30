 
 import { log, Address, BigInt ,Timestamp , Bytes, ByteArray } from "@graphprotocol/graph-ts";
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

  
      entity.group_contract = Address.fromString(deployedLenderGroupContractEvent.groupContract.toString());
      

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
   
    //cast to bytes ? 
    entity.principal_token_address = Address.fromString( initializedLenderGroupPool.principalTokenAddress.toString() );
    entity.collateral_token_address =  Address.fromString( initializedLenderGroupPool.collateralTokenAddress.toString() );
    entity.shares_token_address =  Address.fromString (initializedLenderGroupPool.poolSharesToken.toString() );

    entity.uniswap_v3_pool_address = Address.fromString( initializedLenderGroupPool.uniswapV3PoolAddress.toString() );
    entity.teller_v2_address = Address.fromString( initializedLenderGroupPool.tellerV2Address.toString()  );
    entity.smart_commitment_forwarder_address = Address.fromString( initializedLenderGroupPool.smartCommitmentForwarderAddress.toString()  );


    entity.market_id = BigInt.fromString( initializedLenderGroupPool.marketId ) ;
    entity.uniswap_pool_fee = i32( initializedLenderGroupPool.uniswapPoolFee );
    
    entity.max_loan_duration = i32(initializedLenderGroupPool.maxLoanDuration ); 
    entity.twap_interval = i32(initializedLenderGroupPool.twapInterval);
    entity.interest_rate_lower_bound = i32(initializedLenderGroupPool.interestRateLowerBound);
    entity.interest_rate_upper_bound = i32(initializedLenderGroupPool.interestRateUpperBound);

    entity.liquidity_threshold_percent = i32(initializedLenderGroupPool.liquidityThresholdPercent);
    entity.collateral_ratio = i32(initializedLenderGroupPool.loanToValuePercent);

    entity.total_principal_tokens_committed = 0;
    entity.total_principal_tokens_withdrawn = 0;

    entity.total_principal_tokens_lended = 0;
    entity.total_principal_tokens_repaid = 0;
    entity.total_interest_collected = 0;

    entity.token_difference_from_liquidations = 0;
 

    entity.save();


  }


  for (let i = 0; i < events.lendergroupLenderAddedPrincipals.length; i++) {

    let lenderAddPrincipal = events.lendergroupLenderAddedPrincipals[i];



  }


  for (let i = 0; i < events.lendergroupEarningsWithdrawns.length; i++) {

    let lenderWithdrawEarnings = events.lendergroupEarningsWithdrawns[i];



  }


  for (let i = 0; i < events.lendergroupBorrowerAcceptedFunds.length; i++) {

    let borrowerAcceptedFunds = events.lendergroupBorrowerAcceptedFunds[i];



  }


  for (let i = 0; i < events.lendergroupLoanRepaids.length; i++) {

    let borrowerRepaidLoan = events.lendergroupLoanRepaids[i];




  }


  for (let i = 0; i < events.lendergroupDefaultedLoanLiquidateds.length; i++) {

    let defaultedLoanLiquidation = events.lendergroupDefaultedLoanLiquidateds[i];




  }
 
}
