// @generated
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct TokenPrices {
    #[prost(message, repeated, tag="1")]
    pub tokens: ::prost::alloc::vec::Vec<TokenPrice>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct TokenPrice {
    #[prost(string, tag="1")]
    pub token: ::prost::alloc::string::String,
    #[prost(string, tag="2")]
    pub price_usd: ::prost::alloc::string::String,
    #[prost(string, tag="3")]
    pub timestamp: ::prost::alloc::string::String,
}
// @@protoc_insertion_point(module)
