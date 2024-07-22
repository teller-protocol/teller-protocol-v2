mod abi;
mod pb;
mod rpc;
use hex_literal::hex;
use pb::contract::v1 as contract;
use substreams::Hex;
use substreams_database_change::pb::database::DatabaseChanges;
use substreams_database_change::tables::Tables as DatabaseChangeTables;
use substreams_entity_change::pb::entity::EntityChanges;
use substreams_entity_change::tables::Tables as EntityChangesTables;
use substreams_ethereum::pb::eth::v2 as eth;
use substreams_ethereum::Event;
use ethabi::{ethereum_types::H160, Address};

#[allow(unused_imports)]
use num_traits::cast::ToPrimitive;
use std::str::FromStr;
use substreams::scalar::{BigDecimal,BigInt};

substreams_ethereum::init!();

const TELLERV2_TRACKED_CONTRACT: [u8; 20] = hex!("00182fdb0b880ee24d428e3cc39383717677c37e");

fn map_tellerv2_events(blk: &eth::Block, events: &mut contract::Events) {
    events.tellerv2_accepted_bids.append(&mut blk
        .receipts()
        .flat_map(|view| {
            view.receipt.logs.iter()
                .filter(|log| log.address == TELLERV2_TRACKED_CONTRACT)
                .filter_map(|log| {
                    if let Some(event) = abi::tellerv2_contract::events::AcceptedBid::match_and_decode(log) {
                        
                        
           
            
            
            return Some(contract::Tellerv2AcceptedBid {




                            evt_tx_hash: Hex(&view.transaction.hash).to_string(),
                            evt_index: log.block_index,
                            evt_block_time: Some(blk.timestamp().to_owned()),
                            evt_block_number: blk.number,
                            bid_id: event.bid_id.to_string(),
                            lender: event.lender,
                        });
                    }

                    None
                })
        })
        .collect());
    
    events.tellerv2_cancelled_bids.append(&mut blk
        .receipts()
        .flat_map(|view| {
            view.receipt.logs.iter()
                .filter(|log| log.address == TELLERV2_TRACKED_CONTRACT)
                .filter_map(|log| {
                    if let Some(event) = abi::tellerv2_contract::events::CancelledBid::match_and_decode(log) {
                        return Some(contract::Tellerv2CancelledBid {
                            evt_tx_hash: Hex(&view.transaction.hash).to_string(),
                            evt_index: log.block_index,
                            evt_block_time: Some(blk.timestamp().to_owned()),
                            evt_block_number: blk.number,
                            bid_id: event.bid_id.to_string(),
                        });
                    }

                    None
                })
        })
        .collect());
    events.tellerv2_fee_paids.append(&mut blk
        .receipts()
        .flat_map(|view| {
            view.receipt.logs.iter()
                .filter(|log| log.address == TELLERV2_TRACKED_CONTRACT)
                .filter_map(|log| {
                    if let Some(event) = abi::tellerv2_contract::events::FeePaid::match_and_decode(log) {
                        return Some(contract::Tellerv2FeePaid {
                            evt_tx_hash: Hex(&view.transaction.hash).to_string(),
                            evt_index: log.block_index,
                            evt_block_time: Some(blk.timestamp().to_owned()),
                            evt_block_number: blk.number,
                            amount: event.amount.to_string(),
                            bid_id: event.bid_id.to_string(),
                            fee_type: Hex(event.fee_type.hash).to_string(),  // ???
                        });
                    }

                    None
                })
        })
        .collect());
    events.tellerv2_initializeds.append(&mut blk
        .receipts()
        .flat_map(|view| {
            view.receipt.logs.iter()
                .filter(|log| log.address == TELLERV2_TRACKED_CONTRACT)
                .filter_map(|log| {
                    if let Some(event) = abi::tellerv2_contract::events::Initialized::match_and_decode(log) {
                        return Some(contract::Tellerv2Initialized {
                            evt_tx_hash: Hex(&view.transaction.hash).to_string(),
                            evt_index: log.block_index,
                            evt_block_time: Some(blk.timestamp().to_owned()),
                            evt_block_number: blk.number,
                            version: event.version.to_u64(),
                        });
                    }

                    None
                })
        })
        .collect());
    events.tellerv2_loan_liquidateds.append(&mut blk
        .receipts()
        .flat_map(|view| {
            view.receipt.logs.iter()
                .filter(|log| log.address == TELLERV2_TRACKED_CONTRACT)
                .filter_map(|log| {
                    if let Some(event) = abi::tellerv2_contract::events::LoanLiquidated::match_and_decode(log) {
                        return Some(contract::Tellerv2LoanLiquidated {
                            evt_tx_hash: Hex(&view.transaction.hash).to_string(),
                            evt_index: log.block_index,
                            evt_block_time: Some(blk.timestamp().to_owned()),
                            evt_block_number: blk.number,
                            bid_id: event.bid_id.to_string(),
                            liquidator: event.liquidator,
                        });
                    }

                    None
                })
        })
        .collect());
    events.tellerv2_loan_repaids.append(&mut blk
        .receipts()
        .flat_map(|view| {
            view.receipt.logs.iter()
                .filter(|log| log.address == TELLERV2_TRACKED_CONTRACT)
                .filter_map(|log| {
                    if let Some(event) = abi::tellerv2_contract::events::LoanRepaid::match_and_decode(log) {
                        return Some(contract::Tellerv2LoanRepaid {
                            evt_tx_hash: Hex(&view.transaction.hash).to_string(),
                            evt_index: log.block_index,
                            evt_block_time: Some(blk.timestamp().to_owned()),
                            evt_block_number: blk.number,
                            bid_id: event.bid_id.to_string(),
                        });
                    }

                    None
                })
        })
        .collect());
    events.tellerv2_loan_repayments.append(&mut blk
        .receipts()
        .flat_map(|view| {
            view.receipt.logs.iter()
                .filter(|log| log.address == TELLERV2_TRACKED_CONTRACT)
                .filter_map(|log| {
                    if let Some(event) = abi::tellerv2_contract::events::LoanRepayment::match_and_decode(log) {
                        return Some(contract::Tellerv2LoanRepayment {
                            evt_tx_hash: Hex(&view.transaction.hash).to_string(),
                            evt_index: log.block_index,
                            evt_block_time: Some(blk.timestamp().to_owned()),
                            evt_block_number: blk.number,
                            bid_id: event.bid_id.to_string(),
                        });
                    }

                    None
                })
        })
        .collect());
    events.tellerv2_market_forwarder_approveds.append(&mut blk
        .receipts()
        .flat_map(|view| {
            view.receipt.logs.iter()
                .filter(|log| log.address == TELLERV2_TRACKED_CONTRACT)
                .filter_map(|log| {
                    if let Some(event) = abi::tellerv2_contract::events::MarketForwarderApproved::match_and_decode(log) {
                        return Some(contract::Tellerv2MarketForwarderApproved {
                            evt_tx_hash: Hex(&view.transaction.hash).to_string(),
                            evt_index: log.block_index,
                            evt_block_time: Some(blk.timestamp().to_owned()),
                            evt_block_number: blk.number,
                            forwarder: event.forwarder,
                            market_id: event.market_id.to_string(),
                            sender: event.sender,
                        });
                    }

                    None
                })
        })
        .collect());
    events.tellerv2_market_forwarder_renounceds.append(&mut blk
        .receipts()
        .flat_map(|view| {
            view.receipt.logs.iter()
                .filter(|log| log.address == TELLERV2_TRACKED_CONTRACT)
                .filter_map(|log| {
                    if let Some(event) = abi::tellerv2_contract::events::MarketForwarderRenounced::match_and_decode(log) {
                        return Some(contract::Tellerv2MarketForwarderRenounced {
                            evt_tx_hash: Hex(&view.transaction.hash).to_string(),
                            evt_index: log.block_index,
                            evt_block_time: Some(blk.timestamp().to_owned()),
                            evt_block_number: blk.number,
                            forwarder: event.forwarder,
                            market_id: event.market_id.to_string(),
                            sender: event.sender,
                        });
                    }

                    None
                })
        })
        .collect());
    events.tellerv2_market_owner_cancelled_bids.append(&mut blk
        .receipts()
        .flat_map(|view| {
            view.receipt.logs.iter()
                .filter(|log| log.address == TELLERV2_TRACKED_CONTRACT)
                .filter_map(|log| {
                    if let Some(event) = abi::tellerv2_contract::events::MarketOwnerCancelledBid::match_and_decode(log) {
                        return Some(contract::Tellerv2MarketOwnerCancelledBid {
                            evt_tx_hash: Hex(&view.transaction.hash).to_string(),
                            evt_index: log.block_index,
                            evt_block_time: Some(blk.timestamp().to_owned()),
                            evt_block_number: blk.number,
                            bid_id: event.bid_id.to_string(),
                        });
                    }

                    None
                })
        })
        .collect());
    events.tellerv2_ownership_transferreds.append(&mut blk
        .receipts()
        .flat_map(|view| {
            view.receipt.logs.iter()
                .filter(|log| log.address == TELLERV2_TRACKED_CONTRACT)
                .filter_map(|log| {
                    if let Some(event) = abi::tellerv2_contract::events::OwnershipTransferred::match_and_decode(log) {
                        return Some(contract::Tellerv2OwnershipTransferred {
                            evt_tx_hash: Hex(&view.transaction.hash).to_string(),
                            evt_index: log.block_index,
                            evt_block_time: Some(blk.timestamp().to_owned()),
                            evt_block_number: blk.number,
                            new_owner: event.new_owner,
                            previous_owner: event.previous_owner,
                        });
                    }

                    None
                })
        })
        .collect());
    events.tellerv2_pauseds.append(&mut blk
        .receipts()
        .flat_map(|view| {
            view.receipt.logs.iter()
                .filter(|log| log.address == TELLERV2_TRACKED_CONTRACT)
                .filter_map(|log| {
                    if let Some(event) = abi::tellerv2_contract::events::Paused::match_and_decode(log) {
                        return Some(contract::Tellerv2Paused {
                            evt_tx_hash: Hex(&view.transaction.hash).to_string(),
                            evt_index: log.block_index,
                            evt_block_time: Some(blk.timestamp().to_owned()),
                            evt_block_number: blk.number,
                            account: event.account,
                        });
                    }

                    None
                })
        })
        .collect());
    events.tellerv2_protocol_fee_sets.append(&mut blk
        .receipts()
        .flat_map(|view| {
            view.receipt.logs.iter()
                .filter(|log| log.address == TELLERV2_TRACKED_CONTRACT)
                .filter_map(|log| {
                    if let Some(event) = abi::tellerv2_contract::events::ProtocolFeeSet::match_and_decode(log) {
                        return Some(contract::Tellerv2ProtocolFeeSet {
                            evt_tx_hash: Hex(&view.transaction.hash).to_string(),
                            evt_index: log.block_index,
                            evt_block_time: Some(blk.timestamp().to_owned()),
                            evt_block_number: blk.number,
                            new_fee: event.new_fee.to_u64(),
                            old_fee: event.old_fee.to_u64(),
                        });
                    }

                    None
                })
        })
        .collect());
    events.tellerv2_submitted_bids.append(&mut blk
        .receipts()
        .flat_map(|view| {
            view.receipt.logs.iter()
                .filter(|log| log.address == TELLERV2_TRACKED_CONTRACT)
                .filter_map(|log| {
                    if let Some(event) = abi::tellerv2_contract::events::SubmittedBid::match_and_decode(log) {
                        return Some(contract::Tellerv2SubmittedBid {
                            evt_tx_hash: Hex(&view.transaction.hash).to_string(),
                            evt_index: log.block_index,
                            evt_block_time: Some(blk.timestamp().to_owned()),
                            evt_block_number: blk.number,
                            bid_id: event.bid_id.to_string(),
                            borrower: event.borrower,
                            metadata_uri: Vec::from(event.metadata_uri),
                            receiver: event.receiver,
                        });
                    }

                    None
                })
        })
        .collect());
    events.tellerv2_trusted_market_forwarder_sets.append(&mut blk
        .receipts()
        .flat_map(|view| {
            view.receipt.logs.iter()
                .filter(|log| log.address == TELLERV2_TRACKED_CONTRACT)
                .filter_map(|log| {
                    if let Some(event) = abi::tellerv2_contract::events::TrustedMarketForwarderSet::match_and_decode(log) {
                        return Some(contract::Tellerv2TrustedMarketForwarderSet {
                            evt_tx_hash: Hex(&view.transaction.hash).to_string(),
                            evt_index: log.block_index,
                            evt_block_time: Some(blk.timestamp().to_owned()),
                            evt_block_number: blk.number,
                            forwarder: event.forwarder,
                            market_id: event.market_id.to_string(),
                            sender: event.sender,
                        });
                    }

                    None
                })
        })
        .collect());
    events.tellerv2_unpauseds.append(&mut blk
        .receipts()
        .flat_map(|view| {
            view.receipt.logs.iter()
                .filter(|log| log.address == TELLERV2_TRACKED_CONTRACT)
                .filter_map(|log| {
                    if let Some(event) = abi::tellerv2_contract::events::Unpaused::match_and_decode(log) {
                        return Some(contract::Tellerv2Unpaused {
                            evt_tx_hash: Hex(&view.transaction.hash).to_string(),
                            evt_index: log.block_index,
                            evt_block_time: Some(blk.timestamp().to_owned()),
                            evt_block_number: blk.number,
                            account: event.account,
                        });
                    }

                    None
                })
        })
        .collect());
    
}

