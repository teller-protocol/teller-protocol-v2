mod abi;
mod pb;
mod rpc;
 

use hex_literal::hex;
use pb::contract::v1 as contract;
use pb::collateral::v1 as collateral_contract;
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
const FACTORY_TRACKED_CONTRACT: [u8; 20] = hex!("2fF5ea5CF5061EB0fcfB7A2AafB8CCC79f3F73ea");
const COLLATERAL_MANAGER_TRACKED_CONTRACT: [u8;20] = hex!("76888a882a4fF57455B5e74B791DD19DF3ba51Bb");
 

ARBITRUM 
const FACTORY_TRACKED_CONTRACT: [u8; 20] = hex!("C2a093B641496Ac8AA9d6a17f216ADF4a42FC9B6");
const COLLATERAL_MANAGER_TRACKED_CONTRACT: [u8;20] = hex!("71B04a8569914bCb99D5F95644CF6b089c826024");


BASE 
const FACTORY_TRACKED_CONTRACT: [u8; 20] = hex!("7FBCefE4aE4c0C9E70427D0B9F1504Ed39d141BC");
const COLLATERAL_MANAGER_TRACKED_CONTRACT: [u8;20] = hex!("71B04a8569914bCb99D5F95644CF6b089c826024");


MAINNET 
const FACTORY_TRACKED_CONTRACT: [u8; 20] = hex!("0848E884b2DBb63727aa3216b921C279f6DC9a91");
const COLLATERAL_MANAGER_TRACKED_CONTRACT: [u8;20] = hex!("2551A099129ad9b0b1FEc16f34D9CB73c237be8b");



*/



const FACTORY_TRACKED_CONTRACT: [u8; 20] = hex!("0848E884b2DBb63727aa3216b921C279f6DC9a91");
const COLLATERAL_MANAGER_TRACKED_CONTRACT: [u8;20] = hex!("2551A099129ad9b0b1FEc16f34D9CB73c237be8b");


fn map_factory_events(blk: &eth::Block, events: &mut contract::Events) {
    /*events.factory_admin_changeds.append(&mut blk
        .receipts()
        .flat_map(|view| {
            view.receipt.logs.iter()
                .filter(|log| log.address == FACTORY_TRACKED_CONTRACT)
                .filter_map(|log| {
                    if let Some(event) = abi::factory_contract::events::AdminChanged::match_and_decode(log) {
                        return Some(contract::FactoryAdminChanged {
                            evt_tx_hash: Hex(&view.transaction.hash).to_string(),
                            evt_index: log.block_index,
                            evt_block_time: blk.timestamp_seconds(),
                            evt_block_number: blk.number,
                            new_admin: event.new_admin,
                            previous_admin: event.previous_admin,
                        });
                    }

                    None
                })
        })
        .collect());
    events.factory_beacon_upgradeds.append(&mut blk
        .receipts()
        .flat_map(|view| {
            view.receipt.logs.iter()
                .filter(|log| log.address == FACTORY_TRACKED_CONTRACT)
                .filter_map(|log| {
                    if let Some(event) = abi::factory_contract::events::BeaconUpgraded::match_and_decode(log) {
                        return Some(contract::FactoryBeaconUpgraded {
                            evt_tx_hash: Hex(&view.transaction.hash).to_string(),
                            evt_index: log.block_index,
                            evt_block_time: blk.timestamp_seconds(),
                            evt_block_number: blk.number,
                            beacon: event.beacon,
                        });
                    }

                    None
                })
        })
        .collect());
        
        
        events.factory_upgradeds.append(&mut blk
        .receipts()
        .flat_map(|view| {
            view.receipt.logs.iter()
                .filter(|log| log.address == FACTORY_TRACKED_CONTRACT)
                .filter_map(|log| {
                    if let Some(event) = abi::factory_contract::events::Upgraded::match_and_decode(log) {
                        return Some(contract::FactoryUpgraded {
                            evt_tx_hash: Hex(&view.transaction.hash).to_string(),
                            evt_index: log.block_index,
                            evt_block_time: blk.timestamp_seconds(),
                            evt_block_number: blk.number,
                            implementation: event.implementation,
                        });
                    }

                    None
                })
        })
        .collect());
        
        
        */
    events.factory_deployed_lender_group_contracts.append(&mut blk
        .receipts()
        .flat_map(|view| {
            view.receipt.logs.iter()
                .filter(|log| log.address == FACTORY_TRACKED_CONTRACT)
                .filter_map(|log| {
                    if let Some(event) = abi::factory_contract::events::DeployedLenderGroupContract::match_and_decode(log) {
                        return Some(contract::FactoryDeployedLenderGroupContract {
                            evt_tx_hash: Hex(&view.transaction.hash).to_string(),
                            evt_index: log.block_index,
                            evt_block_time: blk.timestamp_seconds(),
                            evt_block_number: blk.number,
                            group_contract: event.group_contract,
                        });
                    }

                    None
                })
        })
        .collect());
  
}


//is this bad? to use 0 for the log ordinal?  
// if i  use the OG log ordinal, many of my events break for some reason.. maybe run CLI again ? 
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
 
 
 
fn is_declared_dds_address(addr: &Vec<u8>, ordinal: u64, dds_store: &store::StoreGetInt64) -> bool {
    //    substreams::log::info!("Checking if address {} is declared dds address", Hex(addr).to_string());
    if dds_store.get_at(0, Hex(addr).to_string()).is_some() {
        return true;
    }
    return false;
}

