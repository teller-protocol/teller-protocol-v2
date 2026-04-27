// @generated
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct Events {
    #[prost(message, repeated, tag="1")]
    pub teller_submitted_bids: ::prost::alloc::vec::Vec<TellerSubmittedBid>,
    #[prost(message, repeated, tag="2")]
    pub teller_accepted_bids: ::prost::alloc::vec::Vec<TellerAcceptedBid>,
    #[prost(message, repeated, tag="3")]
    pub teller_cancelled_bids: ::prost::alloc::vec::Vec<TellerCancelledBid>,
    #[prost(message, repeated, tag="4")]
    pub teller_loan_liquidateds: ::prost::alloc::vec::Vec<TellerLoanLiquidated>,
    #[prost(message, repeated, tag="5")]
    pub teller_loan_repayments: ::prost::alloc::vec::Vec<TellerLoanRepayment>,
    #[prost(message, repeated, tag="6")]
    pub teller_loan_repaids: ::prost::alloc::vec::Vec<TellerLoanRepaid>,
    #[prost(message, repeated, tag="7")]
    pub teller_fee_paids: ::prost::alloc::vec::Vec<TellerFeePaid>,
    #[prost(message, repeated, tag="8")]
    pub teller_market_owner_cancelled_bids: ::prost::alloc::vec::Vec<TellerMarketOwnerCancelledBid>,
    #[prost(message, repeated, tag="9")]
    pub teller_loan_closeds: ::prost::alloc::vec::Vec<TellerLoanClosed>,
    #[prost(message, repeated, tag="10")]
    pub teller_initializeds: ::prost::alloc::vec::Vec<TellerInitialized>,
    #[prost(message, repeated, tag="11")]
    pub teller_market_forwarder_approveds: ::prost::alloc::vec::Vec<TellerMarketForwarderApproved>,
    #[prost(message, repeated, tag="12")]
    pub teller_market_forwarder_renounceds: ::prost::alloc::vec::Vec<TellerMarketForwarderRenounced>,
    #[prost(message, repeated, tag="13")]
    pub teller_ownership_transferreds: ::prost::alloc::vec::Vec<TellerOwnershipTransferred>,
    #[prost(message, repeated, tag="14")]
    pub teller_pauseds: ::prost::alloc::vec::Vec<TellerPaused>,
    #[prost(message, repeated, tag="15")]
    pub teller_protocol_fee_sets: ::prost::alloc::vec::Vec<TellerProtocolFeeSet>,
    #[prost(message, repeated, tag="16")]
    pub teller_trusted_market_forwarder_sets: ::prost::alloc::vec::Vec<TellerTrustedMarketForwarderSet>,
    #[prost(message, repeated, tag="17")]
    pub teller_unpauseds: ::prost::alloc::vec::Vec<TellerUnpaused>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct TellerSubmittedBid {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(uint64, tag="3")]
    pub evt_block_time: u64,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(string, tag="5")]
    pub evt_address: ::prost::alloc::string::String,
    #[prost(string, tag="6")]
    pub bid_id: ::prost::alloc::string::String,
    #[prost(bytes="vec", tag="7")]
    pub borrower: ::prost::alloc::vec::Vec<u8>,
    #[prost(bytes="vec", tag="8")]
    pub receiver: ::prost::alloc::vec::Vec<u8>,
    #[prost(bytes="vec", tag="9")]
    pub metadata_uri: ::prost::alloc::vec::Vec<u8>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct TellerAcceptedBid {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(uint64, tag="3")]
    pub evt_block_time: u64,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(string, tag="5")]
    pub evt_address: ::prost::alloc::string::String,
    #[prost(string, tag="6")]
    pub bid_id: ::prost::alloc::string::String,
    #[prost(bytes="vec", tag="7")]
    pub lender: ::prost::alloc::vec::Vec<u8>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct TellerCancelledBid {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(uint64, tag="3")]
    pub evt_block_time: u64,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(string, tag="5")]
    pub evt_address: ::prost::alloc::string::String,
    #[prost(string, tag="6")]
    pub bid_id: ::prost::alloc::string::String,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct TellerLoanLiquidated {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(uint64, tag="3")]
    pub evt_block_time: u64,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(string, tag="5")]
    pub evt_address: ::prost::alloc::string::String,
    #[prost(string, tag="6")]
    pub bid_id: ::prost::alloc::string::String,
    #[prost(bytes="vec", tag="7")]
    pub liquidator: ::prost::alloc::vec::Vec<u8>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct TellerLoanRepayment {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(uint64, tag="3")]
    pub evt_block_time: u64,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(string, tag="5")]
    pub evt_address: ::prost::alloc::string::String,
    #[prost(string, tag="6")]
    pub bid_id: ::prost::alloc::string::String,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct TellerLoanRepaid {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(uint64, tag="3")]
    pub evt_block_time: u64,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(string, tag="5")]
    pub evt_address: ::prost::alloc::string::String,
    #[prost(string, tag="6")]
    pub bid_id: ::prost::alloc::string::String,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct TellerFeePaid {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(uint64, tag="3")]
    pub evt_block_time: u64,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(string, tag="5")]
    pub evt_address: ::prost::alloc::string::String,
    #[prost(string, tag="6")]
    pub bid_id: ::prost::alloc::string::String,
    #[prost(string, tag="7")]
    pub fee_type: ::prost::alloc::string::String,
    #[prost(string, tag="8")]
    pub amount: ::prost::alloc::string::String,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct TellerMarketOwnerCancelledBid {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(uint64, tag="3")]
    pub evt_block_time: u64,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(string, tag="5")]
    pub evt_address: ::prost::alloc::string::String,
    #[prost(string, tag="6")]
    pub bid_id: ::prost::alloc::string::String,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct TellerLoanClosed {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(uint64, tag="3")]
    pub evt_block_time: u64,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(string, tag="5")]
    pub evt_address: ::prost::alloc::string::String,
    #[prost(string, tag="6")]
    pub bid_id: ::prost::alloc::string::String,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct TellerInitialized {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(uint64, tag="3")]
    pub evt_block_time: u64,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(string, tag="5")]
    pub evt_address: ::prost::alloc::string::String,
    #[prost(string, tag="6")]
    pub version: ::prost::alloc::string::String,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct TellerMarketForwarderApproved {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(uint64, tag="3")]
    pub evt_block_time: u64,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(string, tag="5")]
    pub evt_address: ::prost::alloc::string::String,
    #[prost(string, tag="6")]
    pub market_id: ::prost::alloc::string::String,
    #[prost(bytes="vec", tag="7")]
    pub forwarder: ::prost::alloc::vec::Vec<u8>,
    #[prost(bytes="vec", tag="8")]
    pub sender: ::prost::alloc::vec::Vec<u8>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct TellerMarketForwarderRenounced {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(uint64, tag="3")]
    pub evt_block_time: u64,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(string, tag="5")]
    pub evt_address: ::prost::alloc::string::String,
    #[prost(string, tag="6")]
    pub market_id: ::prost::alloc::string::String,
    #[prost(bytes="vec", tag="7")]
    pub forwarder: ::prost::alloc::vec::Vec<u8>,
    #[prost(bytes="vec", tag="8")]
    pub sender: ::prost::alloc::vec::Vec<u8>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct TellerOwnershipTransferred {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(uint64, tag="3")]
    pub evt_block_time: u64,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(string, tag="5")]
    pub evt_address: ::prost::alloc::string::String,
    #[prost(bytes="vec", tag="6")]
    pub previous_owner: ::prost::alloc::vec::Vec<u8>,
    #[prost(bytes="vec", tag="7")]
    pub new_owner: ::prost::alloc::vec::Vec<u8>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct TellerPaused {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(uint64, tag="3")]
    pub evt_block_time: u64,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(string, tag="5")]
    pub evt_address: ::prost::alloc::string::String,
    #[prost(bytes="vec", tag="6")]
    pub account: ::prost::alloc::vec::Vec<u8>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct TellerProtocolFeeSet {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(uint64, tag="3")]
    pub evt_block_time: u64,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(string, tag="5")]
    pub evt_address: ::prost::alloc::string::String,
    #[prost(string, tag="6")]
    pub new_fee: ::prost::alloc::string::String,
    #[prost(string, tag="7")]
    pub old_fee: ::prost::alloc::string::String,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct TellerTrustedMarketForwarderSet {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(uint64, tag="3")]
    pub evt_block_time: u64,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(string, tag="5")]
    pub evt_address: ::prost::alloc::string::String,
    #[prost(string, tag="6")]
    pub market_id: ::prost::alloc::string::String,
    #[prost(bytes="vec", tag="7")]
    pub forwarder: ::prost::alloc::vec::Vec<u8>,
    #[prost(bytes="vec", tag="8")]
    pub sender: ::prost::alloc::vec::Vec<u8>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct TellerUnpaused {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(uint64, tag="3")]
    pub evt_block_time: u64,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(string, tag="5")]
    pub evt_address: ::prost::alloc::string::String,
    #[prost(bytes="vec", tag="6")]
    pub account: ::prost::alloc::vec::Vec<u8>,
}
// @@protoc_insertion_point(module)
