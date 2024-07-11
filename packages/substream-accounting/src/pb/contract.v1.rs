// @generated
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct Events {
    #[prost(message, repeated, tag="1")]
    pub tellerv2_accepted_bids: ::prost::alloc::vec::Vec<Tellerv2AcceptedBid>,
    #[prost(message, repeated, tag="2")]
    pub tellerv2_admin_changeds: ::prost::alloc::vec::Vec<Tellerv2AdminChanged>,
    #[prost(message, repeated, tag="3")]
    pub tellerv2_cancelled_bids: ::prost::alloc::vec::Vec<Tellerv2CancelledBid>,
    #[prost(message, repeated, tag="4")]
    pub tellerv2_fee_paids: ::prost::alloc::vec::Vec<Tellerv2FeePaid>,
    #[prost(message, repeated, tag="5")]
    pub tellerv2_initializeds: ::prost::alloc::vec::Vec<Tellerv2Initialized>,
    #[prost(message, repeated, tag="6")]
    pub tellerv2_loan_liquidateds: ::prost::alloc::vec::Vec<Tellerv2LoanLiquidated>,
    #[prost(message, repeated, tag="7")]
    pub tellerv2_loan_repaids: ::prost::alloc::vec::Vec<Tellerv2LoanRepaid>,
    #[prost(message, repeated, tag="8")]
    pub tellerv2_loan_repayments: ::prost::alloc::vec::Vec<Tellerv2LoanRepayment>,
    #[prost(message, repeated, tag="9")]
    pub tellerv2_market_forwarder_approveds: ::prost::alloc::vec::Vec<Tellerv2MarketForwarderApproved>,
    #[prost(message, repeated, tag="10")]
    pub tellerv2_market_forwarder_renounceds: ::prost::alloc::vec::Vec<Tellerv2MarketForwarderRenounced>,
    #[prost(message, repeated, tag="11")]
    pub tellerv2_market_owner_cancelled_bids: ::prost::alloc::vec::Vec<Tellerv2MarketOwnerCancelledBid>,
    #[prost(message, repeated, tag="12")]
    pub tellerv2_ownership_transferreds: ::prost::alloc::vec::Vec<Tellerv2OwnershipTransferred>,
    #[prost(message, repeated, tag="13")]
    pub tellerv2_pauseds: ::prost::alloc::vec::Vec<Tellerv2Paused>,
    #[prost(message, repeated, tag="14")]
    pub tellerv2_protocol_fee_sets: ::prost::alloc::vec::Vec<Tellerv2ProtocolFeeSet>,
    #[prost(message, repeated, tag="15")]
    pub tellerv2_submitted_bids: ::prost::alloc::vec::Vec<Tellerv2SubmittedBid>,
    #[prost(message, repeated, tag="16")]
    pub tellerv2_trusted_market_forwarder_sets: ::prost::alloc::vec::Vec<Tellerv2TrustedMarketForwarderSet>,
    #[prost(message, repeated, tag="17")]
    pub tellerv2_unpauseds: ::prost::alloc::vec::Vec<Tellerv2Unpaused>,
    #[prost(message, repeated, tag="18")]
    pub tellerv2_upgradeds: ::prost::alloc::vec::Vec<Tellerv2Upgraded>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct Tellerv2AcceptedBid {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(message, optional, tag="3")]
    pub evt_block_time: ::core::option::Option<::prost_types::Timestamp>,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(string, tag="5")]
    pub bid_id: ::prost::alloc::string::String,
    #[prost(bytes="vec", tag="6")]
    pub lender: ::prost::alloc::vec::Vec<u8>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct Tellerv2AdminChanged {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(message, optional, tag="3")]
    pub evt_block_time: ::core::option::Option<::prost_types::Timestamp>,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(bytes="vec", tag="5")]
    pub previous_admin: ::prost::alloc::vec::Vec<u8>,
    #[prost(bytes="vec", tag="6")]
    pub new_admin: ::prost::alloc::vec::Vec<u8>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct Tellerv2CancelledBid {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(message, optional, tag="3")]
    pub evt_block_time: ::core::option::Option<::prost_types::Timestamp>,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(string, tag="5")]
    pub bid_id: ::prost::alloc::string::String,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct Tellerv2FeePaid {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(message, optional, tag="3")]
    pub evt_block_time: ::core::option::Option<::prost_types::Timestamp>,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(string, tag="5")]
    pub bid_id: ::prost::alloc::string::String,
    #[prost(string, tag="6")]
    pub fee_type: ::prost::alloc::string::String,
    #[prost(string, tag="7")]
    pub amount: ::prost::alloc::string::String,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct Tellerv2Initialized {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(message, optional, tag="3")]
    pub evt_block_time: ::core::option::Option<::prost_types::Timestamp>,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(uint64, tag="5")]
    pub version: u64,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct Tellerv2LoanLiquidated {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(message, optional, tag="3")]
    pub evt_block_time: ::core::option::Option<::prost_types::Timestamp>,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(string, tag="5")]
    pub bid_id: ::prost::alloc::string::String,
    #[prost(bytes="vec", tag="6")]
    pub liquidator: ::prost::alloc::vec::Vec<u8>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct Tellerv2LoanRepaid {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(message, optional, tag="3")]
    pub evt_block_time: ::core::option::Option<::prost_types::Timestamp>,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(string, tag="5")]
    pub bid_id: ::prost::alloc::string::String,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct Tellerv2LoanRepayment {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(message, optional, tag="3")]
    pub evt_block_time: ::core::option::Option<::prost_types::Timestamp>,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(string, tag="5")]
    pub bid_id: ::prost::alloc::string::String,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct Tellerv2MarketForwarderApproved {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(message, optional, tag="3")]
    pub evt_block_time: ::core::option::Option<::prost_types::Timestamp>,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(string, tag="5")]
    pub market_id: ::prost::alloc::string::String,
    #[prost(bytes="vec", tag="6")]
    pub forwarder: ::prost::alloc::vec::Vec<u8>,
    #[prost(bytes="vec", tag="7")]
    pub sender: ::prost::alloc::vec::Vec<u8>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct Tellerv2MarketForwarderRenounced {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(message, optional, tag="3")]
    pub evt_block_time: ::core::option::Option<::prost_types::Timestamp>,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(string, tag="5")]
    pub market_id: ::prost::alloc::string::String,
    #[prost(bytes="vec", tag="6")]
    pub forwarder: ::prost::alloc::vec::Vec<u8>,
    #[prost(bytes="vec", tag="7")]
    pub sender: ::prost::alloc::vec::Vec<u8>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct Tellerv2MarketOwnerCancelledBid {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(message, optional, tag="3")]
    pub evt_block_time: ::core::option::Option<::prost_types::Timestamp>,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(string, tag="5")]
    pub bid_id: ::prost::alloc::string::String,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct Tellerv2OwnershipTransferred {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(message, optional, tag="3")]
    pub evt_block_time: ::core::option::Option<::prost_types::Timestamp>,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(bytes="vec", tag="5")]
    pub previous_owner: ::prost::alloc::vec::Vec<u8>,
    #[prost(bytes="vec", tag="6")]
    pub new_owner: ::prost::alloc::vec::Vec<u8>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct Tellerv2Paused {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(message, optional, tag="3")]
    pub evt_block_time: ::core::option::Option<::prost_types::Timestamp>,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(bytes="vec", tag="5")]
    pub account: ::prost::alloc::vec::Vec<u8>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct Tellerv2ProtocolFeeSet {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(message, optional, tag="3")]
    pub evt_block_time: ::core::option::Option<::prost_types::Timestamp>,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(uint64, tag="5")]
    pub new_fee: u64,
    #[prost(uint64, tag="6")]
    pub old_fee: u64,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct Tellerv2SubmittedBid {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(message, optional, tag="3")]
    pub evt_block_time: ::core::option::Option<::prost_types::Timestamp>,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(string, tag="5")]
    pub bid_id: ::prost::alloc::string::String,
    #[prost(bytes="vec", tag="6")]
    pub borrower: ::prost::alloc::vec::Vec<u8>,
    #[prost(bytes="vec", tag="7")]
    pub receiver: ::prost::alloc::vec::Vec<u8>,
    #[prost(bytes="vec", tag="8")]
    pub metadata_uri: ::prost::alloc::vec::Vec<u8>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct Tellerv2TrustedMarketForwarderSet {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(message, optional, tag="3")]
    pub evt_block_time: ::core::option::Option<::prost_types::Timestamp>,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(string, tag="5")]
    pub market_id: ::prost::alloc::string::String,
    #[prost(bytes="vec", tag="6")]
    pub forwarder: ::prost::alloc::vec::Vec<u8>,
    #[prost(bytes="vec", tag="7")]
    pub sender: ::prost::alloc::vec::Vec<u8>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct Tellerv2Unpaused {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(message, optional, tag="3")]
    pub evt_block_time: ::core::option::Option<::prost_types::Timestamp>,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(bytes="vec", tag="5")]
    pub account: ::prost::alloc::vec::Vec<u8>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct Tellerv2Upgraded {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(message, optional, tag="3")]
    pub evt_block_time: ::core::option::Option<::prost_types::Timestamp>,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(bytes="vec", tag="5")]
    pub implementation: ::prost::alloc::vec::Vec<u8>,
}
// @@protoc_insertion_point(module)
