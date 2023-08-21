// @generated
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct TokenPrice {
    #[prost(string, tag="1")]
    pub token: ::prost::alloc::string::String,
    #[prost(string, tag="2")]
    pub price_usd: ::prost::alloc::string::String,
    #[prost(uint64, tag="3")]
    pub timestamp: u64,
}
// @@protoc_insertion_point(module)
