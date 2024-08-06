use crate::{abi, eth};
use ethabi::Address;
use ethabi::ethereum_types::H160;
use prost::Message;

use substreams::log;
use substreams::scalar::BigInt;
use substreams::Hex;
use substreams_ethereum::rpc::RpcBatch;
use hex_literal::hex;

// Struct to store the reserves and timestamp returned by getReserves
pub struct ReservesData {
    pub reserve0: BigInt,
    pub reserve1: BigInt,
    pub block_timestamp_last: BigInt,
}

//const UNISWAP_V2_PAIR_ADDRESS: &str = "YOUR_UNISWAP_V2_PAIR_ADDRESS_HERE";

// Function to fetch the reserves from a Uniswap V2 pair contract
pub fn fetch_reserves_from_rpc(pair_address: &Address) -> Option<ReservesData> {
    let pair_address_decoded = Hex::decode( pair_address ).unwrap();

    // Define the getReserves function call
    let get_reserves_function = abi::uniswapv2_pair::functions::GetReserves {};

    // Call the getReserves function and fetch the reserves data
    if let Some((reserve0, reserve1, block_timestamp_last)) = get_reserves_function.call(pair_address_decoded.clone()) {
        return Some(ReservesData {
            reserve0: BigInt::from(reserve0),
            reserve1: BigInt::from(reserve1),
            block_timestamp_last: BigInt::from(block_timestamp_last),
        });
    }

    None
}
