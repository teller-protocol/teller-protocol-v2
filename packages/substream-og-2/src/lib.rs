mod abi;
mod pb;
// mod rpc;
 

use hex_literal::hex;
use pb::contract::v1 as contract;
//use pb::collateral::v1 as collateral_contract;
use substreams::prelude::*;
use substreams::store;
use substreams::Hex;
use substreams_database_change::pb::database::DatabaseChanges;
use substreams_database_change::tables::Tables as DatabaseChangeTables;
use substreams_entity_change::pb::entity::EntityChanges;
use substreams_entity_change::tables::Tables as EntityChangesTables;
use substreams_ethereum::pb::eth::v2 as eth;
use substreams_ethereum::Event;
use std::collections::HashSet;



#[allow(unused_imports)]
use num_traits::cast::ToPrimitive;
use std::str::FromStr;
use substreams::scalar::BigDecimal;

substreams_ethereum::init!();


//make a better config for this ? 
/*

POLYGON 
const TELLERV2_CONTRACT: [u8; 20] = hex!("D3D79A066F2cD471841C047D372F218252Dbf8Ed");
const COLLATERAL_MANAGER_TRACKED_CONTRACT: [u8;20] = hex!("76888a882a4fF57455B5e74B791DD19DF3ba51Bb");
 

ARBITRUM 
const TELLERV2_CONTRACT: [u8; 20] = hex!(" ");
const COLLATERAL_MANAGER_TRACKED_CONTRACT: [u8;20] = hex!("71B04a8569914bCb99D5F95644CF6b089c826024");


BASE 
const TELLERV2_CONTRACT: [u8; 20] = hex!(" ");
const COLLATERAL_MANAGER_TRACKED_CONTRACT: [u8;20] = hex!("71B04a8569914bCb99D5F95644CF6b089c826024");


MAINNET 
const TELLERV2_CONTRACT: [u8; 20] = hex!(" ");
const COLLATERAL_MANAGER_TRACKED_CONTRACT: [u8;20] = hex!("2551A099129ad9b0b1FEc16f34D9CB73c237be8b");



*/



fn is_declared_dds_address(addr: &Vec<u8>, ordinal: u64, dds_store: &store::StoreGetInt64) -> bool {
    //    substreams::log::info!("Checking if address {} is declared dds address", Hex(addr).to_string());
    if dds_store.get_at(0, Hex(addr).to_string()).is_some() {
        return true;
    }
    return false;
}





const TELLERV2_CONTRACT: [u8; 20] = hex!("D3D79A066F2cD471841C047D372F218252Dbf8Ed");
// const MARKET_REGISTRY_CONTRACT: [u8;20] = hex!("2551A099129ad9b0b1FEc16f34D9CB73c237be8b");


/*


    consumes blocks , outputs events 
*/

fn map_tellerv2_events(blk: &eth::Block, events: &mut contract::Events) {


    events.teller_submitted_bids.append(&mut blk
        .receipts()
        .flat_map(|view| {
            view.receipt.logs.iter()
                .filter(|log| log.address == TELLERV2_CONTRACT)
                .filter_map(|log| {


                    if let Some(event) = abi::tellerv2_contract::events::SubmittedBid::match_and_decode(log) {
                        return Some(contract::TellerSubmittedBid {
                            evt_tx_hash: Hex(&view.transaction.hash).to_string(),
                            evt_index: log.block_index,
                            evt_block_time: blk.timestamp_seconds(),
                            evt_block_number: blk.number,
                            evt_address: Hex(&log.address).to_string(),


                            bid_id: event.bid_id.to_string(), 
                            metadata_uri: event.metadata_uri.to_vec(), 
                            borrower: event.borrower , 
                            receiver: event.receiver, 

                         
                        });
                    }

                    None
                })
        })
        .collect());


    events.teller_accepted_bids.append(&mut blk
        .receipts()
        .flat_map(|view| {
            view.receipt.logs.iter()
                .filter(|log| log.address == TELLERV2_CONTRACT)
                .filter_map(|log| {


                    if let Some(event) = abi::tellerv2_contract::events::AcceptedBid::match_and_decode(log) {
                        return Some(contract::TellerAcceptedBid {
                            evt_tx_hash: Hex(&view.transaction.hash).to_string(),
                            evt_index: log.block_index,
                            evt_block_time: blk.timestamp_seconds(),
                            evt_block_number: blk.number,
                            evt_address: Hex(&log.address).to_string(),


                            bid_id: event.bid_id.to_string(), 
                            lender:  event.lender ,  // Hex(& event.lender ).to_string() , 
                        //    metadata_uri: event.metadata_uri.to_vec(), 
                          //  borrower: event.borrower , 
                         //   receiver: event.receiver, 

                         
                        });
                    }

                    None
                })
        })
        .collect());  
}