fn map_lendergroup_events(
    blk: &eth::Block,
    dds_store: &store::StoreGetInt64,   //this is used to know abt lendergroup contract address
    events: &mut contract::Events,
) {

    events.lendergroup_borrower_accepted_funds.append(&mut blk
        .receipts()
        .flat_map(|view| {
            view.receipt.logs.iter()
                .filter(|log| is_declared_dds_address(&log.address, log.ordinal, dds_store))
                .filter_map(|log| {
                    if let Some(event) = abi::lendergroup_contract::events::BorrowerAcceptedFunds::match_and_decode(log) {
                        return Some(contract::LendergroupBorrowerAcceptedFunds {
                            evt_tx_hash: Hex(&view.transaction.hash).to_string(),
                            evt_index: log.block_index,
                            evt_block_time: blk.timestamp_seconds(),
                            evt_block_number: blk.number,
                            evt_address: Hex(&log.address).to_string(),
                            bid_id: event.bid_id.to_string(),
                            borrower: event.borrower,
                            collateral_amount: event.collateral_amount.to_string(),
                            interest_rate: event.interest_rate.to_u64(),
                            loan_duration: event.loan_duration.to_u64(),
                            principal_amount: event.principal_amount.to_string(),
                        });
                    }

                    None
                })
        })
        .collect());

    events.lendergroup_defaulted_loan_liquidateds.append(&mut blk
        .receipts()
        .flat_map(|view| {
            view.receipt.logs.iter()
                .filter(|log| is_declared_dds_address(&log.address, log.ordinal, dds_store))
                .filter_map(|log| {
                    if let Some(event) = abi::lendergroup_contract::events::DefaultedLoanLiquidated::match_and_decode(log) {
                        return Some(contract::LendergroupDefaultedLoanLiquidated {
                            evt_tx_hash: Hex(&view.transaction.hash).to_string(),
                            evt_index: log.block_index,
                            evt_block_time: blk.timestamp_seconds(),
                            evt_block_number: blk.number,
                            evt_address: Hex(&log.address).to_string(),
                            amount_due: event.amount_due.to_string(),
                            bid_id: event.bid_id.to_string(),
                            liquidator: event.liquidator,
                            token_amount_difference: event.token_amount_difference.to_string(),
                        });
                    }

                    None
                })
        })
        .collect());

    events.lendergroup_earnings_withdrawns.append(&mut blk
        .receipts()
        .flat_map(|view| {
            view.receipt.logs.iter()
                .filter(|log| is_declared_dds_address(&log.address, log.ordinal, dds_store))
                .filter_map(|log| {
                    if let Some(event) = abi::lendergroup_contract::events::EarningsWithdrawn::match_and_decode(log) {
                        return Some(contract::LendergroupEarningsWithdrawn {
                            evt_tx_hash: Hex(&view.transaction.hash).to_string(),
                            evt_index: log.block_index,
                            evt_block_time: blk.timestamp_seconds(),
                            evt_block_number: blk.number,
                            evt_address: Hex(&log.address).to_string(),
                            amount_pool_shares_tokens: event.amount_pool_shares_tokens.to_string(),
                            lender: event.lender,
                            principal_tokens_withdrawn: event.principal_tokens_withdrawn.to_string(),
                            recipient: event.recipient,
                        });
                    }

                    None
                })
        })
        .collect());

    events.lendergroup_initializeds.append(&mut blk
        .receipts()
        .flat_map(|view| {
            view.receipt.logs.iter()
                .filter(|log| is_declared_dds_address(&log.address, log.ordinal, dds_store))
                .filter_map(|log| {
                    if let Some(event) = abi::lendergroup_contract::events::Initialized::match_and_decode(log) {
                        return Some(contract::LendergroupInitialized {
                            evt_tx_hash: Hex(&view.transaction.hash).to_string(),
                            evt_index: log.block_index,
                            evt_block_time: blk.timestamp_seconds(),
                            evt_block_number: blk.number,
                            evt_address: Hex(&log.address).to_string(),
                            version: event.version.to_u64(),
                        });
                    }

                    None
                })
        })
        .collect());

    events.lendergroup_lender_added_principals.append(&mut blk
        .receipts()
        .flat_map(|view| {
            view.receipt.logs.iter()
                .filter(|log| is_declared_dds_address(&log.address, log.ordinal, dds_store))
                .filter_map(|log| {
                    if let Some(event) = abi::lendergroup_contract::events::LenderAddedPrincipal::match_and_decode(log) {
                        return Some(contract::LendergroupLenderAddedPrincipal {
                            evt_tx_hash: Hex(&view.transaction.hash).to_string(),
                            evt_index: log.block_index,
                            evt_block_time: blk.timestamp_seconds(),
                            evt_block_number: blk.number,
                            evt_address: Hex(&log.address).to_string(),
                            amount: event.amount.to_string(),
                            lender: event.lender,
                            shares_amount: event.shares_amount.to_string(),
                            shares_recipient: event.shares_recipient,
                        });
                    }

                    None
                })
        })
        .collect());

    events.lendergroup_loan_repaids.append(&mut blk
        .receipts()
        .flat_map(|view| {
            view.receipt.logs.iter()
                .filter(|log| is_declared_dds_address(&log.address, log.ordinal, dds_store))
                .filter_map(|log| {
                    if let Some(event) = abi::lendergroup_contract::events::LoanRepaid::match_and_decode(log) {
                        return Some(contract::LendergroupLoanRepaid {
                            evt_tx_hash: Hex(&view.transaction.hash).to_string(),
                            evt_index: log.block_index,
                            evt_block_time: blk.timestamp_seconds(),
                            evt_block_number: blk.number,
                            evt_address: Hex(&log.address).to_string(),
                            bid_id: event.bid_id.to_string(),
                            interest_amount: event.interest_amount.to_string(),
                            principal_amount: event.principal_amount.to_string(),
                            repayer: event.repayer,
                            total_interest_collected: event.total_interest_collected.to_string(),
                            total_principal_repaid: event.total_principal_repaid.to_string(),
                        });
                    }

                    None
                })
        })
        .collect());

    events.lendergroup_ownership_transferreds.append(&mut blk
        .receipts()
        .flat_map(|view| {
            view.receipt.logs.iter()
                .filter(|log| is_declared_dds_address(&log.address, log.ordinal, dds_store))
                .filter_map(|log| {
                    if let Some(event) = abi::lendergroup_contract::events::OwnershipTransferred::match_and_decode(log) {
                        return Some(contract::LendergroupOwnershipTransferred {
                            evt_tx_hash: Hex(&view.transaction.hash).to_string(),
                            evt_index: log.block_index,
                            evt_block_time: blk.timestamp_seconds(),
                            evt_block_number: blk.number,
                            evt_address: Hex(&log.address).to_string(),
                            new_owner: event.new_owner,
                            previous_owner: event.previous_owner,
                        });
                    }

                    None
                })
        })
        .collect());

    events.lendergroup_pauseds.append(&mut blk
        .receipts()
        .flat_map(|view| {
            view.receipt.logs.iter()
                .filter(|log| is_declared_dds_address(&log.address, log.ordinal, dds_store))
                .filter_map(|log| {
                    if let Some(event) = abi::lendergroup_contract::events::Paused::match_and_decode(log) {
                        return Some(contract::LendergroupPaused {
                            evt_tx_hash: Hex(&view.transaction.hash).to_string(),
                            evt_index: log.block_index,
                            evt_block_time: blk.timestamp_seconds(),
                            evt_block_number: blk.number,
                            evt_address: Hex(&log.address).to_string(),
                            account: event.account,
                        });
                    }

                    None
                })
        })
        .collect());

    events.lendergroup_pool_initializeds.append(&mut blk
        .receipts()
        .flat_map(|view| {
            view.receipt.logs.iter()
                .filter(|log| 
                        

                    //this is a massive problem 
                    is_declared_dds_address(&log.address, log.ordinal, dds_store)
                   // true
                    
                    )
                .filter_map(|log| {
                    if let Some(event) = abi::lendergroup_contract::events::PoolInitialized::match_and_decode(log) {
                        
                        substreams::log::info!("pool initialized evt found ");
                        
                            
                            
                       let lender_group_contract_address = Hex(&log.address).to_string();

                         let fetched_rpc_data = rpc::fetch_lender_group_pool_initialization_data_from_rpc(
                            &lender_group_contract_address
                             ).unwrap();
                             
                        
                        return Some(contract::LendergroupPoolInitialized {
                            evt_tx_hash: Hex(&view.transaction.hash).to_string(),
                            evt_index: log.block_index,
                            evt_block_time: blk.timestamp_seconds(),
                            evt_block_number: blk.number,
                            evt_address: Hex(&log.address).to_string(),
                            collateral_token_address: event.collateral_token_address,
                            interest_rate_lower_bound: event.interest_rate_lower_bound.to_u64(),
                            interest_rate_upper_bound: event.interest_rate_upper_bound.to_u64(),
                            liquidity_threshold_percent: event.liquidity_threshold_percent.to_u64(),
                            loan_to_value_percent: event.loan_to_value_percent.to_u64(),
                            market_id: event.market_id.to_string(),
                            max_loan_duration: event.max_loan_duration.to_u64(),
                            pool_shares_token: event.pool_shares_token,
                            principal_token_address: event.principal_token_address,
                           // twap_interval: event.twap_interval.to_u64(),
                           // uniswap_pool_fee: event.uniswap_pool_fee.to_u64(),

                            teller_v2_address: fetched_rpc_data.teller_v2_address.to_fixed_bytes().to_vec(),
                           // uniswap_v3_pool_address: fetched_rpc_data.uniswap_v3_pool_address.to_fixed_bytes().to_vec(),
                            smart_commitment_forwarder_address: fetched_rpc_data.smart_commitment_forwarder_address.to_fixed_bytes().to_vec(),
                        });
                    } 

                    None
                })
        })
        .collect());

    events.lendergroup_unpauseds.append(&mut blk
        .receipts()
        .flat_map(|view| {
            view.receipt.logs.iter()
                .filter(|log| is_declared_dds_address(&log.address, log.ordinal, dds_store))
                .filter_map(|log| {
                    if let Some(event) = abi::lendergroup_contract::events::Unpaused::match_and_decode(log) {
                        return Some(contract::LendergroupUnpaused {
                            evt_tx_hash: Hex(&view.transaction.hash).to_string(),
                            evt_index: log.block_index,
                            evt_block_time: blk.timestamp_seconds(),
                            evt_block_number: blk.number,
                            evt_address: Hex(&log.address).to_string(),
                            account: event.account,
                        });
                    }

                    None
                })
        })
        .collect());
}
 

