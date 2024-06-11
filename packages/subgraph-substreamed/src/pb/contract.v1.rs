// @generated
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct Events {
    #[prost(message, repeated, tag="1")]
    pub fac_admin_changeds: ::prost::alloc::vec::Vec<FacAdminChanged>,
    #[prost(message, repeated, tag="2")]
    pub fac_beacon_upgradeds: ::prost::alloc::vec::Vec<FacBeaconUpgraded>,
    #[prost(message, repeated, tag="3")]
    pub fac_deployed_lender_group_contracts: ::prost::alloc::vec::Vec<FacDeployedLenderGroupContract>,
    #[prost(message, repeated, tag="4")]
    pub fac_upgradeds: ::prost::alloc::vec::Vec<FacUpgraded>,
    #[prost(message, repeated, tag="5")]
    pub groupp_borrower_accepted_funds: ::prost::alloc::vec::Vec<GrouppBorrowerAcceptedFunds>,
    #[prost(message, repeated, tag="6")]
    pub groupp_defaulted_loan_liquidateds: ::prost::alloc::vec::Vec<GrouppDefaultedLoanLiquidated>,
    #[prost(message, repeated, tag="7")]
    pub groupp_earnings_withdrawns: ::prost::alloc::vec::Vec<GrouppEarningsWithdrawn>,
    #[prost(message, repeated, tag="8")]
    pub groupp_initializeds: ::prost::alloc::vec::Vec<GrouppInitialized>,
    #[prost(message, repeated, tag="9")]
    pub groupp_lender_added_principals: ::prost::alloc::vec::Vec<GrouppLenderAddedPrincipal>,
    #[prost(message, repeated, tag="10")]
    pub groupp_loan_repaids: ::prost::alloc::vec::Vec<GrouppLoanRepaid>,
    #[prost(message, repeated, tag="11")]
    pub groupp_ownership_transferreds: ::prost::alloc::vec::Vec<GrouppOwnershipTransferred>,
    #[prost(message, repeated, tag="12")]
    pub groupp_pauseds: ::prost::alloc::vec::Vec<GrouppPaused>,
    #[prost(message, repeated, tag="13")]
    pub groupp_pool_initializeds: ::prost::alloc::vec::Vec<GrouppPoolInitialized>,
    #[prost(message, repeated, tag="14")]
    pub groupp_unpauseds: ::prost::alloc::vec::Vec<GrouppUnpaused>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct FacAdminChanged {
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
pub struct FacBeaconUpgraded {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(message, optional, tag="3")]
    pub evt_block_time: ::core::option::Option<::prost_types::Timestamp>,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(bytes="vec", tag="5")]
    pub beacon: ::prost::alloc::vec::Vec<u8>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct FacDeployedLenderGroupContract {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(message, optional, tag="3")]
    pub evt_block_time: ::core::option::Option<::prost_types::Timestamp>,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(bytes="vec", tag="5")]
    pub group_contract: ::prost::alloc::vec::Vec<u8>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct FacUpgraded {
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
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct GrouppBorrowerAcceptedFunds {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(message, optional, tag="3")]
    pub evt_block_time: ::core::option::Option<::prost_types::Timestamp>,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(string, tag="5")]
    pub evt_address: ::prost::alloc::string::String,
    #[prost(bytes="vec", tag="6")]
    pub borrower: ::prost::alloc::vec::Vec<u8>,
    #[prost(string, tag="7")]
    pub bid_id: ::prost::alloc::string::String,
    #[prost(string, tag="8")]
    pub principal_amount: ::prost::alloc::string::String,
    #[prost(string, tag="9")]
    pub collateral_amount: ::prost::alloc::string::String,
    #[prost(uint64, tag="10")]
    pub loan_duration: u64,
    #[prost(uint64, tag="11")]
    pub interest_rate: u64,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct GrouppDefaultedLoanLiquidated {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(message, optional, tag="3")]
    pub evt_block_time: ::core::option::Option<::prost_types::Timestamp>,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(string, tag="5")]
    pub evt_address: ::prost::alloc::string::String,
    #[prost(string, tag="6")]
    pub bid_id: ::prost::alloc::string::String,
    #[prost(bytes="vec", tag="7")]
    pub liquidator: ::prost::alloc::vec::Vec<u8>,
    #[prost(string, tag="8")]
    pub amount_due: ::prost::alloc::string::String,
    #[prost(string, tag="9")]
    pub token_amount_difference: ::prost::alloc::string::String,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct GrouppEarningsWithdrawn {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(message, optional, tag="3")]
    pub evt_block_time: ::core::option::Option<::prost_types::Timestamp>,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(string, tag="5")]
    pub evt_address: ::prost::alloc::string::String,
    #[prost(bytes="vec", tag="6")]
    pub lender: ::prost::alloc::vec::Vec<u8>,
    #[prost(string, tag="7")]
    pub amount_pool_shares_tokens: ::prost::alloc::string::String,
    #[prost(string, tag="8")]
    pub principal_tokens_withdrawn: ::prost::alloc::string::String,
    #[prost(bytes="vec", tag="9")]
    pub recipient: ::prost::alloc::vec::Vec<u8>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct GrouppInitialized {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(message, optional, tag="3")]
    pub evt_block_time: ::core::option::Option<::prost_types::Timestamp>,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(string, tag="5")]
    pub evt_address: ::prost::alloc::string::String,
    #[prost(uint64, tag="6")]
    pub version: u64,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct GrouppLenderAddedPrincipal {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(message, optional, tag="3")]
    pub evt_block_time: ::core::option::Option<::prost_types::Timestamp>,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(string, tag="5")]
    pub evt_address: ::prost::alloc::string::String,
    #[prost(bytes="vec", tag="6")]
    pub lender: ::prost::alloc::vec::Vec<u8>,
    #[prost(string, tag="7")]
    pub amount: ::prost::alloc::string::String,
    #[prost(string, tag="8")]
    pub shares_amount: ::prost::alloc::string::String,
    #[prost(bytes="vec", tag="9")]
    pub shares_recipient: ::prost::alloc::vec::Vec<u8>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct GrouppLoanRepaid {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(message, optional, tag="3")]
    pub evt_block_time: ::core::option::Option<::prost_types::Timestamp>,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(string, tag="5")]
    pub evt_address: ::prost::alloc::string::String,
    #[prost(string, tag="6")]
    pub bid_id: ::prost::alloc::string::String,
    #[prost(bytes="vec", tag="7")]
    pub repayer: ::prost::alloc::vec::Vec<u8>,
    #[prost(string, tag="8")]
    pub principal_amount: ::prost::alloc::string::String,
    #[prost(string, tag="9")]
    pub interest_amount: ::prost::alloc::string::String,
    #[prost(string, tag="10")]
    pub total_principal_repaid: ::prost::alloc::string::String,
    #[prost(string, tag="11")]
    pub total_interest_collected: ::prost::alloc::string::String,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct GrouppOwnershipTransferred {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(message, optional, tag="3")]
    pub evt_block_time: ::core::option::Option<::prost_types::Timestamp>,
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
pub struct GrouppPaused {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(message, optional, tag="3")]
    pub evt_block_time: ::core::option::Option<::prost_types::Timestamp>,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(string, tag="5")]
    pub evt_address: ::prost::alloc::string::String,
    #[prost(bytes="vec", tag="6")]
    pub account: ::prost::alloc::vec::Vec<u8>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct GrouppPoolInitialized {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(message, optional, tag="3")]
    pub evt_block_time: ::core::option::Option<::prost_types::Timestamp>,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(string, tag="5")]
    pub evt_address: ::prost::alloc::string::String,
    #[prost(bytes="vec", tag="6")]
    pub principal_token_address: ::prost::alloc::vec::Vec<u8>,
    #[prost(bytes="vec", tag="7")]
    pub collateral_token_address: ::prost::alloc::vec::Vec<u8>,
    #[prost(string, tag="8")]
    pub market_id: ::prost::alloc::string::String,
    #[prost(uint64, tag="9")]
    pub max_loan_duration: u64,
    #[prost(uint64, tag="10")]
    pub interest_rate_lower_bound: u64,
    #[prost(uint64, tag="11")]
    pub interest_rate_upper_bound: u64,
    #[prost(uint64, tag="12")]
    pub liquidity_threshold_percent: u64,
    #[prost(uint64, tag="13")]
    pub loan_to_value_percent: u64,
    #[prost(uint64, tag="14")]
    pub uniswap_pool_fee: u64,
    #[prost(uint64, tag="15")]
    pub twap_interval: u64,
    #[prost(bytes="vec", tag="16")]
    pub pool_shares_token: ::prost::alloc::vec::Vec<u8>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct GrouppUnpaused {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(message, optional, tag="3")]
    pub evt_block_time: ::core::option::Option<::prost_types::Timestamp>,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(string, tag="5")]
    pub evt_address: ::prost::alloc::string::String,
    #[prost(bytes="vec", tag="6")]
    pub account: ::prost::alloc::vec::Vec<u8>,
}
// @@protoc_insertion_point(module)