//is this bad? to use 0 for the log ordinal?  
// if i  use the OG log ordinal, many of my events break for some reason.. maybe run CLI again ? 


/*
#[substreams::handlers::store]
fn store_factory_lendergroup_created(blk: eth::Block, store: StoreSetInt64) {
    for rcpt in blk.receipts() {
        for log in rcpt
            .receipt
            .logs
            .iter()
            .filter(|log| log.address == FACTORY_TRACKED_CONTRACT)
        {
            if let Some(event) = abi::factory_contract::events::DeployedLenderGroupContract::match_and_decode(log) {
                //log.ordinal
                 store.set(0, Hex(event.group_contract).to_string(), &1);
            }
        }
    }
}
 
 */
  



fn graph_tellerv2_out_simple(

    events: &contract::Events, 
    tables: &mut EntityChangesTables


    ) {
    // Loop over all the abis events to create table changes
  

     
  
    events.teller_submitted_bids.iter().for_each(|evt| {
        tables
            .create_row("teller_submitted_bids", format!("{}-{}", evt.evt_tx_hash, evt.evt_index))
            .set("evt_tx_hash", evt.evt_tx_hash.clone().into_bytes())
            .set("evt_index", BigInt::from( evt.evt_index ))
            .set("evt_block_time", BigInt::from(evt.evt_block_time))
            .set("evt_block_number", BigInt::from(evt.evt_block_number))
            .set("bid_id", &evt.bid_id );
    });
   
}

  

 
 
/*

    Consume events ->  builds a STORE 
*/

/*
#[substreams::handlers::store]
fn store_globals_from_events(
    events:  contract::Events, 
   
    bigint_set_store: StoreSetBigInt //for block time and block number 
) {
 
    
    events.lendergroup_earnings_withdrawns.iter().for_each(|evt: &contract::LendergroupEarningsWithdrawn| {
     
        bigint_set_store.set(ord,"latest_block_number", &BigInt::from( evt.evt_block_number ) );
        bigint_set_store.set(ord,"latest_block_time", &BigInt::from(  evt.evt_block_time ) );

        //add total collateral ! 
    });

     


}
*/
 
  

#[substreams::handlers::map]
fn map_events(
    blk: eth::Block,
    store_lendergroup: StoreGetInt64,
) -> Result<contract::Events, substreams::errors::Error> {
    let mut events = contract::Events::default();
    map_tellerv2_events(&blk, &mut events);
   // map_lendergroup_events(&blk, &store_lendergroup, &mut events);
    Ok(events)
}
 


#[substreams::handlers::map]
fn graph_out(
    events: contract::Events,
    store_globals: StoreGetBigInt, 
    store_bids_from_pools_data: StoreGetString,

    deltas_lendergroup_pool_metrics: Deltas<DeltaBigInt>,
    store_lendergroup_pool_metrics: StoreGetBigInt, 
    
    deltas_lendergroup_user_metrics: Deltas<DeltaBigInt>,

    store_collateral_withdrawn_data: StoreGetBigInt, 
  //  store_lendergroup_user_metrics: StoreGetBigInt, 

) -> Result<EntityChanges, substreams::errors::Error> {
    // Initialize Database Changes container
    let mut tables = EntityChangesTables::new();
    


        //for now 
     graph_tellerv2_out_simple(&events, &mut tables);
    

    /* graph_tellerv2_out(
        &events, 
        &mut tables, 

        &store_globals,
        &store_bids_from_pools_data,

        &deltas_lendergroup_pool_metrics,
        &store_lendergroup_pool_metrics,

        &deltas_lendergroup_user_metrics,

        &store_collateral_withdrawn_data
      //  &store_lendergroup_user_metrics,
        );
        
        */

    
        
                
    Ok(tables.to_entity_changes())
    }