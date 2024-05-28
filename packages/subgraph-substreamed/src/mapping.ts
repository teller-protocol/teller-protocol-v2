 
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
  
 
  for (let i = 0; i < events.facDeployedLenderGroupContracts.length; i++) {
    let deployedLenderGroupContractEvent = events.facDeployedLenderGroupContracts[i];

    let event_id = deployedLenderGroupContractEvent.evtTxHash
    .concat( "_" )
    .concat( deployedLenderGroupContractEvent.evtIndex.toString() );   
    let entity = new factory_deployed_lender_group_contract( event_id );

    if (deployedLenderGroupContractEvent.evtBlockTime) {

      entity.evt_tx_hash = deployedLenderGroupContractEvent.evtTxHash;
      entity.evt_block_number = BigInt.fromU64( deployedLenderGroupContractEvent.evtBlockNumber );
      
      entity.evt_index =  BigInt.fromI32(deployedLenderGroupContractEvent.evtIndex);

  
      entity.group_contract = Address.fromString(deployedLenderGroupContractEvent.groupContract.toString());
      

      entity.save();

    }
   
} 
 
}
