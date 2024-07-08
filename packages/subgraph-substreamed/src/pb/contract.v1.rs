// @generated
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct Events {
    #[prost(message, repeated, tag="1")]
    pub factory_admin_changeds: ::prost::alloc::vec::Vec<FactoryAdminChanged>,
    #[prost(message, repeated, tag="2")]
    pub factory_beacon_upgradeds: ::prost::alloc::vec::Vec<FactoryBeaconUpgraded>,
    #[prost(message, repeated, tag="3")]
    pub factory_deployed_lender_group_contracts: ::prost::alloc::vec::Vec<FactoryDeployedLenderGroupContract>,
    #[prost(message, repeated, tag="4")]
    pub factory_upgradeds: ::prost::alloc::vec::Vec<FactoryUpgraded>,
    #[prost(message, repeated, tag="5")]
    pub lendergroup_borrower_accepted_funds: ::prost::alloc::vec::Vec<LendergroupBorrowerAcceptedFunds>,
    #[prost(message, repeated, tag="6")]
    pub lendergroup_defaulted_loan_liquidateds: ::prost::alloc::vec::Vec<LendergroupDefaultedLoanLiquidated>,
    #[prost(message, repeated, tag="7")]
    pub lendergroup_earnings_withdrawns: ::prost::alloc::vec::Vec<LendergroupEarningsWithdrawn>,
    #[prost(message, repeated, tag="8")]
    pub lendergroup_initializeds: ::prost::alloc::vec::Vec<LendergroupInitialized>,
    #[prost(message, repeated, tag="9")]
    pub lendergroup_lender_added_principals: ::prost::alloc::vec::Vec<LendergroupLenderAddedPrincipal>,
    #[prost(message, repeated, tag="10")]
    pub lendergroup_loan_repaids: ::prost::alloc::vec::Vec<LendergroupLoanRepaid>,
    #[prost(message, repeated, tag="11")]
    pub lendergroup_ownership_transferreds: ::prost::alloc::vec::Vec<LendergroupOwnershipTransferred>,
    #[prost(message, repeated, tag="12")]
    pub lendergroup_pauseds: ::prost::alloc::vec::Vec<LendergroupPaused>,
    #[prost(message, repeated, tag="13")]
    pub lendergroup_pool_initializeds: ::prost::alloc::vec::Vec<LendergroupPoolInitialized>,
    #[prost(message, repeated, tag="14")]
    pub lendergroup_unpauseds: ::prost::alloc::vec::Vec<LendergroupUnpaused>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct FactoryAdminChanged {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(uint64, tag="3")]
    pub evt_block_time: u64,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(bytes="vec", tag="5")]
    pub previous_admin: ::prost::alloc::vec::Vec<u8>,
    #[prost(bytes="vec", tag="6")]
    pub new_admin: ::prost::alloc::vec::Vec<u8>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct FactoryBeaconUpgraded {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(uint64, tag="3")]
    pub evt_block_time: u64,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(bytes="vec", tag="5")]
    pub beacon: ::prost::alloc::vec::Vec<u8>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct FactoryDeployedLenderGroupContract {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(uint64, tag="3")]
    pub evt_block_time: u64,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(bytes="vec", tag="5")]
    pub group_contract: ::prost::alloc::vec::Vec<u8>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct FactoryUpgraded {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(uint64, tag="3")]
    pub evt_block_time: u64,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(bytes="vec", tag="5")]
    pub implementation: ::prost::alloc::vec::Vec<u8>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct LendergroupBorrowerAcceptedFunds {
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
pub struct LendergroupDefaultedLoanLiquidated {
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
    #[prost(string, tag="8")]
    pub amount_due: ::prost::alloc::string::String,
    #[prost(string, tag="9")]
    pub token_amount_difference: ::prost::alloc::string::String,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct LendergroupEarningsWithdrawn {
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
pub struct LendergroupInitialized {
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
    #[prost(uint64, tag="6")]
    pub version: u64,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct LendergroupLenderAddedPrincipal {
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
pub struct LendergroupLoanRepaid {
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
pub struct LendergroupOwnershipTransferred {
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
pub struct LendergroupPaused {
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
pub struct LendergroupPoolInitialized {
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
    #[prost(bytes="vec", tag="17")]
    pub uniswap_v3_pool_address: ::prost::alloc::vec::Vec<u8>,
    #[prost(bytes="vec", tag="18")]
    pub teller_v2_address: ::prost::alloc::vec::Vec<u8>,
    #[prost(bytes="vec", tag="19")]
    pub smart_commitment_forwarder_address: ::prost::alloc::vec::Vec<u8>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct LendergroupUnpaused {
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
