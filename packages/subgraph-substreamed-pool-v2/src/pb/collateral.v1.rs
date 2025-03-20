// @generated
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct Events {
    #[prost(message, repeated, tag="1")]
    pub collateral_manager_collateral_escrow_deployeds: ::prost::alloc::vec::Vec<CollateralmanagerCollateralEscrowDeployed>,
    #[prost(message, repeated, tag="2")]
    pub collateral_manager_collateral_deposited: ::prost::alloc::vec::Vec<CollateralmanagerCollateralDeposited>,
    #[prost(message, repeated, tag="3")]
    pub collateral_manager_collateral_withdrawn: ::prost::alloc::vec::Vec<CollateralmanagerCollateralWithdrawn>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct CollateralmanagerCollateralEscrowDeployed {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(uint64, tag="3")]
    pub evt_block_time: u64,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(string, tag="5")]
    pub bid_id: ::prost::alloc::string::String,
    #[prost(bytes="vec", tag="6")]
    pub collateral_escrow: ::prost::alloc::vec::Vec<u8>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct CollateralmanagerCollateralDeposited {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(uint64, tag="3")]
    pub evt_block_time: u64,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(string, tag="5")]
    pub bid_id: ::prost::alloc::string::String,
    #[prost(uint32, tag="6")]
    pub collateral_type: u32,
    #[prost(bytes="vec", tag="7")]
    pub collateral_address: ::prost::alloc::vec::Vec<u8>,
    #[prost(string, tag="8")]
    pub amount: ::prost::alloc::string::String,
    #[prost(string, tag="9")]
    pub token_id: ::prost::alloc::string::String,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct CollateralmanagerCollateralWithdrawn {
    #[prost(string, tag="1")]
    pub evt_tx_hash: ::prost::alloc::string::String,
    #[prost(uint32, tag="2")]
    pub evt_index: u32,
    #[prost(uint64, tag="3")]
    pub evt_block_time: u64,
    #[prost(uint64, tag="4")]
    pub evt_block_number: u64,
    #[prost(string, tag="5")]
    pub bid_id: ::prost::alloc::string::String,
    #[prost(uint32, tag="6")]
    pub collateral_type: u32,
    #[prost(bytes="vec", tag="7")]
    pub collateral_address: ::prost::alloc::vec::Vec<u8>,
    #[prost(string, tag="8")]
    pub amount: ::prost::alloc::string::String,
    #[prost(string, tag="9")]
    pub token_id: ::prost::alloc::string::String,
    #[prost(bytes="vec", tag="10")]
    pub recipient: ::prost::alloc::vec::Vec<u8>,
}
// @@protoc_insertion_point(module)