/*
fn db_tellerv2_out(events: &contract::Events, tables: &mut DatabaseChangeTables) {
    // Loop over all the abis events to create table changes
    events.tellerv2_accepted_bids.iter().for_each(|evt| {
        tables
            .create_row("tellerv2_accepted_bid", [("evt_tx_hash", evt.evt_tx_hash.to_string()),("evt_index", evt.evt_index.to_string())])
            .set("evt_block_time", evt.evt_block_time.as_ref().unwrap())
            .set("evt_block_number", evt.evt_block_number)
            .set("bid_id", BigDecimal::from_str(&evt.bid_id).unwrap())
            .set("lender", Hex(&evt.lender).to_string());
    });
    events.tellerv2_admin_changeds.iter().for_each(|evt| {
        tables
            .create_row("tellerv2_admin_changed", [("evt_tx_hash", evt.evt_tx_hash.to_string()),("evt_index", evt.evt_index.to_string())])
            .set("evt_block_time", evt.evt_block_time.as_ref().unwrap())
            .set("evt_block_number", evt.evt_block_number)
            .set("new_admin", Hex(&evt.new_admin).to_string())
            .set("previous_admin", Hex(&evt.previous_admin).to_string());
    });
    events.tellerv2_cancelled_bids.iter().for_each(|evt| {
        tables
            .create_row("tellerv2_cancelled_bid", [("evt_tx_hash", evt.evt_tx_hash.to_string()),("evt_index", evt.evt_index.to_string())])
            .set("evt_block_time", evt.evt_block_time.as_ref().unwrap())
            .set("evt_block_number", evt.evt_block_number)
            .set("bid_id", BigDecimal::from_str(&evt.bid_id).unwrap());
    });
    events.tellerv2_fee_paids.iter().for_each(|evt| {
        tables
            .create_row("tellerv2_fee_paid", [("evt_tx_hash", evt.evt_tx_hash.to_string()),("evt_index", evt.evt_index.to_string())])
            .set("evt_block_time", evt.evt_block_time.as_ref().unwrap())
            .set("evt_block_number", evt.evt_block_number)
            .set("amount", BigDecimal::from_str(&evt.amount).unwrap())
            .set("bid_id", BigDecimal::from_str(&evt.bid_id).unwrap())
            .set("fee_type", &evt.fee_type);
    });
    events.tellerv2_initializeds.iter().for_each(|evt| {
        tables
            .create_row("tellerv2_initialized", [("evt_tx_hash", evt.evt_tx_hash.to_string()),("evt_index", evt.evt_index.to_string())])
            .set("evt_block_time", evt.evt_block_time.as_ref().unwrap())
            .set("evt_block_number", evt.evt_block_number)
            .set("version", evt.version);
    });
    events.tellerv2_loan_liquidateds.iter().for_each(|evt| {
        tables
            .create_row("tellerv2_loan_liquidated", [("evt_tx_hash", evt.evt_tx_hash.to_string()),("evt_index", evt.evt_index.to_string())])
            .set("evt_block_time", evt.evt_block_time.as_ref().unwrap())
            .set("evt_block_number", evt.evt_block_number)
            .set("bid_id", BigDecimal::from_str(&evt.bid_id).unwrap())
            .set("liquidator", Hex(&evt.liquidator).to_string());
    });
    events.tellerv2_loan_repaids.iter().for_each(|evt| {
        tables
            .create_row("tellerv2_loan_repaid", [("evt_tx_hash", evt.evt_tx_hash.to_string()),("evt_index", evt.evt_index.to_string())])
            .set("evt_block_time", evt.evt_block_time.as_ref().unwrap())
            .set("evt_block_number", evt.evt_block_number)
            .set("bid_id", BigDecimal::from_str(&evt.bid_id).unwrap());
    });
    events.tellerv2_loan_repayments.iter().for_each(|evt| {
        tables
            .create_row("tellerv2_loan_repayment", [("evt_tx_hash", evt.evt_tx_hash.to_string()),("evt_index", evt.evt_index.to_string())])
            .set("evt_block_time", evt.evt_block_time.as_ref().unwrap())
            .set("evt_block_number", evt.evt_block_number)
            .set("bid_id", BigDecimal::from_str(&evt.bid_id).unwrap());
    });
    events.tellerv2_market_forwarder_approveds.iter().for_each(|evt| {
        tables
            .create_row("tellerv2_market_forwarder_approved", [("evt_tx_hash", evt.evt_tx_hash.to_string()),("evt_index", evt.evt_index.to_string())])
            .set("evt_block_time", evt.evt_block_time.as_ref().unwrap())
            .set("evt_block_number", evt.evt_block_number)
            .set("forwarder", Hex(&evt.forwarder).to_string())
            .set("market_id", BigDecimal::from_str(&evt.market_id).unwrap())
            .set("sender", Hex(&evt.sender).to_string());
    });
    events.tellerv2_market_forwarder_renounceds.iter().for_each(|evt| {
        tables
            .create_row("tellerv2_market_forwarder_renounced", [("evt_tx_hash", evt.evt_tx_hash.to_string()),("evt_index", evt.evt_index.to_string())])
            .set("evt_block_time", evt.evt_block_time.as_ref().unwrap())
            .set("evt_block_number", evt.evt_block_number)
            .set("forwarder", Hex(&evt.forwarder).to_string())
            .set("market_id", BigDecimal::from_str(&evt.market_id).unwrap())
            .set("sender", Hex(&evt.sender).to_string());
    });
    events.tellerv2_market_owner_cancelled_bids.iter().for_each(|evt| {
        tables
            .create_row("tellerv2_market_owner_cancelled_bid", [("evt_tx_hash", evt.evt_tx_hash.to_string()),("evt_index", evt.evt_index.to_string())])
            .set("evt_block_time", evt.evt_block_time.as_ref().unwrap())
            .set("evt_block_number", evt.evt_block_number)
            .set("bid_id", BigDecimal::from_str(&evt.bid_id).unwrap());
    });
    events.tellerv2_ownership_transferreds.iter().for_each(|evt| {
        tables
            .create_row("tellerv2_ownership_transferred", [("evt_tx_hash", evt.evt_tx_hash.to_string()),("evt_index", evt.evt_index.to_string())])
            .set("evt_block_time", evt.evt_block_time.as_ref().unwrap())
            .set("evt_block_number", evt.evt_block_number)
            .set("new_owner", Hex(&evt.new_owner).to_string())
            .set("previous_owner", Hex(&evt.previous_owner).to_string());
    });
    events.tellerv2_pauseds.iter().for_each(|evt| {
        tables
            .create_row("tellerv2_paused", [("evt_tx_hash", evt.evt_tx_hash.to_string()),("evt_index", evt.evt_index.to_string())])
            .set("evt_block_time", evt.evt_block_time.as_ref().unwrap())
            .set("evt_block_number", evt.evt_block_number)
            .set("account", Hex(&evt.account).to_string());
    });
    events.tellerv2_protocol_fee_sets.iter().for_each(|evt| {
        tables
            .create_row("tellerv2_protocol_fee_set", [("evt_tx_hash", evt.evt_tx_hash.to_string()),("evt_index", evt.evt_index.to_string())])
            .set("evt_block_time", evt.evt_block_time.as_ref().unwrap())
            .set("evt_block_number", evt.evt_block_number)
            .set("new_fee", evt.new_fee)
            .set("old_fee", evt.old_fee);
    });
    events.tellerv2_submitted_bids.iter().for_each(|evt| {
        tables
            .create_row("tellerv2_submitted_bid", [("evt_tx_hash", evt.evt_tx_hash.to_string()),("evt_index", evt.evt_index.to_string())])
            .set("evt_block_time", evt.evt_block_time.as_ref().unwrap())
            .set("evt_block_number", evt.evt_block_number)
            .set("bid_id", BigDecimal::from_str(&evt.bid_id).unwrap())
            .set("borrower", Hex(&evt.borrower).to_string())
            .set("metadata_uri", Hex(&evt.metadata_uri).to_string())
            .set("receiver", Hex(&evt.receiver).to_string());
            
            
        
        let bid_id = BigInt::from_str(&evt.bid_id).unwrap();
        let teller_v2_address = H160::from_slice( &TELLERV2_TRACKED_CONTRACT ) ;
            
        let submitted_bid_data = rpc::fetch_loan_summary_from_rpc(
            
            &teller_v2_address,
            &bid_id
            
        );
            
            
        if let Some(submitted_bid_data) = submitted_bid_data {
            
            let bid_id = submitted_bid_data.bid_id;
            
            tables
            .create_row("tellerv2_bid",  bid_id.to_string() )
            .set("bid_id",  &bid_id )
            .set("borrower", Hex(&submitted_bid_data.borrower_address).to_string()) 
            .set("lender", Hex(&submitted_bid_data.lender_address).to_string())
            .set("receiver", Hex(&evt.receiver).to_string())
            .set("principal_token_address", Hex(&submitted_bid_data.principal_token_address).to_string())
            .set("principal_amount",  &submitted_bid_data.principal_amount)
            
            ;
            
            
            
        }
            
            
            
            
            
            
            
    });
    events.tellerv2_trusted_market_forwarder_sets.iter().for_each(|evt| {
        tables
            .create_row("tellerv2_trusted_market_forwarder_set", [("evt_tx_hash", evt.evt_tx_hash.to_string()),("evt_index", evt.evt_index.to_string())])
            .set("evt_block_time", evt.evt_block_time.as_ref().unwrap())
            .set("evt_block_number", evt.evt_block_number)
            .set("forwarder", Hex(&evt.forwarder).to_string())
            .set("market_id", BigDecimal::from_str(&evt.market_id).unwrap())
            .set("sender", Hex(&evt.sender).to_string());
    });
    events.tellerv2_unpauseds.iter().for_each(|evt| {
        tables
            .create_row("tellerv2_unpaused", [("evt_tx_hash", evt.evt_tx_hash.to_string()),("evt_index", evt.evt_index.to_string())])
            .set("evt_block_time", evt.evt_block_time.as_ref().unwrap())
            .set("evt_block_number", evt.evt_block_number)
            .set("account", Hex(&evt.account).to_string());
    });
    events.tellerv2_upgradeds.iter().for_each(|evt| {
        tables
            .create_row("tellerv2_upgraded", [("evt_tx_hash", evt.evt_tx_hash.to_string()),("evt_index", evt.evt_index.to_string())])
            .set("evt_block_time", evt.evt_block_time.as_ref().unwrap())
            .set("evt_block_number", evt.evt_block_number)
            .set("implementation", Hex(&evt.implementation).to_string());
    });
}
*/