fn graph_factory_out(events: &contract::Events, tables: &mut EntityChangesTables) {
    // Loop over all the abis events to create table changes
   /*events.factory_admin_changeds.iter().for_each(|evt| {
        tables
            .create_row("factory_admin_changed", format!("{}-{}", evt.evt_tx_hash, evt.evt_index))
            .set("evt_tx_hash", evt.evt_tx_hash.clone().into_bytes())
            .set("evt_index", BigInt::from( evt.evt_index)  )
            .set("evt_block_time", BigInt::from ( evt.evt_block_time )) 
            .set("evt_block_number", BigInt::from( evt.evt_block_number) )
            .set("new_admin",  &evt.new_admin )  //throws an error ??
            .set("previous_admin",  &evt.previous_admin  );
    });
    
      events.factory_beacon_upgradeds.iter().for_each(|evt| {
        tables
            .create_row("factory_beacon_upgraded", format!("{}-{}", evt.evt_tx_hash, evt.evt_index))
            .set("evt_tx_hash", evt.evt_tx_hash.clone().into_bytes())
            .set("evt_index", BigInt::from(evt.evt_index))
            .set("evt_block_time", BigInt::from( evt.evt_block_time ))
            .set("evt_block_number", BigInt::from( evt.evt_block_number ))
            .set("beacon",  &evt.beacon );
    });
    
     events.factory_upgradeds.iter().for_each(|evt| {
        tables
            .create_row("factory_upgraded", format!("{}-{}", evt.evt_tx_hash, evt.evt_index))
            .set("evt_tx_hash", evt.evt_tx_hash.clone().into_bytes())
            .set("evt_index", BigInt::from(evt.evt_index))
            .set("evt_block_time", BigInt::from(evt.evt_block_time))
            .set("evt_block_number", BigInt::from(evt.evt_block_number))
            .set("implementation",  &evt.implementation  );
    });
    */
     
  
    events.factory_deployed_lender_group_contracts.iter().for_each(|evt| {
        tables
            .create_row("factory_deployed_lender_group_contract", format!("{}-{}", evt.evt_tx_hash, evt.evt_index))
            .set("evt_tx_hash", evt.evt_tx_hash.clone().into_bytes())
            .set("evt_index", BigInt::from( evt.evt_index ))
            .set("evt_block_time", BigInt::from(evt.evt_block_time))
            .set("evt_block_number", BigInt::from(evt.evt_block_number))
            .set("group_contract", &evt.group_contract );
    });
   
}


