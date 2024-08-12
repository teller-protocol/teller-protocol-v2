mod abi;
mod pb;
mod rpc;
use ethabi::{ethereum_types::H160, Address};
use hex_literal::hex;
use pb::contract::v1 as contract;
use substreams::Hex;
use substreams_database_change::pb::database::DatabaseChanges;
use substreams_database_change::tables::Tables as DatabaseChangeTables;
use substreams_entity_change::pb::entity::EntityChanges;
use substreams_entity_change::tables::Tables as EntityChangesTables;
use substreams_ethereum::pb::eth::v2 as eth;
use substreams_ethereum::Event;

#[allow(unused_imports)]
use num_traits::cast::ToPrimitive;
use std::str::FromStr;
use substreams::scalar::{BigDecimal, BigInt};

substreams_ethereum::init!();

use substreams::prelude::*;

//these are both mainet
const TELLERV2_TRACKED_CONTRACT: [u8; 20] = hex!("00182fdb0b880ee24d428e3cc39383717677c37e");

const UNISWAPV2_FACTORY_CONTRACT: &str = "0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f";

fn map_tellerv2_events(blk: &eth::Block, events: &mut contract::Events) {
    events.tellerv2_accepted_bids.append(
        &mut blk
            .receipts()
            .flat_map(|view| {
                view.receipt
                    .logs
                    .iter()
                    .filter(|log| log.address == TELLERV2_TRACKED_CONTRACT)
                    .filter_map(|log| {
                        if let Some(event) =
                            abi::tellerv2_contract::events::AcceptedBid::match_and_decode(log)
                        {
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
            .collect(),
    );

    events.tellerv2_cancelled_bids.append(
        &mut blk
            .receipts()
            .flat_map(|view| {
                view.receipt
                    .logs
                    .iter()
                    .filter(|log| log.address == TELLERV2_TRACKED_CONTRACT)
                    .filter_map(|log| {
                        if let Some(event) =
                            abi::tellerv2_contract::events::CancelledBid::match_and_decode(log)
                        {
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
            .collect(),
    );
    events.tellerv2_fee_paids.append(
        &mut blk
            .receipts()
            .flat_map(|view| {
                view.receipt
                    .logs
                    .iter()
                    .filter(|log| log.address == TELLERV2_TRACKED_CONTRACT)
                    .filter_map(|log| {
                        if let Some(event) =
                            abi::tellerv2_contract::events::FeePaid::match_and_decode(log)
                        {
                            return Some(contract::Tellerv2FeePaid {
                                evt_tx_hash: Hex(&view.transaction.hash).to_string(),
                                evt_index: log.block_index,
                                evt_block_time: Some(blk.timestamp().to_owned()),
                                evt_block_number: blk.number,
                                amount: event.amount.to_string(),
                                bid_id: event.bid_id.to_string(),
                                fee_type: Hex(event.fee_type.hash).to_string(), // ???
                            });
                        }

                        None
                    })
            })
            .collect(),
    );
    events.tellerv2_initializeds.append(
        &mut blk
            .receipts()
            .flat_map(|view| {
                view.receipt
                    .logs
                    .iter()
                    .filter(|log| log.address == TELLERV2_TRACKED_CONTRACT)
                    .filter_map(|log| {
                        if let Some(event) =
                            abi::tellerv2_contract::events::Initialized::match_and_decode(log)
                        {
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
            .collect(),
    );
    events.tellerv2_loan_liquidateds.append(
        &mut blk
            .receipts()
            .flat_map(|view| {
                view.receipt
                    .logs
                    .iter()
                    .filter(|log| log.address == TELLERV2_TRACKED_CONTRACT)
                    .filter_map(|log| {
                        if let Some(event) =
                            abi::tellerv2_contract::events::LoanLiquidated::match_and_decode(log)
                        {
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
            .collect(),
    );
    events.tellerv2_loan_repaids.append(
        &mut blk
            .receipts()
            .flat_map(|view| {
                view.receipt
                    .logs
                    .iter()
                    .filter(|log| log.address == TELLERV2_TRACKED_CONTRACT)
                    .filter_map(|log| {
                        if let Some(event) =
                            abi::tellerv2_contract::events::LoanRepaid::match_and_decode(log)
                        {
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
            .collect(),
    );
    events.tellerv2_loan_repayments.append(
        &mut blk
            .receipts()
            .flat_map(|view| {
                view.receipt
                    .logs
                    .iter()
                    .filter(|log| log.address == TELLERV2_TRACKED_CONTRACT)
                    .filter_map(|log| {
                        if let Some(event) =
                            abi::tellerv2_contract::events::LoanRepayment::match_and_decode(log)
                        {
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
            .collect(),
    );
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
    events.tellerv2_ownership_transferreds.append(
        &mut blk
            .receipts()
            .flat_map(|view| {
                view.receipt
                    .logs
                    .iter()
                    .filter(|log| log.address == TELLERV2_TRACKED_CONTRACT)
                    .filter_map(|log| {
                        if let Some(event) =
                            abi::tellerv2_contract::events::OwnershipTransferred::match_and_decode(
                                log,
                            )
                        {
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
            .collect(),
    );
    events.tellerv2_pauseds.append(
        &mut blk
            .receipts()
            .flat_map(|view| {
                view.receipt
                    .logs
                    .iter()
                    .filter(|log| log.address == TELLERV2_TRACKED_CONTRACT)
                    .filter_map(|log| {
                        if let Some(event) =
                            abi::tellerv2_contract::events::Paused::match_and_decode(log)
                        {
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
            .collect(),
    );
    events.tellerv2_protocol_fee_sets.append(
        &mut blk
            .receipts()
            .flat_map(|view| {
                view.receipt
                    .logs
                    .iter()
                    .filter(|log| log.address == TELLERV2_TRACKED_CONTRACT)
                    .filter_map(|log| {
                        if let Some(event) =
                            abi::tellerv2_contract::events::ProtocolFeeSet::match_and_decode(log)
                        {
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
            .collect(),
    );
    events.tellerv2_submitted_bids.append(
        &mut blk
            .receipts()
            .flat_map(|view| {
                view.receipt
                    .logs
                    .iter()
                    .filter(|log| log.address == TELLERV2_TRACKED_CONTRACT)
                    .filter_map(|log| {
                        if let Some(event) =
                            abi::tellerv2_contract::events::SubmittedBid::match_and_decode(log)
                        {
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
            .collect(),
    );
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
    events.tellerv2_unpauseds.append(
        &mut blk
            .receipts()
            .flat_map(|view| {
                view.receipt
                    .logs
                    .iter()
                    .filter(|log| log.address == TELLERV2_TRACKED_CONTRACT)
                    .filter_map(|log| {
                        if let Some(event) =
                            abi::tellerv2_contract::events::Unpaused::match_and_decode(log)
                        {
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
            .collect(),
    );
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

/*

any block wiht any activity -- get price of ETH / USDC ? as multiplier..
*/

#[substreams::handlers::store]
fn store_token_interaction_deltas(
    events: contract::Events,

    token_address_delta_store: StoreAddBigInt, //just use a flag..   key is address as string
) {
    //FOR NOW .. CAN CAUSE ISSUES
    let ord = 0;

    let mut activity_occured = false;

    events.tellerv2_submitted_bids.iter().for_each(|evt| {
        let bid_id = BigInt::from_str(&evt.bid_id).unwrap();
        let teller_v2_address = Address::from_slice(&TELLERV2_TRACKED_CONTRACT);

        // this fails for very old bids as this fn wasnt added until later
        let submitted_bid_data_option =
            rpc::tellerv2::fetch_loan_summary_from_rpc(&teller_v2_address, &bid_id);

        if let Some(submitted_bid_data) = submitted_bid_data_option {
            let store_key: String = address_to_string(&submitted_bid_data.principal_token_address);
            token_address_delta_store.add(ord, &store_key, BigInt::one());

            activity_occured = true;
        }
    });

    // Loop over all the abis events to create table changes
    events.tellerv2_accepted_bids.iter().for_each(|evt| {
        let bid_id = BigInt::from_str(&evt.bid_id).unwrap();
        let teller_v2_address = Address::from_slice(&TELLERV2_TRACKED_CONTRACT);

        // this fails for very old bids as this fn wasnt added until later
        let submitted_bid_data_option =
            rpc::tellerv2::fetch_loan_summary_from_rpc(&teller_v2_address, &bid_id);

        if let Some(submitted_bid_data) = submitted_bid_data_option {
            let store_key: String = address_to_string(&submitted_bid_data.principal_token_address);
            token_address_delta_store.add(ord, &store_key, BigInt::one());

            activity_occured = true;
        }
    });

    events.tellerv2_loan_liquidateds.iter().for_each(|evt| {
        let bid_id = BigInt::from_str(&evt.bid_id).unwrap();
        let teller_v2_address = Address::from_slice(&TELLERV2_TRACKED_CONTRACT);

        // this fails for very old bids as this fn wasnt added until later
        let submitted_bid_data_option =
            rpc::tellerv2::fetch_loan_summary_from_rpc(&teller_v2_address, &bid_id);

        if let Some(submitted_bid_data) = submitted_bid_data_option {
            let store_key: String = address_to_string(&submitted_bid_data.principal_token_address);
            token_address_delta_store.add(ord, &store_key, BigInt::one());

            activity_occured = true;
        }
    });
    events.tellerv2_loan_repaids.iter().for_each(|evt| {
        let bid_id = BigInt::from_str(&evt.bid_id).unwrap();
        let teller_v2_address = Address::from_slice(&TELLERV2_TRACKED_CONTRACT);

        // this fails for very old bids as this fn wasnt added until later
        let submitted_bid_data_option =
            rpc::tellerv2::fetch_loan_summary_from_rpc(&teller_v2_address, &bid_id);

        if let Some(submitted_bid_data) = submitted_bid_data_option {
            let store_key: String = address_to_string(&submitted_bid_data.principal_token_address);
            token_address_delta_store.add(ord, &store_key, BigInt::one());

            activity_occured = true;
        }
    });

    if activity_occured {
        //always capture USDC / ETH price data ... so we can do lookups ..

        let USDC_ADDRESS = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48";

        //add usdc as a delta !

        let store_key: String = format!("{}", USDC_ADDRESS);

        token_address_delta_store.add(ord, &store_key, BigInt::one());
    }
}

#[substreams::handlers::store]
fn store_decimals_for_tokens(
    //uses rpc !! heavily
    token_address_delta_store: Deltas<DeltaBigInt>, //each key of the delta array represents a tokenAddress that we need to get price for ..

    bigint_set_store: StoreSetBigInt, //for block time and block number
) {
    let ord = 0; // FOR NOW - CAN CAUSE ISSUES - GET FROM LOG AND STUFF INTO EVENT

    let mut tokens_to_fetch_decimals_array: Vec<String> = Vec::new();

    for token_address_delta in token_address_delta_store.iter() {
        tokens_to_fetch_decimals_array.push(token_address_delta.key.clone());
    }

    let weth_address = "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2".to_string();

    let usdc_address = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48".to_string();

    tokens_to_fetch_decimals_array.push(weth_address);
    tokens_to_fetch_decimals_array.push(usdc_address);

    //always compare to ETH !
    for token_address in tokens_to_fetch_decimals_array {
        let token_decimals_option =
            rpc::erc20::fetch_token_decimals(&H160::from_str(token_address.as_str()).unwrap());

        if let Some(decimals) = token_decimals_option {
            bigint_set_store.set(ord, token_address.clone(), &decimals);
        }

        //if let Some( token_decimals ) =  token_decimals {
        //    bigint_set_store.set(ord, token_address.clone(), &token_decimals )  ;
        //}
    } // iter
}

#[substreams::handlers::store]
fn store_uniswap_prices_for_tokens(
    //uses rpc !! heavily
    token_address_delta_store: Deltas<DeltaBigInt>, //each key of the delta array represents a tokenAddress that we need to get price for ..

    bigint_set_store: StoreSetFloat64, //for block time and block number
) {
    let ord = 0; // FOR NOW - CAN CAUSE ISSUES - GET FROM LOG AND STUFF INTO EVENT

    let WETH_ADDRESS = "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2";

    //always compare to ETH !
    for token_address_delta in token_address_delta_store.iter() {
        let token_address = &token_address_delta.key;

        let mut price_ratio_to_base_currency: Option<f64> = None;

        substreams::log::println(format!("token address {}", token_address));

        //we are inverting if the input is greater than the reference..

        let pair_address_option = rpc::uniswapv2_factory::fetch_pair_from_factory(
            &H160::from_str(UNISWAPV2_FACTORY_CONTRACT).unwrap(),
            &H160::from_str(WETH_ADDRESS).unwrap(),
            &H160::from_str(token_address.as_str()).unwrap(), //bad character !?
        );

        if let Some(pair_address) = pair_address_option {
            let reserves_data_option = rpc::uniswapv2_pair::fetch_reserves_from_pair(&pair_address);

            if let Some(reserves_data) = reserves_data_option {
                //doesnt ordering matter?? have to figure this out
                price_ratio_to_base_currency = Some(reserves_data.get_price_ratio());
            }
        }

        if let Some(price_ratio_to_base_currency) = price_ratio_to_base_currency {
            bigint_set_store.set(ord, token_address.clone(), &price_ratio_to_base_currency);
        }
    }
}

fn graph_tellerv2_out(
    events: &contract::Events,

    token_address_delta_store: &Deltas<DeltaBigInt>,

    token_prices: &StoreGetFloat64,

    token_decimals: &StoreGetBigInt,

    tables: &mut EntityChangesTables,
) {
    events.tellerv2_submitted_bids.iter().for_each(|evt| {
        tables
            .create_row(
                "tellerv2_submitted_bid",
                format!("{}-{}", evt.evt_tx_hash, evt.evt_index),
            )
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

    // Loop over all the abis events to create table changes
    events.tellerv2_accepted_bids.iter().for_each(|evt| {
        tables
            .create_row(
                "tellerv2_accepted_bid",
                format!("{}-{}", evt.evt_tx_hash, evt.evt_index),
            )
            .set("evt_tx_hash", &evt.evt_tx_hash)
            .set("evt_index", evt.evt_index)
            .set("evt_block_time", evt.evt_block_time.as_ref().unwrap())
            .set("evt_block_number", evt.evt_block_number)
            .set("bid_id", BigDecimal::from_str(&evt.bid_id).unwrap())
            .set("lender", Hex(&evt.lender).to_string());

        let bid_id = BigInt::from_str(&evt.bid_id).unwrap();
        let teller_v2_address = Address::from_slice(&TELLERV2_TRACKED_CONTRACT);

        // this fails for very old bids as this fn wasnt added until later
        let submitted_bid_data_option =
            rpc::tellerv2::fetch_loan_summary_from_rpc(&teller_v2_address, &bid_id);

        /*


            The block stream encountered a substreams fatal error and will not retry: rpc error: code = InvalidArgument desc = step new irr: handler step new: execute modules: applying executor results "graph_out" on block 15096143: execute: maps wasm call: block 15096143: module "graph_out": general wasm execution panicked: wasm execution failed deterministically: panic in the wasm: "called `Option::unwrap()` on a `None` value" at src/lib.rs:750:15

        */

        //  if let Some(submitted_bid_data) = submitted_bid_data {
        if let Some(submitted_bid_data) = submitted_bid_data_option {
            let bid_id = submitted_bid_data.bid_id;

            let weth_address =
                H160::from_str("0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2").unwrap();
            let usdc_address =
                H160::from_str("0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48").unwrap();

            let principal_token_address = submitted_bid_data.principal_token_address.clone();
            let principal_amount = submitted_bid_data.principal_amount.clone();

            let principal_amount_usdc = calculate_principal_amount_usdc(
                principal_amount,
                principal_token_address,
                weth_address,
                usdc_address,
                &token_prices,
                &token_decimals,
            );

            let principal_amount_usdc_big_decimal = f64_to_bigdecimal(principal_amount_usdc);

            tables
                .create_row("tellerv2_bid", bid_id.to_string())
                .set("bid_id", &bid_id)
                .set(
                    "borrower",
                    Hex(&submitted_bid_data.borrower_address).to_string(),
                )
                .set(
                    "lender",
                    Hex(&submitted_bid_data.lender_address).to_string(),
                )
                // .set("receiver", Hex(&evt.receiver).to_string())
                .set(
                    "principal_token_address",
                    Hex(&submitted_bid_data.principal_token_address).to_string(),
                )
                .set("principal_amount", &submitted_bid_data.principal_amount)
                .set("principal_amount_usdc", &principal_amount_usdc_big_decimal);
        }
    });

    events.tellerv2_cancelled_bids.iter().for_each(|evt| {
        tables
            .create_row(
                "tellerv2_cancelled_bid",
                format!("{}-{}", evt.evt_tx_hash, evt.evt_index),
            )
            .set("evt_tx_hash", &evt.evt_tx_hash)
            .set("evt_index", evt.evt_index)
            .set("evt_block_time", evt.evt_block_time.as_ref().unwrap())
            .set("evt_block_number", evt.evt_block_number)
            .set("bid_id", BigDecimal::from_str(&evt.bid_id).unwrap());
    });
    events.tellerv2_fee_paids.iter().for_each(|evt| {
        tables
            .create_row(
                "tellerv2_fee_paid",
                format!("{}-{}", evt.evt_tx_hash, evt.evt_index),
            )
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
            .create_row(
                "tellerv2_initialized",
                format!("{}-{}", evt.evt_tx_hash, evt.evt_index),
            )
            .set("evt_tx_hash", &evt.evt_tx_hash)
            .set("evt_index", evt.evt_index)
            .set("evt_block_time", evt.evt_block_time.as_ref().unwrap())
            .set("evt_block_number", evt.evt_block_number)
            .set("version", evt.version);
    });
    events.tellerv2_loan_liquidateds.iter().for_each(|evt| {
        tables
            .create_row(
                "tellerv2_loan_liquidated",
                format!("{}-{}", evt.evt_tx_hash, evt.evt_index),
            )
            .set("evt_tx_hash", &evt.evt_tx_hash)
            .set("evt_index", evt.evt_index)
            .set("evt_block_time", evt.evt_block_time.as_ref().unwrap())
            .set("evt_block_number", evt.evt_block_number)
            .set("bid_id", BigDecimal::from_str(&evt.bid_id).unwrap())
            .set("liquidator", Hex(&evt.liquidator).to_string());
    });
    events.tellerv2_loan_repaids.iter().for_each(|evt| {
        tables
            .create_row(
                "tellerv2_loan_repaid",
                format!("{}-{}", evt.evt_tx_hash, evt.evt_index),
            )
            .set("evt_tx_hash", &evt.evt_tx_hash)
            .set("evt_index", evt.evt_index)
            .set("evt_block_time", evt.evt_block_time.as_ref().unwrap())
            .set("evt_block_number", evt.evt_block_number)
            .set("bid_id", BigDecimal::from_str(&evt.bid_id).unwrap());
    });
    events.tellerv2_loan_repayments.iter().for_each(|evt| {
        tables
            .create_row(
                "tellerv2_loan_repayment",
                format!("{}-{}", evt.evt_tx_hash, evt.evt_index),
            )
            .set("evt_tx_hash", &evt.evt_tx_hash)
            .set("evt_index", evt.evt_index)
            .set("evt_block_time", evt.evt_block_time.as_ref().unwrap())
            .set("evt_block_number", evt.evt_block_number)
            .set("bid_id", BigDecimal::from_str(&evt.bid_id).unwrap());
    });
    events
        .tellerv2_market_forwarder_approveds
        .iter()
        .for_each(|evt| {
            tables
                .create_row(
                    "tellerv2_market_forwarder_approved",
                    format!("{}-{}", evt.evt_tx_hash, evt.evt_index),
                )
                .set("evt_tx_hash", &evt.evt_tx_hash)
                .set("evt_index", evt.evt_index)
                .set("evt_block_time", evt.evt_block_time.as_ref().unwrap())
                .set("evt_block_number", evt.evt_block_number)
                .set("forwarder", Hex(&evt.forwarder).to_string())
                .set("market_id", BigDecimal::from_str(&evt.market_id).unwrap())
                .set("sender", Hex(&evt.sender).to_string());
        });
    events
        .tellerv2_market_forwarder_renounceds
        .iter()
        .for_each(|evt| {
            tables
                .create_row(
                    "tellerv2_market_forwarder_renounced",
                    format!("{}-{}", evt.evt_tx_hash, evt.evt_index),
                )
                .set("evt_tx_hash", &evt.evt_tx_hash)
                .set("evt_index", evt.evt_index)
                .set("evt_block_time", evt.evt_block_time.as_ref().unwrap())
                .set("evt_block_number", evt.evt_block_number)
                .set("forwarder", Hex(&evt.forwarder).to_string())
                .set("market_id", BigDecimal::from_str(&evt.market_id).unwrap())
                .set("sender", Hex(&evt.sender).to_string());
        });
    events
        .tellerv2_market_owner_cancelled_bids
        .iter()
        .for_each(|evt| {
            tables
                .create_row(
                    "tellerv2_market_owner_cancelled_bid",
                    format!("{}-{}", evt.evt_tx_hash, evt.evt_index),
                )
                .set("evt_tx_hash", &evt.evt_tx_hash)
                .set("evt_index", evt.evt_index)
                .set("evt_block_time", evt.evt_block_time.as_ref().unwrap())
                .set("evt_block_number", evt.evt_block_number)
                .set("bid_id", BigDecimal::from_str(&evt.bid_id).unwrap());
        });
    events
        .tellerv2_ownership_transferreds
        .iter()
        .for_each(|evt| {
            tables
                .create_row(
                    "tellerv2_ownership_transferred",
                    format!("{}-{}", evt.evt_tx_hash, evt.evt_index),
                )
                .set("evt_tx_hash", &evt.evt_tx_hash)
                .set("evt_index", evt.evt_index)
                .set("evt_block_time", evt.evt_block_time.as_ref().unwrap())
                .set("evt_block_number", evt.evt_block_number)
                .set("new_owner", Hex(&evt.new_owner).to_string())
                .set("previous_owner", Hex(&evt.previous_owner).to_string());
        });
    events.tellerv2_pauseds.iter().for_each(|evt| {
        tables
            .create_row(
                "tellerv2_paused",
                format!("{}-{}", evt.evt_tx_hash, evt.evt_index),
            )
            .set("evt_tx_hash", &evt.evt_tx_hash)
            .set("evt_index", evt.evt_index)
            .set("evt_block_time", evt.evt_block_time.as_ref().unwrap())
            .set("evt_block_number", evt.evt_block_number)
            .set("account", Hex(&evt.account).to_string());
    });
    events.tellerv2_protocol_fee_sets.iter().for_each(|evt| {
        tables
            .create_row(
                "tellerv2_protocol_fee_set",
                format!("{}-{}", evt.evt_tx_hash, evt.evt_index),
            )
            .set("evt_tx_hash", &evt.evt_tx_hash)
            .set("evt_index", evt.evt_index)
            .set("evt_block_time", evt.evt_block_time.as_ref().unwrap())
            .set("evt_block_number", evt.evt_block_number)
            .set("new_fee", evt.new_fee)
            .set("old_fee", evt.old_fee);
    });

    events
        .tellerv2_trusted_market_forwarder_sets
        .iter()
        .for_each(|evt| {
            tables
                .create_row(
                    "tellerv2_trusted_market_forwarder_set",
                    format!("{}-{}", evt.evt_tx_hash, evt.evt_index),
                )
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
            .create_row(
                "tellerv2_unpaused",
                format!("{}-{}", evt.evt_tx_hash, evt.evt_index),
            )
            .set("evt_tx_hash", &evt.evt_tx_hash)
            .set("evt_index", evt.evt_index)
            .set("evt_block_time", evt.evt_block_time.as_ref().unwrap())
            .set("evt_block_number", evt.evt_block_number)
            .set("account", Hex(&evt.account).to_string());
    });

    for token_address_delta in token_address_delta_store.iter() {
        let ord = 0; // FOR NOW

        let token_address = &token_address_delta.key;

        let token_price_option = token_prices.get_at(ord, token_address);

        let WETH_ADDRESS = "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2";

        if let Some(token_price) = token_price_option {
            tables
                .create_row("token_price", token_address.clone())
                .set("base_token_address", token_address)
                .set("reference_token_address", WETH_ADDRESS)
                .set("price_ratio", token_price.to_string());
        }
    }
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
fn graph_out(
    events: contract::Events,
    token_address_delta_store: Deltas<DeltaBigInt>, //each key of the delta array represents a tokenAddress that we need to get price for ..

    token_prices: StoreGetFloat64,
    token_decimals: StoreGetBigInt,
) -> Result<EntityChanges, substreams::errors::Error> {
    // Initialize Database Changes container
    let mut tables = EntityChangesTables::new();
    graph_tellerv2_out(
        &events,
        &token_address_delta_store,
        &token_prices,
        &token_decimals,
        &mut tables,
    );
    Ok(tables.to_entity_changes())
}

// this is correct but stuff may be flipped

fn calculate_principal_amount_usdc(
    input_token_amount: BigInt,
    input_token_address: Address,

    reference_token_address: Address, //WETH
    usdc_token_address: Address,

    token_prices: &StoreGetFloat64,

    token_decimals: &StoreGetBigInt,
) -> f64 {
    let ord = 0; // FOR NOW

    let input_token_price_to_reference = token_prices
        .get_at(ord, address_to_string(&input_token_address))
        .unwrap_or(1.0);

    let input_token_decimals = token_decimals
        .get_at(ord, address_to_string(&input_token_address))
        .unwrap_or(BigInt::from_str("18").unwrap())
        .to_u64();
    let reference_token_decimals = token_decimals
        .get_at(ord, address_to_string(&reference_token_address))
        .unwrap_or(BigInt::from_str("18").unwrap())
        .to_u64();
    let usdc_token_decimals = token_decimals
        .get_at(ord, address_to_string(&usdc_token_address))
        .unwrap_or(BigInt::from_str("18").unwrap())
        .to_u64();

    let usdc_token_price_to_reference = token_prices
        .get_at(ord, address_to_string(&usdc_token_address))
        .unwrap_or(1.0);

    calculate_principal_amount_usdc_internal(
        input_token_amount,
        input_token_address,
        reference_token_address,
        usdc_token_address,
        input_token_price_to_reference,
        usdc_token_price_to_reference,
        input_token_decimals,
        reference_token_decimals,
        usdc_token_decimals,
    )
}

fn calculate_principal_amount_usdc_internal(
    input_token_amount: BigInt,
    input_token_address: Address,

    reference_token_address: Address, //WETH
    usdc_token_address: Address,

    input_token_price_to_reference: f64,
    usdc_token_price_to_reference: f64,

    input_token_decimals: u64,
    reference_token_decimals: u64,
    usdc_token_decimals: u64,
) -> f64 {
    let ord = 0; // FOR NOW

    //let mut input_token_price_to_reference = token_prices.get_at(ord, address_to_string( &input_token_address )).unwrap_or( 1.0 );

    //usdc is not inverted
    let need_to_invert_input_token_price_ratio = input_token_address > reference_token_address;

    // why are these flipped?  are my test assumptions wrong ?   maybe bc i have to divide by the usdc price ?

    let updated_input_token_price_to_reference = match need_to_invert_input_token_price_ratio {
        false => 1.0 / input_token_price_to_reference,
        true => input_token_price_to_reference,
    };

    let need_to_invert_usdc_token_price_ratio = usdc_token_address > reference_token_address; // is this ok ?

    let updated_usdc_token_price_to_reference = match need_to_invert_usdc_token_price_ratio {
        false => usdc_token_price_to_reference,
        true => 1.0 / usdc_token_price_to_reference,
    };

    // Convert the input token amount to a float value
    let input_token_amount_float_raw = bigint_to_f64(&input_token_amount);

    let input_token_amount_scaled =
        input_token_amount_float_raw * 10f64.powi(-(input_token_decimals as i32));

    let updated_input_token_price_to_reference_scaled = match need_to_invert_input_token_price_ratio
    {
        true => {
            updated_input_token_price_to_reference
                * 10f64.powi(reference_token_decimals as i32 - input_token_decimals as i32)
        }
        false => {
            updated_input_token_price_to_reference
                * 10f64.powi(input_token_decimals as i32 - reference_token_decimals as i32)
        }
    };

    let input_value_in_reference_token_scaled =
        input_token_amount_scaled * updated_input_token_price_to_reference_scaled;

    //   WETH  *   ( usdc   /  weth    )

    println!(
        "updated_usdc_token_price_to_reference {:?}",
        updated_usdc_token_price_to_reference
    );

    let usdc_token_price_to_reference_scaled = updated_usdc_token_price_to_reference
        * 10f64.powi(reference_token_decimals as i32 - usdc_token_decimals as i32);

    let final_amount = input_value_in_reference_token_scaled * usdc_token_price_to_reference_scaled;

    final_amount
}

pub fn address_to_string(address: &Address) -> String {
    format!("0x{:x}", address)
}

fn bigint_to_f64(value: &BigInt) -> f64 {
    value.to_string().parse::<f64>().unwrap_or(0.0)
}

fn f64_to_bigdecimal(value: f64) -> BigDecimal {
    // Convert the f64 to a string
    let value_str = value.to_string();
    // Create a BigDecimal from the string
    BigDecimal::from_str(&value_str).unwrap()
}

#[cfg(test)]
mod tests {
    use super::*;
    use ethabi::ethereum_types::H160;
    use substreams::scalar::BigInt;

    #[test]
    fn test_calculate_principal_amount_usdc_internal() {
        let input_token_amount = BigInt::from_str("1000000000000000000").unwrap(); //1 unit 18 decimals

        let input_token_address =
            H160::from_str("0x0000000000000000000000000000000000000001").unwrap();
        let reference_token_address =
            H160::from_str("0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2").unwrap(); // WETH
        let usdc_token_address =
            H160::from_str("0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48").unwrap(); // USDC

        //   let input_token_price_to_reference = 0.002f64; // Example: 1 input token = 0.002 WETH
        //    let usdc_token_price_to_reference = 3000.0f64; // Example: 1 WETH = 3000 USDC

        //denom is always WETH , numerator is always the other token

        // 500 input tokens to 1 weth

        //make sure these make sense
        let input_token_price_to_reference = 500.0f64; // 1 input token = 0.002 WETH (1e18 input units to 2e15 WETH units)
        let usdc_token_price_to_reference = 0.0000000030f64; // 1e18 WETH units = 3000e6 USDC units

        // this is USDC PER WETH   RAW

        //   reserve 0 is 3000_000000
        //reserve 1 is 1000000000000000000
        // 0.000333333 WETH per usdc

        // 3000 USDC per WETh

        // 0.002 WETH worth of input token
        // 6.666  USDC worth of input token

        let input_token_decimals = 18;
        let reference_token_decimals = 18;
        let usdc_token_decimals = 6;

        let usdc_value = calculate_principal_amount_usdc_internal(
            input_token_amount,
            input_token_address,
            reference_token_address,
            usdc_token_address,
            input_token_price_to_reference,
            usdc_token_price_to_reference,
            input_token_decimals,
            reference_token_decimals,
            usdc_token_decimals,
        );

        println!("usdc value is {:?}", usdc_value);
        // Expected USDC value: 1 token * 0.002 WETH/token * 3000 USDC/WETH = 6 USDC
        assert!(
            (usdc_value - 6.0).abs() < 0.01,
            "USDC value should be approximately 6.0"
        );
    }

    #[test]
    fn test_calculate_principal_amount_usdc_internal_two() {
        let input_token_amount = BigInt::from_str("1000000000000").unwrap(); //1 unit 12 decimals

        let input_token_address =
            H160::from_str("0x0000000000000000000000000000000000000001").unwrap();
        let reference_token_address =
            H160::from_str("0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2").unwrap(); // WETH
        let usdc_token_address =
            H160::from_str("0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48").unwrap(); // USDC

        //   let input_token_price_to_reference = 0.002f64; // Example: 1 input token = 0.002 WETH
        //    let usdc_token_price_to_reference = 3000.0f64; // Example: 1 WETH = 3000 USDC

        //denom is always WETH , numerator is always the other token

        // 500 input tokens to 1 weth

        //make sure these make sense
        let input_token_price_to_reference = 0.0005f64; // 1 input token = 0.002 WETH (1e18 input units to 2e15 WETH units)
        let usdc_token_price_to_reference = 0.0000000030f64; // 1e18 WETH units = 3000e6 USDC units

        let input_token_decimals = 12;
        let reference_token_decimals = 18;
        let usdc_token_decimals = 6;

        let usdc_value = calculate_principal_amount_usdc_internal(
            input_token_amount,
            input_token_address,
            reference_token_address,
            usdc_token_address,
            input_token_price_to_reference,
            usdc_token_price_to_reference,
            input_token_decimals,
            reference_token_decimals,
            usdc_token_decimals,
        );

        println!("usdc value is {:?}", usdc_value);
        // Expected USDC value: 1 token * 0.002 WETH/token * 3000 USDC/WETH = 6 USDC
        assert!(
            (usdc_value - 6.0).abs() < 0.01,
            "USDC value should be approximately 6.0"
        );
    }

    #[test]
    fn test_calculate_principal_amount_usdc_internal_three() {
        let input_token_amount = BigInt::from_str("1000000000000000000").unwrap(); //1 unit 12 decimals

        let input_token_address =
            H160::from_str("0xf000000000000000000000000000000000000001").unwrap();
        let reference_token_address =
            H160::from_str("0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2").unwrap(); // WETH
        let usdc_token_address =
            H160::from_str("0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48").unwrap(); // USDC

        //   let input_token_price_to_reference = 0.002f64; // Example: 1 input token = 0.002 WETH
        //    let usdc_token_price_to_reference = 3000.0f64; // Example: 1 WETH = 3000 USDC

        //denom is always WETH , numerator is always the other token

        // 500 input tokens to 1 weth

        //make sure these make sense
        let input_token_price_to_reference = 0.002f64; // 1 input token = 0.002 WETH (1e18 input units to 2e15 WETH units)
        let usdc_token_price_to_reference = 0.0000000030f64; // 1e18 WETH units = 3000e6 USDC units

        let input_token_decimals = 18;
        let reference_token_decimals = 18;
        let usdc_token_decimals = 6;

        let usdc_value = calculate_principal_amount_usdc_internal(
            input_token_amount,
            input_token_address,
            reference_token_address,
            usdc_token_address,
            input_token_price_to_reference,
            usdc_token_price_to_reference,
            input_token_decimals,
            reference_token_decimals,
            usdc_token_decimals,
        );

        println!("usdc value is {:?}", usdc_value);
        // Expected USDC value: 1 token * 0.002 WETH/token * 3000 USDC/WETH = 6 USDC
        assert!(
            (usdc_value - 6.0).abs() < 0.01,
            "USDC value should be approximately 6.0"
        );
    }

    #[test]
    fn test_calculate_principal_amount_usdc_internal_four() {
        let input_token_amount = BigInt::from_str("1000000000").unwrap(); //1 unit 12 decimals

        let input_token_address =
            H160::from_str("0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48").unwrap();
        let reference_token_address =
            H160::from_str("0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2").unwrap(); // WETH
        let usdc_token_address =
            H160::from_str("0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48").unwrap(); // USDC

        //make sure these make sense
        let input_token_price_to_reference = 0.0000000030f64; // 1 input token = 0.002 WETH (1e18 input units to 2e15 WETH units)
        let usdc_token_price_to_reference = 0.0000000030f64; // 1e18 WETH units = 3000e6 USDC units

        let input_token_decimals = 6;
        let reference_token_decimals = 18;
        let usdc_token_decimals = 6;

        let usdc_value = calculate_principal_amount_usdc_internal(
            input_token_amount,
            input_token_address,
            reference_token_address,
            usdc_token_address,
            input_token_price_to_reference,
            usdc_token_price_to_reference,
            input_token_decimals,
            reference_token_decimals,
            usdc_token_decimals,
        );

        println!("usdc value is {:?}", usdc_value);
        // Expected USDC value: 1 token * 0.002 WETH/token * 3000 USDC/WETH = 6 USDC
        assert!(
            (usdc_value - 1000.0).abs() < 0.01,
            "USDC value should be approximately 6.0"
        );
    }

    fn bigint_to_f64(value: &BigInt) -> f64 {
        value.to_string().parse::<f64>().unwrap_or(0.0)
    }
}