fn graph_tellerv2_out(events: &contract::Events, tables: &mut EntityChangesTables) {
    // Loop over all the abis events to create table changes
    events.tellerv2_accepted_bids.iter().for_each(|evt| {
        tables
            .create_row("tellerv2_accepted_bid", format!("{}-{}", evt.evt_tx_hash, evt.evt_index))
            .set("evt_tx_hash", &evt.evt_tx_hash)
            .set("evt_index", evt.evt_index)
            .set("evt_block_time", evt.evt_block_time.as_ref().unwrap())
            .set("evt_block_number", evt.evt_block_number)
            .set("bid_id", BigDecimal::from_str(&evt.bid_id).unwrap())
            .set("lender", Hex(&evt.lender).to_string());
            
            
            let bid_id = BigInt::from_str(&evt.bid_id).unwrap();
            let teller_v2_address = Address::from_slice(   &TELLERV2_TRACKED_CONTRACT   ) ;
                
            let submitted_bid_data_option = rpc::fetch_loan_summary_from_rpc(
                
                &teller_v2_address,
                &bid_id
                
            ) ; // this is failing 
                
                
                /*
                    
                    
                    The block stream encountered a substreams fatal error and will not retry: rpc error: code = InvalidArgument desc = step new irr: handler step new: execute modules: applying executor results "graph_out" on block 15096143: execute: maps wasm call: block 15096143: module "graph_out": general wasm execution panicked: wasm execution failed deterministically: panic in the wasm: "called `Option::unwrap()` on a `None` value" at src/lib.rs:750:15
                    
                */
                
                
          //  if let Some(submitted_bid_data) = submitted_bid_data {
                if let Some(submitted_bid_data) = submitted_bid_data_option {
                        let bid_id = submitted_bid_data.bid_id;
                            
                        tables
                        .create_row("tellerv2_bid",  bid_id.to_string() )
                        .set("bid_id",  &bid_id )
                        .set("borrower", Hex(&submitted_bid_data.borrower_address).to_string()) 
                        .set("lender", Hex(&submitted_bid_data.lender_address).to_string())
                    // .set("receiver", Hex(&evt.receiver).to_string())
                        .set("principal_token_address", Hex(&submitted_bid_data.principal_token_address).to_string())
                        .set("principal_amount",  &submitted_bid_data.principal_amount)
                        
                        ;
                    
                }
                
                
    });
    
    events.tellerv2_cancelled_bids.iter().for_each(|evt| {
        tables
            .create_row("tellerv2_cancelled_bid", format!("{}-{}", evt.evt_tx_hash, evt.evt_index))
            .set("evt_tx_hash", &evt.evt_tx_hash)
            .set("evt_index", evt.evt_index)
            .set("evt_block_time", evt.evt_block_time.as_ref().unwrap())
            .set("evt_block_number", evt.evt_block_number)
            .set("bid_id", BigDecimal::from_str(&evt.bid_id).unwrap());
    });
    events.tellerv2_fee_paids.iter().for_each(|evt| {
        tables
            .create_row("tellerv2_fee_paid", format!("{}-{}", evt.evt_tx_hash, evt.evt_index))
            .set("evt_tx_hash", &evt.evt_tx_hash)
            .set("evt_index", evt.evt_index)
            .set("evt_block_time", evt.evt_block_time.as_ref().unwrap())
            .set("evt_block_number", evt.evt_block_number)
            .set("amount", BigDecimal::from_str(&evt.amount).unwrap())
            .set("bid_id", BigDecimal::from_str(&evt.bid_id).unwrap())
            .set("fee_type", &evt.fee_type);
    });
    events.tellerv2_initializeds.iter().for_each(|evt| {
        tables
            .create_row("tellerv2_initialized", format!("{}-{}", evt.evt_tx_hash, evt.evt_index))
            .set("evt_tx_hash", &evt.evt_tx_hash)
            .set("evt_index", evt.evt_index)
            .set("evt_block_time", evt.evt_block_time.as_ref().unwrap())
            .set("evt_block_number", evt.evt_block_number)
            .set("version", evt.version);
    });
    events.tellerv2_loan_liquidateds.iter().for_each(|evt| {
        tables
            .create_row("tellerv2_loan_liquidated", format!("{}-{}", evt.evt_tx_hash, evt.evt_index))
            .set("evt_tx_hash", &evt.evt_tx_hash)
            .set("evt_index", evt.evt_index)
            .set("evt_block_time", evt.evt_block_time.as_ref().unwrap())
            .set("evt_block_number", evt.evt_block_number)
            .set("bid_id", BigDecimal::from_str(&evt.bid_id).unwrap())
            .set("liquidator", Hex(&evt.liquidator).to_string());
    });
    events.tellerv2_loan_repaids.iter().for_each(|evt| {
        tables
            .create_row("tellerv2_loan_repaid", format!("{}-{}", evt.evt_tx_hash, evt.evt_index))
            .set("evt_tx_hash", &evt.evt_tx_hash)
            .set("evt_index", evt.evt_index)
            .set("evt_block_time", evt.evt_block_time.as_ref().unwrap())
            .set("evt_block_number", evt.evt_block_number)
            .set("bid_id", BigDecimal::from_str(&evt.bid_id).unwrap());
    });
    events.tellerv2_loan_repayments.iter().for_each(|evt| {
        tables
            .create_row("tellerv2_loan_repayment", format!("{}-{}", evt.evt_tx_hash, evt.evt_index))
            .set("evt_tx_hash", &evt.evt_tx_hash)
            .set("evt_index", evt.evt_index)
            .set("evt_block_time", evt.evt_block_time.as_ref().unwrap())
            .set("evt_block_number", evt.evt_block_number)
            .set("bid_id", BigDecimal::from_str(&evt.bid_id).unwrap());
    });
    events.tellerv2_market_forwarder_approveds.iter().for_each(|evt| {
        tables
            .create_row("tellerv2_market_forwarder_approved", format!("{}-{}", evt.evt_tx_hash, evt.evt_index))
            .set("evt_tx_hash", &evt.evt_tx_hash)
            .set("evt_index", evt.evt_index)
            .set("evt_block_time", evt.evt_block_time.as_ref().unwrap())
            .set("evt_block_number", evt.evt_block_number)
            .set("forwarder", Hex(&evt.forwarder).to_string())
            .set("market_id", BigDecimal::from_str(&evt.market_id).unwrap())
            .set("sender", Hex(&evt.sender).to_string());
    });
    events.tellerv2_market_forwarder_renounceds.iter().for_each(|evt| {
        tables
            .create_row("tellerv2_market_forwarder_renounced", format!("{}-{}", evt.evt_tx_hash, evt.evt_index))
            .set("evt_tx_hash", &evt.evt_tx_hash)
            .set("evt_index", evt.evt_index)
            .set("evt_block_time", evt.evt_block_time.as_ref().unwrap())
            .set("evt_block_number", evt.evt_block_number)
            .set("forwarder", Hex(&evt.forwarder).to_string())
            .set("market_id", BigDecimal::from_str(&evt.market_id).unwrap())
            .set("sender", Hex(&evt.sender).to_string());
    });
    events.tellerv2_market_owner_cancelled_bids.iter().for_each(|evt| {
        tables
            .create_row("tellerv2_market_owner_cancelled_bid", format!("{}-{}", evt.evt_tx_hash, evt.evt_index))
            .set("evt_tx_hash", &evt.evt_tx_hash)
            .set("evt_index", evt.evt_index)
            .set("evt_block_time", evt.evt_block_time.as_ref().unwrap())
            .set("evt_block_number", evt.evt_block_number)
            .set("bid_id", BigDecimal::from_str(&evt.bid_id).unwrap());
    });
    events.tellerv2_ownership_transferreds.iter().for_each(|evt| {
        tables
            .create_row("tellerv2_ownership_transferred", format!("{}-{}", evt.evt_tx_hash, evt.evt_index))
            .set("evt_tx_hash", &evt.evt_tx_hash)
            .set("evt_index", evt.evt_index)
            .set("evt_block_time", evt.evt_block_time.as_ref().unwrap())
            .set("evt_block_number", evt.evt_block_number)
            .set("new_owner", Hex(&evt.new_owner).to_string())
            .set("previous_owner", Hex(&evt.previous_owner).to_string());
    });
    events.tellerv2_pauseds.iter().for_each(|evt| {
        tables
            .create_row("tellerv2_paused", format!("{}-{}", evt.evt_tx_hash, evt.evt_index))
            .set("evt_tx_hash", &evt.evt_tx_hash)
            .set("evt_index", evt.evt_index)
            .set("evt_block_time", evt.evt_block_time.as_ref().unwrap())
            .set("evt_block_number", evt.evt_block_number)
            .set("account", Hex(&evt.account).to_string());
    });
    events.tellerv2_protocol_fee_sets.iter().for_each(|evt| {
        tables
            .create_row("tellerv2_protocol_fee_set", format!("{}-{}", evt.evt_tx_hash, evt.evt_index))
            .set("evt_tx_hash", &evt.evt_tx_hash)
            .set("evt_index", evt.evt_index)
            .set("evt_block_time", evt.evt_block_time.as_ref().unwrap())
            .set("evt_block_number", evt.evt_block_number)
            .set("new_fee", evt.new_fee)
            .set("old_fee", evt.old_fee);
    });
    events.tellerv2_submitted_bids.iter().for_each(|evt| {
        tables
            .create_row("tellerv2_submitted_bid", format!("{}-{}", evt.evt_tx_hash, evt.evt_index))
            .set("evt_tx_hash", &evt.evt_tx_hash)
            .set("evt_index", evt.evt_index)
            .set("evt_block_time", evt.evt_block_time.as_ref().unwrap())
            .set("evt_block_number", evt.evt_block_number)
            .set("bid_id", BigDecimal::from_str(&evt.bid_id).unwrap())
            .set("borrower", Hex(&evt.borrower).to_string())
            .set("metadata_uri", Hex(&evt.metadata_uri).to_string())
            .set("receiver", Hex(&evt.receiver).to_string());
            
            
             
                
          
           // }.unwrap()
            
    });
    events.tellerv2_trusted_market_forwarder_sets.iter().for_each(|evt| {
        tables
            .create_row("tellerv2_trusted_market_forwarder_set", format!("{}-{}", evt.evt_tx_hash, evt.evt_index))
            .set("evt_tx_hash", &evt.evt_tx_hash)
            .set("evt_index", evt.evt_index)
            .set("evt_block_time", evt.evt_block_time.as_ref().unwrap())
            .set("evt_block_number", evt.evt_block_number)
            .set("forwarder", Hex(&evt.forwarder).to_string())
            .set("market_id", BigDecimal::from_str(&evt.market_id).unwrap())
            .set("sender", Hex(&evt.sender).to_string());
    });
    events.tellerv2_unpauseds.iter().for_each(|evt| {
        tables
            .create_row("tellerv2_unpaused", format!("{}-{}", evt.evt_tx_hash, evt.evt_index))
            .set("evt_tx_hash", &evt.evt_tx_hash)
            .set("evt_index", evt.evt_index)
            .set("evt_block_time", evt.evt_block_time.as_ref().unwrap())
            .set("evt_block_number", evt.evt_block_number)
            .set("account", Hex(&evt.account).to_string());
    });
 
}

#[substreams::handlers::map]
fn map_events(blk: eth::Block) -> Result<contract::Events, substreams::errors::Error> {
    let mut events = contract::Events::default();
    map_tellerv2_events(&blk, &mut events);
    Ok(events)
}

/*
#[substreams::handlers::map]
fn db_out(events: contract::Events) -> Result<DatabaseChanges, substreams::errors::Error> {
    // Initialize Database Changes container
    let mut tables = DatabaseChangeTables::new();
    db_tellerv2_out(&events, &mut tables);
    Ok(tables.to_database_changes())
}
*/


#[substreams::handlers::map]
fn graph_out(events: contract::Events) -> Result<EntityChanges, substreams::errors::Error> {
    // Initialize Database Changes container
    let mut tables = EntityChangesTables::new();
    graph_tellerv2_out(&events, &mut tables);
    Ok(tables.to_entity_changes())
}