//make sure these match schema.graphql ! 
fn graph_lendergroup_out(
     events: &contract::Events,
     tables: &mut EntityChangesTables,
     store_get_globals: &StoreGetBigInt, 
     store_bids_from_pools_data: &StoreGetString,

     deltas_lendergroup_pool_metrics: &Deltas<DeltaBigInt>,
     store_get_lendergroup_pool_metrics: &StoreGetBigInt, 
  
     deltas_lendergroup_user_metrics: &Deltas<DeltaBigInt>,

     store_collateral_withdrawn_data: &StoreGetBigInt, 
    // store_get_lendergroup_user_metrics: &StoreGetBigInt, not used 
  
    
    ) {
    // Loop over all the abis events to create table changes
    events.lendergroup_borrower_accepted_funds.iter().for_each(|evt| {
        tables
            .create_row("group_borrower_accepted_funds", format!("{}-{}", evt.evt_tx_hash, evt.evt_index))
            .set("evt_tx_hash", evt.evt_tx_hash.clone().into_bytes())  //maybe do hex to string first ? 
            .set("evt_index", BigInt::from(evt.evt_index))
            .set("evt_block_time", BigInt::from(evt.evt_block_time))
            .set("evt_block_number", BigInt::from(evt.evt_block_number))
            .set("group_pool_address", Hex::decode(&evt.evt_address).unwrap() )
            .set("bid_id", BigDecimal::from_str(&evt.bid_id).unwrap())
            .set("borrower",  &evt.borrower )
            .set("collateral_amount", BigDecimal::from_str(&evt.collateral_amount).unwrap())
            .set("interest_rate", evt.interest_rate)
            .set("loan_duration", evt.loan_duration)
            .set("principal_amount", BigDecimal::from_str(&evt.principal_amount).unwrap());
            
            
            
            
            /*            
            
            This occurs when someone takes out a loan with a lender group .
            
            This is only going to give us the BidId 
            
            */
            
              tables
            .create_row("group_pool_bid", format!("{}", evt.evt_address )  ) 
           
            .set("group_pool_address", Hex::decode(&evt.evt_address).unwrap() )
            .set("bid_id", BigDecimal::from_str(&evt.bid_id).unwrap() )
            .set("borrower",  &evt.borrower )
            .set("principal_amount", BigDecimal::from_str(&evt.principal_amount).unwrap())
            .set("collateral_amount", BigDecimal::from_str(&evt.collateral_amount).unwrap())
            
            ;
    });
    events.lendergroup_defaulted_loan_liquidateds.iter().for_each(|evt| {
        tables
            .create_row("group_defaulted_loan_liquidated", format!("{}-{}", evt.evt_tx_hash, evt.evt_index))
            .set("evt_tx_hash", evt.evt_tx_hash.clone().into_bytes())
            .set("evt_index", BigInt::from(evt.evt_index))
            .set("evt_block_time", BigInt::from(evt.evt_block_time))
            .set("evt_block_number", BigInt::from(evt.evt_block_number))
            .set("group_pool_address", Hex::decode(&evt.evt_address).unwrap() )
            .set("amount_due", BigDecimal::from_str(&evt.amount_due).unwrap())
            .set("bid_id", BigDecimal::from_str(&evt.bid_id).unwrap())
            .set("liquidator", &evt.liquidator )
            .set("token_amount_difference", BigDecimal::from_str(&evt.token_amount_difference).unwrap());
    });
    events.lendergroup_earnings_withdrawns.iter().for_each(|evt| {
        tables
            .create_row("group_earnings_withdrawn", format!("{}-{}", evt.evt_tx_hash, evt.evt_index))
            .set("evt_tx_hash", evt.evt_tx_hash.clone().into_bytes())
            .set("evt_index", BigInt::from(evt.evt_index))
            .set("evt_block_time", BigInt::from(evt.evt_block_time))
            .set("evt_block_number", BigInt::from(evt.evt_block_number))
            .set("group_pool_address", Hex::decode(&evt.evt_address).unwrap() )
            .set("amount_pool_shares_tokens", BigDecimal::from_str(&evt.amount_pool_shares_tokens).unwrap())
            .set("lender", &evt.lender )
            .set("principal_tokens_withdrawn", BigDecimal::from_str(&evt.principal_tokens_withdrawn).unwrap())
            .set("recipient",  &evt.recipient );
    });
    events.lendergroup_initializeds.iter().for_each(|evt| {
        tables
            .create_row("group_initialized", format!("{}-{}", evt.evt_tx_hash, evt.evt_index))
            .set("evt_tx_hash", evt.evt_tx_hash.clone().into_bytes())
            .set("evt_index", BigInt::from(evt.evt_index))
            .set("evt_block_time", BigInt::from(evt.evt_block_time))
            .set("evt_block_number", BigInt::from(evt.evt_block_number))
            .set("group_pool_address", Hex::decode(&evt.evt_address).unwrap() )
            .set("version", evt.version);
    });
    events.lendergroup_lender_added_principals.iter().for_each(|evt| {
        tables
            .create_row("group_lender_added_principal", format!("{}-{}", evt.evt_tx_hash, evt.evt_index))
            .set("evt_tx_hash", evt.evt_tx_hash.clone().into_bytes())
            .set("evt_index", BigInt::from(evt.evt_index))
            .set("evt_block_time", BigInt::from(evt.evt_block_time))
            .set("evt_block_number", BigInt::from(evt.evt_block_number))
            .set("group_pool_address", Hex::decode(&evt.evt_address).unwrap() )
            .set("amount", BigDecimal::from_str(&evt.amount).unwrap())
            .set("lender",  &evt.lender )
            .set("shares_amount", BigDecimal::from_str(&evt.shares_amount).unwrap())
            .set("shares_recipient",  &evt.shares_recipient );
    });
    events.lendergroup_loan_repaids.iter().for_each(|evt| {
        tables
            .create_row("group_loan_repaid", format!("{}-{}", evt.evt_tx_hash, evt.evt_index))
            .set("evt_tx_hash", evt.evt_tx_hash.clone().into_bytes())
            .set("evt_index", BigInt::from(evt.evt_index))
            .set("evt_block_time", BigInt::from(evt.evt_block_time))
            .set("evt_block_number", BigInt::from(evt.evt_block_number))
            .set("group_pool_address", Hex::decode(&evt.evt_address).unwrap() )
            .set("bid_id", BigDecimal::from_str(&evt.bid_id).unwrap())
            .set("interest_amount", BigDecimal::from_str(&evt.interest_amount).unwrap())
            .set("principal_amount", BigDecimal::from_str(&evt.principal_amount).unwrap())
            .set("repayer",  &evt.repayer )
            .set("total_interest_collected", BigDecimal::from_str(&evt.total_interest_collected).unwrap())
            .set("total_principal_repaid", BigDecimal::from_str(&evt.total_principal_repaid).unwrap());
    });
    events.lendergroup_ownership_transferreds.iter().for_each(|evt| {
        tables
            .create_row("group_ownership_transferred", format!("{}-{}", evt.evt_tx_hash, evt.evt_index))
            .set("evt_tx_hash", evt.evt_tx_hash.clone().into_bytes())
            .set("evt_index", BigInt::from(evt.evt_index))
            .set("evt_block_time", BigInt::from(evt.evt_block_time))
            .set("evt_block_number", BigInt::from(evt.evt_block_number))
            .set("group_pool_address", Hex::decode(&evt.evt_address).unwrap() )
            .set("new_owner",  &evt.new_owner )
            .set("previous_owner",  &evt.previous_owner );
    });
    events.lendergroup_pauseds.iter().for_each(|evt| {
        tables
            .create_row("group_paused", format!("{}-{}", evt.evt_tx_hash, evt.evt_index))
            .set("evt_tx_hash", evt.evt_tx_hash.clone().into_bytes())
            .set("evt_index", BigInt::from(evt.evt_index))
            .set("evt_block_time", BigInt::from(evt.evt_block_time))
            .set("evt_block_number", BigInt::from(evt.evt_block_number))
            .set("group_pool_address", Hex::decode(&evt.evt_address).unwrap() )
            .set("account",  &evt.account );
    });
    events.lendergroup_pool_initializeds.iter().for_each(|evt| {
        tables
            .create_row("group_pool_initialized", format!("{}-{}", evt.evt_tx_hash, evt.evt_index))
            .set("evt_tx_hash", evt.evt_tx_hash.clone().into_bytes())
            .set("evt_index", BigInt::from(evt.evt_index))
            .set("evt_block_time", BigInt::from(evt.evt_block_time))
            .set("evt_block_number", BigInt::from(evt.evt_block_number))
            .set("group_pool_address", Hex::decode(&evt.evt_address).unwrap() )
            .set("collateral_token_address",  &evt.collateral_token_address )
            .set("interest_rate_lower_bound", evt.interest_rate_lower_bound)
            .set("interest_rate_upper_bound", evt.interest_rate_upper_bound)
            .set("liquidity_threshold_percent", evt.liquidity_threshold_percent)
            .set("loan_to_value_percent", evt.loan_to_value_percent)
            .set("market_id", BigInt::from_str(&evt.market_id).unwrap())
            .set("max_loan_duration", evt.max_loan_duration)
            .set("pool_shares_token",  &evt.pool_shares_token )
            .set("principal_token_address", &evt.principal_token_address )
           // .set("twap_interval", evt.twap_interval)
            //.set("uniswap_pool_fee", evt.uniswap_pool_fee)
            ;

    
            

             
          // let lender_group_contract_address = Hex::decode(&evt.evt_address).unwrap();
   
           let fetched_min_interest_rate = rpc::fetch_min_interest_rate_from_rpc(
                &evt.evt_address,
                 BigInt::zero() 
                 ).unwrap();
            
           let fetched_token_amount_difference = rpc::fetch_token_amount_difference_from_liquidations(&evt.evt_address).unwrap_or_default();
         
    
       //create group pool metric 
       tables
            .create_row("group_pool_metric", format!("{}", evt.evt_address )  ) 

            .set("created_at", BigInt::from(evt.evt_block_time))
           
            .set("group_pool_address", Hex::decode(&evt.evt_address).unwrap() )
            .set("principal_token_address",  &evt.principal_token_address  )
            .set("collateral_token_address",  &evt.collateral_token_address  )
            .set("shares_token_address",  &evt.pool_shares_token  )
          //  .set("uniswap_v3_pool_address",  &evt.uniswap_v3_pool_address )
            .set("teller_v2_address",  &evt.teller_v2_address  )
            .set("smart_commitment_forwarder_address",  &evt.smart_commitment_forwarder_address  )
            .set("market_id", BigInt::from_str(&evt.market_id).unwrap() )
           // .set("uniswap_pool_fee", evt.uniswap_pool_fee)
            .set("max_loan_duration", evt.max_loan_duration)
           // .set("twap_interval", evt.twap_interval)
            .set("interest_rate_upper_bound", evt.interest_rate_upper_bound)
            .set("interest_rate_lower_bound", evt.interest_rate_lower_bound)
            .set("liquidity_threshold_percent", evt.liquidity_threshold_percent)
            .set("collateral_ratio", evt.loan_to_value_percent)  //rename me 
            .set("current_min_interest_rate",  fetched_min_interest_rate) 
                 
            //when do these get set !? 
            .set("total_principal_tokens_committed",  BigInt::zero()) 
            .set("total_collateral_tokens_escrowed",  BigInt::zero()) 
            .set("total_principal_tokens_withdrawn",  BigInt::zero()) 
            .set("total_principal_tokens_borrowed",  BigInt::zero()) 
            .set("total_principal_tokens_repaid",  BigInt::zero()) 
            .set("total_interest_collected",  BigInt::zero()) 
            .set("token_difference_from_liquidations",  fetched_token_amount_difference) 
            .set("total_collateral_withdrawn",  BigInt::zero()) 
           // .set("ordinal",   evt.log.ordinal  )  //is this ok ?  
            ;

         
                  



    });
    events.lendergroup_unpauseds.iter().for_each(|evt| {
        tables
            .create_row("group_unpaused", format!("{}-{}", evt.evt_tx_hash, evt.evt_index))
            .set("evt_tx_hash", evt.evt_tx_hash.clone().into_bytes())
            .set("evt_index", BigInt::from(evt.evt_index))
            .set("evt_block_time", BigInt::from(evt.evt_block_time))
            .set("evt_block_number", BigInt::from(evt.evt_block_number))
            .set("group_pool_address", Hex::decode(&evt.evt_address).unwrap() )
            .set("account",  &evt.account  );
    });





    
     // -------------
    
    
    



        // read the data from the table   group_pool_metrics 


        //create a new row for the table "group_pool_metrics_data_points" based on that 
        
     //   let group_address = Address::from_slice(  & Hex::decode(&evt.evt_address).unwrap() )    ; //evt.evt_address.clone();
        
            
         let mut pool_metric_deltas_detected = HashSet::new();
         
     
         for pool_metric_delta in deltas_lendergroup_pool_metrics.deltas. iter(){
             
                    
                        //this splits on ":"
                let delta_root_identifier = substreams::key::segment_at(pool_metric_delta.get_key(), 0);


                //maybe this is breaking things ?
               if delta_root_identifier != "group_pool_metric" {continue};
                
                let group_address = substreams::key::segment_at(pool_metric_delta.get_key(), 1);
                let delta_prop_identifier = substreams::key::segment_at(pool_metric_delta.get_key(), 2);
                        
                        
                        
               // let block_number = BigInt::zero(); // FOR NOW 
                let new_value = &pool_metric_delta.new_value ;
                        
                        
                pool_metric_deltas_detected.insert(group_address);
                        
                        
              
                        

                //add more here 
                 match delta_prop_identifier  { 
                    "total_principal_tokens_committed" => {
                        tables.update_row("group_pool_metric", &group_address)
                            .set("total_principal_tokens_committed", new_value );
                    },
                    "total_collateral_tokens_escrowed" => {
                        tables.update_row("group_pool_metric", &group_address)
                            .set("total_collateral_tokens_escrowed", new_value );
                    },
                    "total_principal_tokens_withdrawn" => {
                        tables.update_row("group_pool_metric", &group_address)
                            .set("total_principal_tokens_withdrawn", new_value );
                    },
                    "total_principal_tokens_borrowed" => {
                        tables.update_row("group_pool_metric", &group_address)
                            .set("total_principal_tokens_borrowed", new_value );
                    },
                    "total_principal_tokens_repaid" => {
                        tables.update_row("group_pool_metric", &group_address)
                            .set("total_principal_tokens_repaid", new_value );
                    },
                    "total_interest_collected" => {
                        tables.update_row("group_pool_metric", &group_address)
                            .set("total_interest_collected", new_value );
                    },
                  
                    // Add more cases as per your metric names
                    _ => {}
                };
                             
                                     
                             
        // Create row in group_pool_metrics_data_point table
          
                                      
         }
         
         
          for group_pool_address in pool_metric_deltas_detected.iter() {
                       
               let fetched_min_interest_rate = rpc::fetch_min_interest_rate_from_rpc(
                     &group_pool_address.to_string(),
                      BigInt::zero()
                    ).unwrap();
                    
            
                    
                tables.update_row("group_pool_metric", &group_pool_address)
                            .set("current_min_interest_rate", fetched_min_interest_rate );



                let fetched_token_amount_difference = rpc::fetch_token_amount_difference_from_liquidations(&group_pool_address.to_string()).unwrap_or_default();
         
                    
            
                    
                tables.update_row("group_pool_metric", &group_pool_address)
                            .set("token_difference_from_liquidations", fetched_token_amount_difference );
                    
          }
            
        //add total collateral withdrawn data 


        for group_pool_address in pool_metric_deltas_detected.iter() {

            let store_key = format!("total_collateral_amount_withdrawn:{}", group_pool_address);


            //change this source !? 
            let ord = 0; // for now 
            if let Some( collateral_withdrawn_delta ) = store_collateral_withdrawn_data.get_at(ord, store_key){

                tables.update_row("group_pool_metric", &group_pool_address)
                .set("total_collateral_withdrawn", collateral_withdrawn_delta );
                

            }

          
        }
         
         //need to use a non-delta store!?
         for group_pool_address in pool_metric_deltas_detected.iter() {
             
                
            //get the data from store_get_lendergroup_pool_metrics
               
               
            let ord = 0; // FOR NOW - CAN CAUSE ISSUES 
               
            let block_number = store_get_globals
            .get_at(ord, format!("latest_block_number"   ))
            .unwrap_or(BigInt::zero());  
            let block_time = store_get_globals
            .get_at(ord, format!("latest_block_time"   ))
            .unwrap_or(BigInt::zero());   
               
               
               //turn this into an enum !?
            let total_principal_committed = store_get_lendergroup_pool_metrics
            .get_at(ord, format!("group_pool_metric:{}:total_principal_tokens_committed", group_pool_address  ))
            .unwrap_or(BigInt::zero()) ;
           
            let total_collateral_escrowed = store_get_lendergroup_pool_metrics
            .get_at(ord, format!("group_pool_metric:{}:total_collateral_tokens_escrowed", group_pool_address  ))
            .unwrap_or(BigInt::zero()) ;
            

            //this comes from a special source !! since it comes from CollateralManager contract 
            let total_collateral_withdrawn = store_collateral_withdrawn_data
            .get_at(ord, format!("total_collateral_amount_withdrawn:{}", group_pool_address) )
            .unwrap_or(BigInt::zero()) ;
                
            let total_principal_tokens_withdrawn = store_get_lendergroup_pool_metrics
            .get_at(ord, format!("group_pool_metric:{}:total_principal_tokens_withdrawn", group_pool_address  ))
            .unwrap_or(BigInt::zero()) ;
                
            let total_principal_tokens_borrowed = store_get_lendergroup_pool_metrics
            .get_at(ord, format!("group_pool_metric:{}:total_principal_tokens_borrowed", group_pool_address  ))
            .unwrap_or(BigInt::zero()) ;
                
            let total_principal_tokens_repaid = store_get_lendergroup_pool_metrics
            .get_at(ord, format!("group_pool_metric:{}:total_principal_tokens_repaid", group_pool_address  ))
            .unwrap_or(BigInt::zero()) ;
                
            let total_interest_collected = store_get_lendergroup_pool_metrics
            .get_at(ord, format!("group_pool_metric:{}:total_interest_collected", group_pool_address  ))
            .unwrap_or(BigInt::zero()) ;



            let fetched_token_amount_difference = rpc::fetch_token_amount_difference_from_liquidations(&group_pool_address.to_string()).unwrap_or_default();
         
                
            /* let token_difference_from_liquidations = store_get_lendergroup_pool_metrics
            .get_at(ord, format!("group_pool_metric:{}:token_difference_from_liquidations", group_pool_address  ))
            .unwrap_or(BigInt::zero()) ;  */
                 
              
            
               tables
                    .create_row("group_pool_metric_data_point", format!("{}_{}", group_pool_address, block_number )  ) 
                    .set("group_pool_address", Hex::decode( group_pool_address ).unwrap())
                    .set("block_number", &block_number )
                    .set("block_time", &block_time)
                    .set("total_principal_tokens_committed", &total_principal_committed )
                    .set("total_collateral_tokens_escrowed", &total_collateral_escrowed )
                    .set("total_collateral_tokens_withdrawn", &total_collateral_withdrawn )
                    .set("total_principal_tokens_withdrawn", &total_principal_tokens_withdrawn  )
                    .set("total_principal_tokens_borrowed", &total_principal_tokens_borrowed )
                    .set("total_principal_tokens_repaid", &total_principal_tokens_repaid  )
                    .set("total_interest_collected", &total_interest_collected )
                    .set("token_difference_from_liquidations",&fetched_token_amount_difference)
                    ;
            
                    
            
            let day_index = block_time.clone() / 86400;
            
                    
                tables
                    .create_row("group_pool_metric_data_point_daily", format!("{}_{}", group_pool_address, day_index )  ) 
                    .set("group_pool_address", Hex::decode( group_pool_address ).unwrap())
                     .set("block_number", &block_number )
                    .set("block_time", &block_time)
                    .set("total_principal_tokens_committed", &total_principal_committed )
                    .set("total_collateral_tokens_withdrawn", &total_collateral_withdrawn )
                    .set("total_collateral_tokens_escrowed", &total_collateral_escrowed )
                    .set("total_principal_tokens_withdrawn", &total_principal_tokens_withdrawn  )
                    .set("total_principal_tokens_borrowed", &total_principal_tokens_borrowed )
                    .set("total_principal_tokens_repaid", &total_principal_tokens_repaid  )
                    .set("total_interest_collected", &total_interest_collected ) 
                    .set("token_difference_from_liquidations",&fetched_token_amount_difference)
                    ;
            
                
            
            let week_index = block_time.clone() / 604800;
            
                      
                tables
                    .create_row("group_pool_metric_data_point_weekly", format!("{}_{}", group_pool_address, week_index )  ) 
                    .set("group_pool_address", Hex::decode( group_pool_address ).unwrap())
                    .set("block_number", &block_number )
                    .set("block_time", &block_time)
                    .set("total_principal_tokens_committed", &total_principal_committed )
                    .set("total_collateral_tokens_escrowed", &total_collateral_escrowed )
                    .set("total_collateral_tokens_withdrawn", &total_collateral_withdrawn )
                    .set("total_principal_tokens_withdrawn", &total_principal_tokens_withdrawn  )
                    .set("total_principal_tokens_borrowed", &total_principal_tokens_borrowed )
                    .set("total_principal_tokens_repaid", &total_principal_tokens_repaid  )
                    .set("total_interest_collected", &total_interest_collected )
                    .set("token_difference_from_liquidations",&fetched_token_amount_difference)
                    ;
                
             
         }
         
         
        
          
          


    // -- end group pool metrics 



    // -- start user metrics 

   // let mut user_metric_deltas_detected = HashSet::new();
         
     
    for user_metric_delta in deltas_lendergroup_user_metrics.deltas. iter(){
    
        
        let delta_root_identifier = substreams::key::segment_at(user_metric_delta.get_key(), 0);
        let ord = 0; // FOR NOW - CAN CAUSE ISSUES 
          

        //maybe this is breaking things ?
       if delta_root_identifier != "group_user_metric" {continue};
        
        let group_address = substreams::key::segment_at(user_metric_delta.get_key(), 1);
        let user_address = substreams::key::segment_at(user_metric_delta.get_key(), 2);
        let delta_prop_identifier = substreams::key::segment_at(user_metric_delta.get_key(), 3);
                
                
                
       // let block_number = BigInt::zero(); // FOR NOW 
       
        
      //  user_metric_deltas_detected.insert(format!("{}:{}",group_address,user_address));

        // if interaction count is 1, make a new row 

        if delta_prop_identifier == "interaction_count"{

            let interaction_count = &user_metric_delta.new_value ;

            if interaction_count == & BigInt::from(1) {
                tables
                .create_row("group_user_metric", format!("{}_{}", group_address, user_address )  ) 
                .set("group_pool_address", Hex::decode( group_address ).unwrap())
                .set("user_address", Hex::decode( user_address ).unwrap())
      
                .set("total_principal_tokens_committed", BigInt::zero() )
                .set("total_collateral_tokens_escrowed", BigInt::zero() )
                .set("total_principal_tokens_withdrawn", BigInt::zero() )
                .set("total_principal_tokens_borrowed", BigInt::zero() );
            }
    
            
        }
    
     

       
    }
  

    for user_metric_delta in deltas_lendergroup_user_metrics.deltas. iter(){
    
        
        let delta_root_identifier = substreams::key::segment_at(user_metric_delta.get_key(), 0);
        let ord = 0; // FOR NOW - CAN CAUSE ISSUES 
          

        //maybe this is breaking things ?
       if delta_root_identifier != "group_user_metric" {continue};
        
        let group_address = substreams::key::segment_at(user_metric_delta.get_key(), 1);
        let user_address = substreams::key::segment_at(user_metric_delta.get_key(), 2);
        let delta_prop_identifier = substreams::key::segment_at(user_metric_delta.get_key(), 3);
                
        let new_value = &user_metric_delta.new_value ;
                
       // let block_number = BigInt::zero(); // FOR NOW 
       
        
       match delta_prop_identifier  {
        "total_principal_tokens_committed" => {
            tables.update_row("group_user_metric", format!("{}_{}", group_address, user_address ))
                .set("total_principal_tokens_committed", new_value );
        },
        "total_collateral_tokens_escrowed" => {
            tables.update_row("group_user_metric", format!("{}_{}", group_address, user_address ))
                .set("total_collateral_tokens_escrowed", new_value );
        },
        "total_principal_tokens_withdrawn" => {
            tables.update_row("group_user_metric", format!("{}_{}", group_address, user_address ))
                .set("total_principal_tokens_withdrawn", new_value );
        },
        "total_principal_tokens_borrowed" => {
            tables.update_row("group_user_metric", format!("{}_{}", group_address, user_address ))
                .set("total_principal_tokens_borrowed", new_value );
        },  
        "total_principal_tokens_repaid" => {
            tables.update_row("group_user_metric", format!("{}_{}", group_address, user_address ))
                .set("total_principal_tokens_repaid", new_value );
        },  
        "total_interest_collected" => {
            tables.update_row("group_user_metric", format!("{}_{}", group_address, user_address ))
                .set("total_interest_collected", new_value );
        },
        
        
        // Add more cases as per your metric names
        _ => {}
    };
     

       
    }
        
    

    // -- end user metrics 


}



