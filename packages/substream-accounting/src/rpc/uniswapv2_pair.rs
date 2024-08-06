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


/*

Token Order: In the Uniswap V2 pair contract, the token addresses are stored in sorted order. Specifically, token0 and token1 are set such that token0 has a smaller address value than token1. This order is consistent and does not depend on the reserves or any other runtime state.

Reserves Mapping: The reserve0 value always corresponds to token0, and reserve1 corresponds to token1. Thus, if you know the tokens in the pair, you can determine which reserve corresponds to which token.

*/
impl ReservesData{
    
    pub fn get_price_ratio(&self) -> f64 {
        let reserve0:f64 = self.reserve0.into();
        let reserve1:f64 = self.reserve1.into();
        if reserve0 == 0.0 {
            return 0.0; // Avoid division by zero
        }
        reserve1 / reserve0
        
        
    }
    
}

//const UNISWAP_V2_PAIR_ADDRESS: &str = "YOUR_UNISWAP_V2_PAIR_ADDRESS_HERE";

// Function to fetch the reserves from a Uniswap V2 pair contract
pub fn fetch_reserves_from_pair(pair_address: &Address) -> Option<ReservesData> {
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
