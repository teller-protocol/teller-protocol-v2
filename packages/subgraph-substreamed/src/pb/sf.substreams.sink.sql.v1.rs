// @generated
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct Service {
    /// Containing both create table statements and index creation statements.
    #[prost(string, tag="1")]
    pub schema: ::prost::alloc::string::String,
    #[prost(message, optional, tag="2")]
    pub dbt_config: ::core::option::Option<DbtConfig>,
    #[prost(message, optional, tag="4")]
    pub hasura_frontend: ::core::option::Option<HasuraFrontend>,
    #[prost(message, optional, tag="5")]
    pub postgraphile_frontend: ::core::option::Option<PostgraphileFrontend>,
    #[prost(enumeration="service::Engine", tag="7")]
    pub engine: i32,
    #[prost(message, optional, tag="8")]
    pub rest_frontend: ::core::option::Option<RestFrontend>,
}
/// Nested message and enum types in `Service`.
pub mod service {
    #[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, ::prost::Enumeration)]
    #[repr(i32)]
    pub enum Engine {
        Unset = 0,
        Postgres = 1,
        Clickhouse = 2,
    }
    impl Engine {
        /// String value of the enum field names used in the ProtoBuf definition.
        ///
        /// The values are not transformed in any way and thus are considered stable
        /// (if the ProtoBuf definition does not change) and safe for programmatic use.
        pub fn as_str_name(&self) -> &'static str {
            match self {
                Engine::Unset => "unset",
                Engine::Postgres => "postgres",
                Engine::Clickhouse => "clickhouse",
            }
        }
        /// Creates an enum from field names used in the ProtoBuf definition.
        pub fn from_str_name(value: &str) -> ::core::option::Option<Self> {
            match value {
                "unset" => Some(Self::Unset),
                "postgres" => Some(Self::Postgres),
                "clickhouse" => Some(Self::Clickhouse),
                _ => None,
            }
        }
    }
}
/// <https://www.getdbt.com/product/what-is-dbt>
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct DbtConfig {
    #[prost(bytes="vec", tag="1")]
    pub files: ::prost::alloc::vec::Vec<u8>,
    #[prost(int32, tag="2")]
    pub run_interval_seconds: i32,
    #[prost(bool, tag="3")]
    pub enabled: bool,
}
/// <https://hasura.io/docs/latest/index/>
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct HasuraFrontend {
    #[prost(bool, tag="1")]
    pub enabled: bool,
}
/// <https://www.graphile.org/postgraphile/>
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct PostgraphileFrontend {
    #[prost(bool, tag="1")]
    pub enabled: bool,
}
/// <https://github.com/sosedoff/pgweb>
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct PgWebFrontend {
    #[prost(bool, tag="1")]
    pub enabled: bool,
}
/// <https://github.com/semiotic-ai/sql-wrapper>
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct RestFrontend {
    #[prost(bool, tag="1")]
    pub enabled: bool,
}
// @@protoc_insertion_point(module)