/*

    This creates a mapping that we use to help figure out which
    collateralmanager events we care abt 

*/
/*
#[substreams::handlers::store]
fn store_accepted_bids_data(
    events:  contract::Events, 
   
    bigint_set_store: StoreSetBigInt //for block time and block number 
) {

    let ord = 0; 
    
    events.lendergroup_borrower_accepted_funds.iter().for_each(|evt: &contract::LendergroupBorrowerAcceptedFunds| {
         
        bigint_set_store.set(ord, evt.bid_id.clone() , &BigInt::from(  1 ) );
 
    });
    

}*/



#[substreams::handlers::map]
fn map_collateralmanager_events(
    blk: eth::Block,
    //store_collateral_withdrawn: StoreGetInt64,
) -> Result<collateral_contract::Events, substreams::errors::Error> {
    let mut collateral_events = collateral_contract::Events::default();
    //map_factory_events(&blk, &mut events);
    //map_lendergroup_events(&blk, &store_lendergroup, &mut events);


    collateral_events.collateral_manager_collateral_withdrawn.append(&mut blk
        .receipts()
        .flat_map(|view| {
            view.receipt.logs.iter()
                .filter(|log| log.address == COLLATERAL_MANAGER_TRACKED_CONTRACT)
                .filter_map(|log| {
                    if let Some(event) = abi::collateral_manager::events::CollateralWithdrawn::match_and_decode(log) {
                        

                        substreams::log::info!("collateral withdrawn evt found ");
                        
                        
                        return Some(collateral_contract::CollateralmanagerCollateralWithdrawn {
                            evt_tx_hash: Hex(&view.transaction.hash).to_string(),
                            evt_index: log.block_index,
                            evt_block_time: blk.timestamp_seconds(),
                            evt_block_number: blk.number,

                            //why are these prefixed by u_ ??

                            bid_id: event.u_bid_id.clone().to_string(),
                            collateral_type: event.u_type.clone().to_string().parse().unwrap(), //coerce into a u32 ..
                            collateral_address: event.u_collateral_address.clone(),
                            amount: event.u_amount.clone().to_string(),
                            token_id: event.u_token_id.clone().to_string(),
                            recipient: event.u_recipient.clone(),

                            //group_contract: event.group_contract,
                        });
                    }

                    None
                })
        })
        .collect());
  
    
    Ok(collateral_events)
}
 




