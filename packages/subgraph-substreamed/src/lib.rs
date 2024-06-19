mod abi;
mod pb;
mod rpc;
use hex_literal::hex;
use pb::contract::v1 as contract;
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

const FACTORY_TRACKED_CONTRACT: [u8; 20] = hex!("e00384587dc733d1e201e1eaa5583645d351c01c");

fn map_factory_events(blk: &eth::Block, events: &mut contract::Events) {
    events.factory_admin_changeds.append(&mut blk
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
}

fn is_declared_dds_address(addr: &Vec<u8>, ordinal: u64, dds_store: &store::StoreGetInt64) -> bool {
    //    substreams::log::info!("Checking if address {} is declared dds address", Hex(addr).to_string());
    if dds_store.get_at(ordinal, Hex(addr).to_string()).is_some() {
        return true;
    }
    return false;
}

fn map_lendergroup_events(
    blk: &eth::Block,
    dds_store: &store::StoreGetInt64,
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
                .filter(|log| is_declared_dds_address(&log.address, log.ordinal, dds_store))
                .filter_map(|log| {
                    if let Some(event) = abi::lendergroup_contract::events::PoolInitialized::match_and_decode(log) {
                        
                        
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
                            twap_interval: event.twap_interval.to_u64(),
                            uniswap_pool_fee: event.uniswap_pool_fee.to_u64(),

                            teller_v2_address: fetched_rpc_data.teller_v2_address.to_fixed_bytes().to_vec(),
                            uniswap_v3_pool_address: fetched_rpc_data.uniswap_v3_pool_address.to_fixed_bytes().to_vec(),
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
    events.factory_admin_changeds.iter().for_each(|evt| {
        tables
            .create_row("factory_admin_changed", format!("{}-{}", evt.evt_tx_hash, evt.evt_index))
            .set("evt_tx_hash", evt.evt_tx_hash.clone().into_bytes())
            .set("evt_index", BigInt::from( evt.evt_index)  )
            .set("evt_block_time", BigInt::from ( evt.evt_block_time )) 
            .set("evt_block_number", BigInt::from( evt.evt_block_number) )
            .set("new_admin", Hex(&evt.new_admin).to_string().into_bytes())
            .set("previous_admin", Hex(&evt.previous_admin).to_string().into_bytes() );
    });
    events.factory_beacon_upgradeds.iter().for_each(|evt| {
        tables
            .create_row("factory_beacon_upgraded", format!("{}-{}", evt.evt_tx_hash, evt.evt_index))
            .set("evt_tx_hash", evt.evt_tx_hash.clone().into_bytes())
            .set("evt_index", BigInt::from(evt.evt_index))
            .set("evt_block_time", BigInt::from( evt.evt_block_time ))
            .set("evt_block_number", BigInt::from( evt.evt_block_number ))
            .set("beacon", Hex(&evt.beacon).to_string().into_bytes());
    });
    events.factory_deployed_lender_group_contracts.iter().for_each(|evt| {
        tables
            .create_row("factory_deployed_lender_group_contract", format!("{}-{}", evt.evt_tx_hash, evt.evt_index))
            .set("evt_tx_hash", evt.evt_tx_hash.clone().into_bytes())
            .set("evt_index", BigInt::from( evt.evt_index ))
            .set("evt_block_time", BigInt::from(evt.evt_block_time))
            .set("evt_block_number", BigInt::from(evt.evt_block_number))
            .set("group_contract", Hex(&evt.group_contract).to_string().into_bytes());
    });
    events.factory_upgradeds.iter().for_each(|evt| {
        tables
            .create_row("factory_upgraded", format!("{}-{}", evt.evt_tx_hash, evt.evt_index))
            .set("evt_tx_hash", evt.evt_tx_hash.clone().into_bytes())
            .set("evt_index", BigInt::from(evt.evt_index))
            .set("evt_block_time", BigInt::from(evt.evt_block_time))
            .set("evt_block_number", BigInt::from(evt.evt_block_number))
            .set("implementation", Hex(&evt.implementation).to_string().into_bytes());
    });
}


//make sure these match schema.graphql ! 
fn graph_lendergroup_out(
    events: &contract::Events,
     tables: &mut EntityChangesTables,
     deltas_lendergroup_pool_metrics: &Deltas<DeltaBigInt>,
     store_get_lendergroup_pool_metrics: &StoreGetBigInt, 
    
    ) {
    // Loop over all the abis events to create table changes
    events.lendergroup_borrower_accepted_funds.iter().for_each(|evt| {
        tables
            .create_row("group_borrower_accepted_funds", format!("{}-{}", evt.evt_tx_hash, evt.evt_index))
            .set("evt_tx_hash", evt.evt_tx_hash.clone().into_bytes())  //maybe do hex to string first ? 
            .set("evt_index", BigInt::from(evt.evt_index))
            .set("evt_block_time", BigInt::from(evt.evt_block_time))
            .set("evt_block_number", BigInt::from(evt.evt_block_number))
            .set("group_pool_address", Hex(&evt.evt_address).to_string().into_bytes() )
            .set("bid_id", BigDecimal::from_str(&evt.bid_id).unwrap())
            .set("borrower", Hex(&evt.borrower).to_string())
            .set("collateral_amount", BigDecimal::from_str(&evt.collateral_amount).unwrap())
            .set("interest_rate", evt.interest_rate)
            .set("loan_duration", evt.loan_duration)
            .set("principal_amount", BigDecimal::from_str(&evt.principal_amount).unwrap());
    });
    events.lendergroup_defaulted_loan_liquidateds.iter().for_each(|evt| {
        tables
            .create_row("group_defaulted_loan_liquidated", format!("{}-{}", evt.evt_tx_hash, evt.evt_index))
            .set("evt_tx_hash", evt.evt_tx_hash.clone().into_bytes())
            .set("evt_index", BigInt::from(evt.evt_index))
            .set("evt_block_time", BigInt::from(evt.evt_block_time))
            .set("evt_block_number", BigInt::from(evt.evt_block_number))
            .set("group_pool_address", Hex(&evt.evt_address).to_string().into_bytes() )
            .set("amount_due", BigDecimal::from_str(&evt.amount_due).unwrap())
            .set("bid_id", BigDecimal::from_str(&evt.bid_id).unwrap())
            .set("liquidator", Hex(&evt.liquidator).to_string().into_bytes())
            .set("token_amount_difference", BigDecimal::from_str(&evt.token_amount_difference).unwrap());
    });
    events.lendergroup_earnings_withdrawns.iter().for_each(|evt| {
        tables
            .create_row("group_earnings_withdrawn", format!("{}-{}", evt.evt_tx_hash, evt.evt_index))
            .set("evt_tx_hash", evt.evt_tx_hash.clone().into_bytes())
            .set("evt_index", BigInt::from(evt.evt_index))
            .set("evt_block_time", BigInt::from(evt.evt_block_time))
            .set("evt_block_number", BigInt::from(evt.evt_block_number))
            .set("group_pool_address", Hex(&evt.evt_address).to_string().into_bytes() )
            .set("amount_pool_shares_tokens", BigDecimal::from_str(&evt.amount_pool_shares_tokens).unwrap())
            .set("lender", Hex(&evt.lender).to_string().into_bytes())
            .set("principal_tokens_withdrawn", BigDecimal::from_str(&evt.principal_tokens_withdrawn).unwrap())
            .set("recipient", Hex(&evt.recipient).to_string().into_bytes());
    });
    events.lendergroup_initializeds.iter().for_each(|evt| {
        tables
            .create_row("group_initialized", format!("{}-{}", evt.evt_tx_hash, evt.evt_index))
            .set("evt_tx_hash", evt.evt_tx_hash.clone().into_bytes())
            .set("evt_index", BigInt::from(evt.evt_index))
            .set("evt_block_time", BigInt::from(evt.evt_block_time))
            .set("evt_block_number", BigInt::from(evt.evt_block_number))
            .set("group_pool_address", Hex(&evt.evt_address).to_string().into_bytes() )
            .set("version", evt.version);
    });
    events.lendergroup_lender_added_principals.iter().for_each(|evt| {
        tables
            .create_row("group_lender_added_principal", format!("{}-{}", evt.evt_tx_hash, evt.evt_index))
            .set("evt_tx_hash", evt.evt_tx_hash.clone().into_bytes())
            .set("evt_index", BigInt::from(evt.evt_index))
            .set("evt_block_time", BigInt::from(evt.evt_block_time))
            .set("evt_block_number", BigInt::from(evt.evt_block_number))
            .set("group_pool_address", Hex(&evt.evt_address).to_string().into_bytes() )
            .set("amount", BigDecimal::from_str(&evt.amount).unwrap())
            .set("lender", Hex(&evt.lender).to_string().into_bytes())
            .set("shares_amount", BigDecimal::from_str(&evt.shares_amount).unwrap())
            .set("shares_recipient", Hex(&evt.shares_recipient).to_string().into_bytes());
    });
    events.lendergroup_loan_repaids.iter().for_each(|evt| {
        tables
            .create_row("group_loan_repaid", format!("{}-{}", evt.evt_tx_hash, evt.evt_index))
            .set("evt_tx_hash", evt.evt_tx_hash.clone().into_bytes())
            .set("evt_index", BigInt::from(evt.evt_index))
            .set("evt_block_time", BigInt::from(evt.evt_block_time))
            .set("evt_block_number", BigInt::from(evt.evt_block_number))
            .set("group_pool_address", Hex(&evt.evt_address).to_string().into_bytes() )
            .set("bid_id", BigDecimal::from_str(&evt.bid_id).unwrap())
            .set("interest_amount", BigDecimal::from_str(&evt.interest_amount).unwrap())
            .set("principal_amount", BigDecimal::from_str(&evt.principal_amount).unwrap())
            .set("repayer", Hex(&evt.repayer).to_string().into_bytes())
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
            .set("group_pool_address", Hex(&evt.evt_address).to_string().into_bytes() )
            .set("new_owner", Hex(&evt.new_owner).to_string().into_bytes())
            .set("previous_owner", Hex(&evt.previous_owner).to_string().into_bytes());
    });
    events.lendergroup_pauseds.iter().for_each(|evt| {
        tables
            .create_row("group_paused", format!("{}-{}", evt.evt_tx_hash, evt.evt_index))
            .set("evt_tx_hash", evt.evt_tx_hash.clone().into_bytes())
            .set("evt_index", BigInt::from(evt.evt_index))
            .set("evt_block_time", BigInt::from(evt.evt_block_time))
            .set("evt_block_number", BigInt::from(evt.evt_block_number))
            .set("group_pool_address", Hex(&evt.evt_address).to_string().into_bytes() )
            .set("account", Hex(&evt.account).to_string().into_bytes());
    });
    events.lendergroup_pool_initializeds.iter().for_each(|evt| {
        tables
            .create_row("group_pool_initialized", format!("{}-{}", evt.evt_tx_hash, evt.evt_index))
            .set("evt_tx_hash", evt.evt_tx_hash.clone().into_bytes())
            .set("evt_index", BigInt::from(evt.evt_index))
            .set("evt_block_time", BigInt::from(evt.evt_block_time))
            .set("evt_block_number", BigInt::from(evt.evt_block_number))
            .set("group_pool_address", Hex(&evt.evt_address).to_string().into_bytes() )
            .set("collateral_token_address", Hex(&evt.collateral_token_address).to_string().into_bytes())
            .set("interest_rate_lower_bound", evt.interest_rate_lower_bound)
            .set("interest_rate_upper_bound", evt.interest_rate_upper_bound)
            .set("liquidity_threshold_percent", evt.liquidity_threshold_percent)
            .set("loan_to_value_percent", evt.loan_to_value_percent)
            .set("market_id", BigInt::from_str(&evt.market_id).unwrap())
            .set("max_loan_duration", evt.max_loan_duration)
            .set("pool_shares_token", Hex(&evt.pool_shares_token).to_string().into_bytes())
            .set("principal_token_address", Hex(&evt.principal_token_address).to_string().into_bytes())
            .set("twap_interval", evt.twap_interval)
            .set("uniswap_pool_fee", evt.uniswap_pool_fee);




             
            let lender_group_contract_address = Hex(&evt.evt_address).to_string();
    /*
            let fetched_rpc_data = rpc::fetch_lender_group_pool_initialization_data_from_rpc(
                &lender_group_contract_address
                 ).unwrap();
     */
            
           
         let uniswap_v3_pool_address = Hex(&evt.uniswap_v3_pool_address).to_string();
          let teller_v2_address = Hex(&evt.teller_v2_address).to_string();
           let smart_commitment_forwarder_address = Hex(&evt.smart_commitment_forwarder_address).to_string();
       
     
    
       //create group pool metric 
       tables
            .create_row("group_pool_metric", format!("{}", evt.evt_address )  ) 
           
            .set("group_pool_address", Hex::decode(&evt.evt_address).unwrap() )
            .set("principal_token_address", Hex(&evt.principal_token_address).to_string().into_bytes() )
            .set("collateral_token_address", Hex(&evt.collateral_token_address).to_string().into_bytes() )
            .set("shares_token_address", Hex(&evt.pool_shares_token).to_string().into_bytes() )
            .set("uniswap_v3_pool_address", Hex(&uniswap_v3_pool_address).to_string().into_bytes() )
            .set("teller_v2_address", Hex(&teller_v2_address).to_string().into_bytes() )
            .set("smart_commitment_forwarder_address", Hex(&smart_commitment_forwarder_address).to_string().into_bytes() )
            .set("market_id", BigInt::from_str(&evt.market_id).unwrap() )
            .set("uniswap_pool_fee", evt.uniswap_pool_fee)
            .set("max_loan_duration", evt.max_loan_duration)
            .set("twap_interval", evt.twap_interval)
            .set("interest_rate_upper_bound", evt.interest_rate_upper_bound)
            .set("interest_rate_lower_bound", evt.interest_rate_lower_bound)
            .set("liquidity_threshold_percent", evt.liquidity_threshold_percent)
            .set("collateral_ratio", evt.loan_to_value_percent)  //rename me 
 
            .set("total_principal_tokens_committed",  BigInt::zero()) 
            .set("total_principal_tokens_withdrawn",  BigInt::zero()) 
            .set("total_principal_tokens_lended",  BigInt::zero()) 
            .set("total_principal_tokens_repaid",  BigInt::zero()) 
            .set("total_interest_collected",  BigInt::zero()) 
            .set("token_difference_from_liquidations",  BigInt::zero())  
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
            .set("group_pool_address", Hex(&evt.evt_address).to_string().into_bytes() )
            .set("account", Hex(&evt.account).to_string().into_bytes());
    });





    
     // -------------
    
    
    



        // read the data from the table   group_pool_metrics 


        //create a new row for the table "group_pool_metrics_data_points" based on that 
        
     //   let group_address = Address::from_slice(  & Hex::decode(&evt.evt_address).unwrap() )    ; //evt.evt_address.clone();
        
            
         let mut  pool_metric_deltas_detected = HashSet::new();
         
     
         for pool_metric_delta in deltas_lendergroup_pool_metrics.deltas. iter(){
             
                    
                        //this splits on ":"
                let delta_root_identifier = substreams::key::segment_at(pool_metric_delta.get_key(), 0);


                //maybe this is breaking things ?
               if delta_root_identifier != "group_pool_metric" {continue};
                
                let group_address = substreams::key::segment_at(pool_metric_delta.get_key(), 1);
                let delta_prop_identifier = substreams::key::segment_at(pool_metric_delta.get_key(), 2);
                        
                        
                        
                let block_number = BigInt::zero(); // FOR NOW 
                let new_value = &pool_metric_delta.new_value ;
                        
                        
                pool_metric_deltas_detected.insert(group_address);
                        
             
                 match delta_prop_identifier  {
                    "total_principal_tokens_committed" => {
                        tables.update_row("group_pool_metric", &group_address)
                            .set("total_principal_tokens_committed", new_value );
                    },
                    "total_principal_tokens_withdrawn" => {
                        tables.update_row("group_pool_metric", &group_address)
                            .set("total_principal_tokens_withdrawn", new_value );
                    },
                    // Add more cases as per your metric names
                    _ => {}
                };
                             
                                     
                             
        // Create row in group_pool_metrics_data_point table
          
                                      
         }
         
        
         
         //need to use a non-delta store!?
         for group_pool_address in pool_metric_deltas_detected.iter() {
             
                
            //get the data from store_get_lendergroup_pool_metrics
               
               
            let ord = 0; // FOR NOW - CAN CAUSE ISSUES 
               
            let block_number = BigInt::zero(); // FOR NOW - get from store !?  
            let block_time = BigInt::zero();  // FOR NOW - get from store !?  
               
               
               //turn this into an enum !?
            let total_principal_committed = store_get_lendergroup_pool_metrics
            .get_at(ord, format!("group_pool_metric:{}:total_principal_tokens_committed", group_pool_address  ))
            .unwrap_or(BigInt::zero()) ;
                
            let total_principal_tokens_withdrawn = store_get_lendergroup_pool_metrics
            .get_at(ord, format!("group_pool_metric:{}:total_principal_tokens_withdrawn", group_pool_address  ))
            .unwrap_or(BigInt::zero()) ;
                
            let total_principal_tokens_lended = store_get_lendergroup_pool_metrics
            .get_at(ord, format!("group_pool_metric:{}:total_principal_tokens_lended", group_pool_address  ))
            .unwrap_or(BigInt::zero()) ;
                
            let total_principal_tokens_repaid = store_get_lendergroup_pool_metrics
            .get_at(ord, format!("group_pool_metric:{}:total_principal_tokens_repaid", group_pool_address  ))
            .unwrap_or(BigInt::zero()) ;
                
            let total_interest_collected = store_get_lendergroup_pool_metrics
            .get_at(ord, format!("group_pool_metric:{}:total_interest_collected", group_pool_address  ))
            .unwrap_or(BigInt::zero()) ;
                 
              
            
               tables
                    .create_row("group_pool_metric_data_point", format!("{}_{}", group_pool_address, block_number )  ) 
                    .set("group_pool_address", Hex::decode( group_pool_address ).unwrap())
                    .set("block_number", block_number)
                    .set("block_time", block_time)
                    .set("total_principal_tokens_committed", total_principal_committed )
                    .set("total_principal_tokens_withdrawn", total_principal_tokens_withdrawn  )
                    .set("total_principal_tokens_lended", total_principal_tokens_lended )
                    .set("total_principal_tokens_repaid", total_principal_tokens_repaid  )
                    .set("total_interest_collected", total_interest_collected );
                
             
         }
        



}
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
                store.set(log.ordinal, Hex(event.group_contract).to_string(), &1);
            }
        }
    }
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
fn store_lendergroup_pool_metrics_deltas(events:  contract::Events, store: StoreAddBigInt) {
    
    
    let ord = 0; // FOR NOW - CAN CAUSE ISSUES - GET FROM LOG AND STUFF INTO EVENT    
    

    events.lendergroup_pool_initializeds.iter().for_each(|evt: &contract::LendergroupPoolInitialized| {

        let store_key: String = format!("group_pool_metric:{}:total_principal_tokens_committed", evt.evt_address);
        store.add(ord,&store_key, BigInt::zero() );

        let store_key: String = format!("group_pool_metric:{}:total_principal_tokens_lended", evt.evt_address);
        store.add(ord,&store_key, BigInt::zero() );

        let store_key: String = format!("group_pool_metric:{}:total_principal_tokens_withdrawn", evt.evt_address);
        store.add(ord,&store_key, BigInt::zero() );

        let store_key: String = format!("group_pool_metric:{}:total_principal_tokens_repaid", evt.evt_address);
        store.add(ord,&store_key, BigInt::zero() );

        let store_key: String = format!("group_pool_metric:{}:total_interest_collected", evt.evt_address);
        store.add(ord,&store_key, BigInt::zero() );

    });
    
    events.lendergroup_lender_added_principals.iter().for_each(|evt: &contract::LendergroupLenderAddedPrincipal| {
        let store_key: String = format!("group_pool_metric:{}:total_principal_tokens_committed", evt.evt_address);
        store.add(ord,&store_key, BigInt::from_str(&evt.amount).unwrap_or(BigInt::zero()));
    });

    events.lendergroup_borrower_accepted_funds.iter().for_each(|evt: &contract::LendergroupBorrowerAcceptedFunds| {
        
        let store_key: String = format!("group_pool_metric:{}:total_principal_tokens_lended", evt.evt_address);
        store.add(ord,&store_key, BigInt::from_str(&evt.principal_amount).unwrap_or(BigInt::zero()));
        
        
       
        //add total collateral ! 
        
        //  evt.collateral_amount
    });

    
    events.lendergroup_earnings_withdrawns.iter().for_each(|evt: &contract::LendergroupEarningsWithdrawn| {
        let store_key: String = format!("group_pool_metric:{}:total_principal_tokens_withdrawn", evt.evt_address);
        store.add(ord,&store_key, BigInt::from_str(&evt.principal_tokens_withdrawn).unwrap_or(BigInt::zero()));
         
        
        //add total collateral ! 
    });

    
            
    events.lendergroup_loan_repaids.iter().for_each(|evt: &contract::LendergroupLoanRepaid| {
        let store_key_repaid: String = format!("group_pool_metric:{}:total_principal_tokens_repaid", evt.evt_address);
        let store_key_interest: String = format!("group_pool_metric:{}:total_interest_collected", evt.evt_address);
        store.add(ord,&store_key_repaid, BigInt::from_str(&evt.principal_amount).unwrap_or(BigInt::zero()));
        store.add(ord,&store_key_interest, BigInt::from_str(&evt.interest_amount).unwrap_or(BigInt::zero()));
    });
}



#[substreams::handlers::store]
fn store_lendergroup_pool_metrics(
     deltas_lendergroup_pool_metrics: Deltas<DeltaBigInt>,
     store: StoreSetBigInt
    ) {
    
    
    let ord = 0; // FOR NOW - CAN CAUSE ISSUES - GET FROM LOG AND STUFF INTO EVENT    
    
      for pool_metric_delta in deltas_lendergroup_pool_metrics.deltas. iter(){
             
                    
                        //this splits on ":"
                let delta_root_identifier = substreams::key::segment_at(pool_metric_delta.get_key(), 0);
            
                if delta_root_identifier != "group_pool_metric" {continue};
                
                let group_address = substreams::key::segment_at(pool_metric_delta.get_key(), 1);
                let delta_prop_identifier = substreams::key::segment_at(pool_metric_delta.get_key(), 2);
                        
                        
                        
                let block_number = 0; // FOR NOW 
                let new_value = &pool_metric_delta.new_value ;
                        
                
                //substreams::log::info();
                        
               match delta_prop_identifier {
                   
                   "total_principal_tokens_committed" => {
                       let store_key: String = format!("group_pool_metric:{}:total_principal_tokens_committed", group_address);
                       store.set(ord,&store_key,  new_value  );
                   }
                   
                     
                   "total_principal_tokens_withdrawn" => {
                       let store_key: String = format!("group_pool_metric:{}:total_principal_tokens_withdrawn", group_address);
                       store.set(ord,&store_key,  new_value  );
                   }
                   
                   "total_principal_tokens_lended"=> {
                       let store_key: String = format!("group_pool_metric:{}:total_principal_tokens_lended", group_address);
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


    deltas_lendergroup_pool_metrics: Deltas<DeltaBigInt>,
    store_get_big_int: StoreGetBigInt, 


) -> Result<EntityChanges, substreams::errors::Error> {
    // Initialize Database Changes container
    let mut tables = EntityChangesTables::new();
    graph_factory_out(&events, &mut tables);
    graph_lendergroup_out(&events, &mut tables, &deltas_lendergroup_pool_metrics, &store_get_big_int);
    Ok(tables.to_entity_changes())
}