#[substreams::handlers::store]
fn store_bid_collateral_withdrawn_data_deltas(
    events:  collateral_contract::Events,    
    bigint_delta_store:  StoreAddBigInt //for block time and block number 
) {


     
    let ord = 0; // FOR NOW - CAN CAUSE ISSUES - GET FROM LOG AND STUFF INTO EVENT    
    

    
    events.collateral_manager_collateral_withdrawn.iter().for_each(|evt: &collateral_contract::CollateralmanagerCollateralWithdrawn| {
        

        let store_key: String = format!("collateral_amount_withdrawn:{}:{}", evt.bid_id,Hex(&evt.collateral_address).to_string());
        bigint_delta_store.add(ord,&store_key, BigInt::from_str(&evt.amount).unwrap_or(BigInt::zero()));

        substreams::log::info!(" Storing collateral amt withdrawn: {} {}",store_key, BigInt::from_str(&evt.amount).unwrap_or(BigInt::zero()) );
 
      // need to write a whole set of drivers to track   shares tokens !! 
      // need ERC20 abi also 
    });

}

#[substreams::handlers::store]
fn store_pool_collateral_withdrawn_data(
    bigint_delta_store: Deltas<DeltaBigInt> ,
    string_get_store: StoreGetString, //for block time and block number 

    output_store: StoreAddBigInt,
) {


     
    let ord = 0; // FOR NOW - CAN CAUSE ISSUES - GET FROM LOG AND STUFF INTO EVENT    





    /*  for each delta,it tells how much collateral was withdrawn for a bid 

    We have to look up the pool address  using the bid id with string_get_store 

    Then we have to store, in the output store, an addition 



    */
    for collateral_withdrawn_delta in bigint_delta_store.deltas.iter(){
             
                            
                //this splits on ":"
        let delta_root_identifier = substreams::key::segment_at(collateral_withdrawn_delta.get_key(), 0);

        if delta_root_identifier != "collateral_amount_withdrawn" {continue};

        let bid_id = substreams::key::segment_at(collateral_withdrawn_delta.get_key(), 1);
        let collateral_address = substreams::key::segment_at(collateral_withdrawn_delta.get_key(), 2); //ignore for now 
        
                
        //  let block_number = 0; // FOR NOW 
      //  let new_value = &pool_metric_delta.new_value ;

      let delta_value = collateral_withdrawn_delta.new_value.clone() - collateral_withdrawn_delta.old_value.clone();
       // let delta_value = &collateral_withdrawn_delta.delta_value; // ??? 


      

         let string_store_key = format!("bid_originated_from_pool:{}", bid_id);
         if let Some( group_pool_address ) = string_get_store.get_at(ord, string_store_key){

            let output_store_key = format!("total_collateral_amount_withdrawn:{}", group_pool_address);

            output_store.add(ord, &output_store_key, delta_value.clone() );


         }
                    

      }

     
}




 
 



#[substreams::handlers::store]
fn store_globals_from_events(
    events:  contract::Events, 
   
    bigint_set_store: StoreSetBigInt //for block time and block number 
) {


    let ord = 0; // FOR NOW - CAN CAUSE ISSUES - GET FROM LOG AND STUFF INTO EVENT    
    

    events.lendergroup_pool_initializeds.iter().for_each(|evt: &contract::LendergroupPoolInitialized| {
 

        bigint_set_store.set(ord,"latest_block_number", &BigInt::from( evt.evt_block_number ) );
        bigint_set_store.set(ord,"latest_block_time", &BigInt::from(  evt.evt_block_time ) );

    });
    
    events.lendergroup_lender_added_principals.iter().for_each(|evt: &contract::LendergroupLenderAddedPrincipal| {
        
       
        bigint_set_store.set(ord,"latest_block_number", &BigInt::from( evt.evt_block_number ) );
        bigint_set_store.set(ord,"latest_block_time", &BigInt::from(  evt.evt_block_time ) );

    });

    events.lendergroup_borrower_accepted_funds.iter().for_each(|evt: &contract::LendergroupBorrowerAcceptedFunds| {
        
        bigint_set_store.set(ord,"latest_block_number", &BigInt::from( evt.evt_block_number ) );
        bigint_set_store.set(ord,"latest_block_time", &BigInt::from(  evt.evt_block_time ) );


      
        //add total collateral ! 
        
        //  evt.collateral_amount
    });

    
    events.lendergroup_earnings_withdrawns.iter().for_each(|evt: &contract::LendergroupEarningsWithdrawn| {
     
        bigint_set_store.set(ord,"latest_block_number", &BigInt::from( evt.evt_block_number ) );
        bigint_set_store.set(ord,"latest_block_time", &BigInt::from(  evt.evt_block_time ) );

        //add total collateral ! 
    });

    
            
    events.lendergroup_loan_repaids.iter().for_each(|evt: &contract::LendergroupLoanRepaid| {
        
       

    });


    events.lendergroup_defaulted_loan_liquidateds.iter().for_each(|evt: &contract::LendergroupDefaultedLoanLiquidated| {
        bigint_set_store.set(ord,"latest_block_number", &BigInt::from( evt.evt_block_number ) );
        bigint_set_store.set(ord,"latest_block_time", &BigInt::from(  evt.evt_block_time ) );

    });


}



#[substreams::handlers::store]
fn store_bid_from_pool_data(
    events:  contract::Events, 
   
    string_set_store: StoreSetString //for block time and block number 
) {


    let ord = 0; // FOR NOW - CAN CAUSE ISSUES - GET FROM LOG AND STUFF INTO EVENT    
    
 
    events.lendergroup_borrower_accepted_funds.iter().for_each(|evt: &contract::LendergroupBorrowerAcceptedFunds| {
        
        let bid_id = &evt.bid_id;
        let group_pool_address = &evt.evt_address;

        string_set_store.set(ord, format!("bid_originated_from_pool:{}", bid_id ), group_pool_address );

      
    });
 

}

/*


The block stream encountered a substreams fatal error and will not retry:
 rpc error: code = InvalidArgument desc = step new irr: handler step new:
  execute modules: applying executor results "store_lendergroup_pool_metrics_deltas"
   on block 57615083: execute: store wasm call: block 57615083: module 
   "store_lendergroup_pool_metrics_deltas":
    general wasm execution failed: wasm execution 
    failed deterministically: call: module
     "store_lendergroup_pool_metrics_deltas": 
     invalid store operation "add_bigint", only valid for stores with updatePolicy
      == "add" and valueType == "bigint" (recovered by wazero) wasm stack trace:
       state.add_bigint(i64,i32,i32,i32,i32) ._ZN90_$LT$substreams..store..
       StoreAddBigInt$u20$as$u20$substreams..store..StoreAdd$LT$V$GT$$GT$3ad
       d17h658373da49566eb1E(i32,i32,i32) .store_lendergroup_pool_metrics_deltas
       (i32,i32)

*/


#[substreams::handlers::store]
fn store_lendergroup_user_metrics_deltas(
    events:  contract::Events, 
    bigint_add_store: StoreAddBigInt,
 
) {
    
    let ord = 0; // FOR NOW - CAN CAUSE ISSUES - GET FROM LOG AND STUFF INTO EVENT    
    

    
    events.lendergroup_lender_added_principals.iter().for_each(|evt: &contract::LendergroupLenderAddedPrincipal| {
        
        let user_store_key: String = format!("group_user_metric:{}:{}:interaction_count", evt.evt_address,Hex(&evt.lender).to_string());
        bigint_add_store.add(ord,&user_store_key, BigInt::from( 1 ));


        
        let user_store_key: String = format!("group_user_metric:{}:{}:total_principal_tokens_committed", evt.evt_address,Hex(&evt.lender).to_string());
        bigint_add_store.add(ord,&user_store_key, BigInt::from_str(&evt.amount).unwrap_or(BigInt::zero()));

      // need to write a whole set of drivers to track   shares tokens !! 
      // need ERC20 abi also 
    });

    events.lendergroup_borrower_accepted_funds.iter().for_each(|evt: &contract::LendergroupBorrowerAcceptedFunds| {
       
        let user_store_key: String = format!("group_user_metric:{}:{}:interaction_count", evt.evt_address,Hex(&evt.borrower).to_string());
        bigint_add_store.add(ord,&user_store_key, BigInt::from( 1 ));

        
          
        let user_store_key: String = format!("group_user_metric:{}:{}:total_principal_tokens_borrowed", evt.evt_address,Hex(&evt.borrower).to_string());
        bigint_add_store.add(ord,&user_store_key, BigInt::from_str(&evt.principal_amount).unwrap_or(BigInt::zero()));
        
        let user_store_key: String = format!("group_user_metric:{}:{}:total_collateral_tokens_escrowed", evt.evt_address,Hex(&evt.borrower).to_string());
        bigint_add_store.add(ord,&user_store_key, BigInt::from_str(&evt.collateral_amount).unwrap_or(BigInt::zero()));
 
    });

    
    events.lendergroup_earnings_withdrawns.iter().for_each(|evt: &contract::LendergroupEarningsWithdrawn| {
        
        let user_store_key: String = format!("group_user_metric:{}:{}:interaction_count", evt.evt_address,Hex(&evt.lender).to_string());
        bigint_add_store.add(ord,&user_store_key, BigInt::from( 1 ));

        
      
        let user_store_key: String = format!("group_user_metric:{}:{}:total_principal_tokens_withdrawn", evt.evt_address,Hex(&evt.lender).to_string());
        bigint_add_store.add(ord,&user_store_key, BigInt::from_str(&evt.principal_tokens_withdrawn).unwrap_or(BigInt::zero()));
 
    });

    
            
    events.lendergroup_loan_repaids.iter().for_each(|evt: &contract::LendergroupLoanRepaid| {

        let user_store_key: String = format!("group_user_metric:{}:{}:interaction_count", evt.evt_address,Hex(&evt.repayer).to_string());
        bigint_add_store.add(ord,&user_store_key, BigInt::from( 1 ));


        let user_store_key: String = format!("group_user_metric:{}:{}:total_principal_tokens_repaid", evt.evt_address,Hex(&evt.repayer).to_string());
        bigint_add_store.add(ord,&user_store_key, BigInt::from_str(&evt.principal_amount).unwrap_or(BigInt::zero()));
        
        let user_store_key: String = format!("group_user_metric:{}:{}:total_interest_collected", evt.evt_address,Hex(&evt.repayer).to_string());
        bigint_add_store.add(ord,&user_store_key, BigInt::from_str(&evt.interest_amount).unwrap_or(BigInt::zero()));
         
        
    });

   

    /* events.lendergroup_defaulted_loan_liquidateds.iter().for_each(|evt: &contract::LendergroupDefaultedLoanLiquidated| {
 
 
        let user_store_key: String = format!("group_user_metric:{}:{}:token_difference_from_liquidations", evt.evt_address,Hex(&evt.liquidator).to_string());
        bigint_add_store.add(ord,&user_store_key, BigInt::from_str(&evt.token_amount_difference).unwrap_or(BigInt::zero()));
         
        
    }); */
}

/*
#[substreams::handlers::store]
fn store_lendergroup_user_metrics(
     deltas_lendergroup_user_metrics: Deltas<DeltaBigInt>,
     store: StoreSetBigInt
    ) {
    
    
    let ord = 0; // FOR NOW - CAN CAUSE ISSUES - GET FROM LOG AND STUFF INTO EVENT    
    
      for user_metric_delta in deltas_lendergroup_user_metrics.deltas. iter(){
             
                    
                        //this splits on ":"
                let delta_root_identifier = substreams::key::segment_at(user_metric_delta.get_key(), 0);
            
                if delta_root_identifier != "group_user_metric" {continue};
                
                let group_address = substreams::key::segment_at(user_metric_delta.get_key(), 1);
                let user_address = substreams::key::segment_at(user_metric_delta.get_key(), 2);
                let delta_prop_identifier = substreams::key::segment_at(user_metric_delta.get_key(), 3);
                        
                        
                        
              //  let block_number = 0; // FOR NOW 
                let new_value = &user_metric_delta.new_value ;
                        
                
                //substreams::log::info();


                        
               match delta_prop_identifier {
                   
                   "interaction_count" => {
                       let store_key: String = format!("group_user_metric:{}:{}:interaction_count", group_address,user_address);
                       store.set(ord,&store_key,  new_value  );

                   }
                   
                   "total_principal_tokens_committed" => {
                    let store_key: String = format!("group_user_metric:{}:{}:total_principal_tokens_committed", group_address,user_address);
                    store.set(ord,&store_key,  new_value  );

                }
                


                   "total_collateral_tokens_escrowed" => {
                    let store_key: String = format!("group_user_metric:{}:{}:total_collateral_tokens_escrowed", group_address,user_address);
                    store.set(ord,&store_key,  new_value  );

                }
                
                     
                   "total_principal_tokens_withdrawn" => {
                       let store_key: String = format!("group_user_metric:{}:{}:total_principal_tokens_withdrawn", group_address,user_address);
                       store.set(ord,&store_key,  new_value  );
                   }
                   
                   "total_principal_tokens_borrowed"=> {
                       let store_key: String = format!("group_user_metric:{}:{}:total_principal_tokens_borrowed", group_address,user_address);
                       store.set(ord,&store_key,  new_value  );
                   }
                   
                      
                   "total_principal_tokens_repaid" => {
                       let store_key: String = format!("group_user_metric:{}:{}:total_principal_tokens_repaid", group_address,user_address);
                       store.set(ord,&store_key,  new_value  );
                   }
                   
                
                   
                   
                   _ => {} 
                   
               }
               
                        
                        
      }
    
    
   
}
*/


#[substreams::handlers::store]
fn store_lendergroup_pool_metrics_deltas(
    events:  contract::Events, 
    bigint_add_store: StoreAddBigInt,
 
) {
    
    let ord = 0; // FOR NOW - CAN CAUSE ISSUES - GET FROM LOG AND STUFF INTO EVENT    
    

    events.lendergroup_pool_initializeds.iter().for_each(|evt: &contract::LendergroupPoolInitialized| {
        
        
        let store_key: String = format!("group_pool_metric:{}:total_principal_tokens_committed", evt.evt_address);
        bigint_add_store.add(ord,&store_key, BigInt::zero() );

        let store_key: String = format!("group_pool_metric:{}:total_principal_tokens_borrowed", evt.evt_address);
        bigint_add_store.add(ord,&store_key, BigInt::zero() );

        let store_key: String = format!("group_pool_metric:{}:total_principal_tokens_withdrawn", evt.evt_address);
        bigint_add_store.add(ord,&store_key, BigInt::zero() );

        let store_key: String = format!("group_pool_metric:{}:total_principal_tokens_repaid", evt.evt_address);
        bigint_add_store.add(ord,&store_key, BigInt::zero() );

        let store_key: String = format!("group_pool_metric:{}:total_interest_collected", evt.evt_address);
        bigint_add_store.add(ord,&store_key, BigInt::zero() );


        let store_key: String = format!("group_pool_metric:{}:total_collateral_tokens_escrowed", evt.evt_address);
        bigint_add_store.add(ord,&store_key, BigInt::zero() );

        


    });
    
    events.lendergroup_lender_added_principals.iter().for_each(|evt: &contract::LendergroupLenderAddedPrincipal| {
        let group_store_key: String = format!("group_pool_metric:{}:total_principal_tokens_committed", evt.evt_address);
        bigint_add_store.add(ord,&group_store_key, BigInt::from_str(&evt.amount).unwrap_or(BigInt::zero()));
        
        
      // need to write a whole set of drivers to track   shares tokens !! 
      // need ERC20 abi also 
    });

    events.lendergroup_borrower_accepted_funds.iter().for_each(|evt: &contract::LendergroupBorrowerAcceptedFunds| {
        
        let group_store_key: String = format!("group_pool_metric:{}:total_principal_tokens_borrowed", evt.evt_address);
        bigint_add_store.add(ord,&group_store_key, BigInt::from_str(&evt.principal_amount).unwrap_or(BigInt::zero()));
        
        let group_store_key: String = format!("group_pool_metric:{}:total_collateral_tokens_escrowed", evt.evt_address);
        bigint_add_store.add(ord,&group_store_key, BigInt::from_str(&evt.collateral_amount).unwrap_or(BigInt::zero()));
        
      
    });

    
    events.lendergroup_earnings_withdrawns.iter().for_each(|evt: &contract::LendergroupEarningsWithdrawn| {
        let group_store_key: String = format!("group_pool_metric:{}:total_principal_tokens_withdrawn", evt.evt_address);
        bigint_add_store.add(ord,&group_store_key, BigInt::from_str(&evt.principal_tokens_withdrawn).unwrap_or(BigInt::zero()));
         
      
    
    });

    
            
    events.lendergroup_loan_repaids.iter().for_each(|evt: &contract::LendergroupLoanRepaid| {
        let group_store_key: String = format!("group_pool_metric:{}:total_principal_tokens_repaid", evt.evt_address);
        bigint_add_store.add(ord,&group_store_key, BigInt::from_str(&evt.principal_amount).unwrap_or(BigInt::zero()));

        let group_store_key: String = format!("group_pool_metric:{}:total_interest_collected", evt.evt_address);
        bigint_add_store.add(ord,&group_store_key, BigInt::from_str(&evt.interest_amount).unwrap_or(BigInt::zero()));
    
        
    });

    events.lendergroup_defaulted_loan_liquidateds.iter().for_each(|evt: &contract::LendergroupDefaultedLoanLiquidated| {

        let group_store_key: String = format!("group_pool_metric:{}:total_principal_tokens_repaid", evt.evt_address);
        bigint_add_store.add(ord,&group_store_key, BigInt::from_str(&evt.amount_due).unwrap_or(BigInt::zero()));

        //track token amt difference? 
    });



  /*  events.lendergroup_defaulted_loan_liquidateds.iter().for_each(|evt: &contract::LendergroupDefaultedLoanLiquidated| {
 
 
         
        let group_store_key: String = format!("group_pool_metric:{}:token_difference_from_liquidations", evt.evt_address);
        bigint_add_store.add(ord,&group_store_key, BigInt::from_str(&evt.token_amount_difference).unwrap_or(BigInt::zero()));
    
        
    }); */

}


//we do this so we can output the pool metric data points ! gives us longer term memory for these variables 
#[substreams::handlers::store]
fn store_lendergroup_pool_metrics(
     deltas_lendergroup_pool_metrics: Deltas<DeltaBigInt>,
     globals_store: StoreGetBigInt, 
     store: StoreSetBigInt,
     
    ) {
    
    
    let ord = 0; // FOR NOW - CAN CAUSE ISSUES - GET FROM LOG AND STUFF INTO EVENT    
    
      for pool_metric_delta in deltas_lendergroup_pool_metrics.deltas. iter(){
             
                    
                        //this splits on ":"
                let delta_root_identifier = substreams::key::segment_at(pool_metric_delta.get_key(), 0);
            
                if delta_root_identifier != "group_pool_metric" {continue};
                
                let group_address = substreams::key::segment_at(pool_metric_delta.get_key(), 1);
                let delta_prop_identifier = substreams::key::segment_at(pool_metric_delta.get_key(), 2);
                        
                        
                        
              //  let block_number = 0; // FOR NOW 
                let new_value = &pool_metric_delta.new_value ;
                        
                
                //substreams::log::info();
                
               let current_block_time = globals_store.get_at(ord, "latest_block_time").unwrap_or(BigInt::zero());

                    
                    
               let store_block_time_key: String = format!("group_pool_metric:{}:block_time", group_address);              
               store.set(ord,&store_block_time_key, &current_block_time  );
                        
               match delta_prop_identifier {
                   
                   "total_principal_tokens_committed" => {
                       let store_key: String = format!("group_pool_metric:{}:total_principal_tokens_committed", group_address);
                       store.set(ord,&store_key,  new_value  );
                      

                   }
                   
                   "total_collateral_tokens_escrowed" => {
                    let store_key: String = format!("group_pool_metric:{}:total_collateral_tokens_escrowed", group_address);
                    store.set(ord,&store_key,  new_value  );

                    }
                
                     
                   "total_principal_tokens_withdrawn" => {
                       let store_key: String = format!("group_pool_metric:{}:total_principal_tokens_withdrawn", group_address);
                       store.set(ord,&store_key,  new_value  );
                   }
                   
                   "total_principal_tokens_borrowed"=> {
                       let store_key: String = format!("group_pool_metric:{}:total_principal_tokens_borrowed", group_address);
                       store.set(ord,&store_key,  new_value  );
                   }
                   
                      
                   "total_principal_tokens_repaid" => {
                       let store_key: String = format!("group_pool_metric:{}:total_principal_tokens_repaid", group_address);
                       store.set(ord,&store_key,  new_value  );
                   }
                   
                  "total_interest_collected" => {
                       let store_key: String = format!("group_pool_metric:{}:total_interest_collected", group_address);
                       store.set(ord,&store_key,  new_value  );
                   }
                   
                   
                   _ => {} 
                   
               }
               
                        
                        
      }
    
    
   
}


#[substreams::handlers::map]
fn map_events(
    blk: eth::Block,
    store_lendergroup: StoreGetInt64,
) -> Result<contract::Events, substreams::errors::Error> {
    let mut events = contract::Events::default();
    map_factory_events(&blk, &mut events);
    map_lendergroup_events(&blk, &store_lendergroup, &mut events);
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
    graph_factory_out(&events, &mut tables);
    graph_lendergroup_out(
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
        
        
        
  // Pool Day/Hour data:  //from uniswap repo 
   /* db::pool_windows_create(&mut tables, &tx_count_deltas);
    db::pool_windows_update(
        &mut tables,
        timestamp,
        &tx_count_deltas,
        &swaps_volume_deltas,
        &events,
        &pool_sqrt_price_store,
        &pool_liquidities_store_deltas,
        &price_deltas,
        &store_prices,
        &derived_tvl_deltas,
        &min_windows_deltas,
        &max_windows_deltas,
    );*/

    
        
                
    Ok(tables.to_entity_changes())
    }