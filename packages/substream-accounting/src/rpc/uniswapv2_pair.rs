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
    
    //ASSUME we are going pepe   0x4dFae3690b93c47470b03036A17B23C1Be05127C
    
    
    
    //ASSUME we are doing usdc ...  usdc will be 0  and  weth will be 1 
    
    //ASSUME uninverted means that   reserve 0 is input token and  reserve 1  is reference ... usdc is uninverted 
    
    /*
        
        "id": "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
        "base_token_address": "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
        "reference_token_address": "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",
        "price_ratio": "434359356.79825205"  ->   reserveWeth  /  reserveUSDC   need to mul by 10^6   
    */
    
    pub fn get_price_ratio(&self) -> f64 {
        let reserve0 = bigint_to_f64(&self.reserve0);
        let reserve1 = bigint_to_f64(&self.reserve1);
        if reserve0 == 0.0 {
            return 0.0; // Avoid division by zero
        }
        reserve1 / reserve0
        
        
    }
    
}

 fn bigint_to_f64( value: &BigInt ) -> f64 {
        value.to_string().parse::<f64>().unwrap_or(0.0)
}

//const UNISWAP_V2_PAIR_ADDRESS: &str = "YOUR_UNISWAP_V2_PAIR_ADDRESS_HERE";

// Function to fetch the reserves from a Uniswap V2 pair contract
pub fn fetch_reserves_from_pair(pair_address: &Address) -> Option<ReservesData> {
    //let pair_address_decoded = Hex::decode( pair_address ).unwrap();
    
     let pair_address_bytes = pair_address.as_bytes().to_vec();

   
    
    // Define the getReserves function call
    let get_reserves_function = abi::uniswapv2_pair::functions::GetReserves {};

    // Call the getReserves function and fetch the reserves data
    if let Some((reserve0, reserve1, block_timestamp_last)) = get_reserves_function.call( pair_address_bytes.clone()) {
        return Some(ReservesData {
            reserve0: BigInt::from(reserve0),
            reserve1: BigInt::from(reserve1),
            block_timestamp_last: BigInt::from(block_timestamp_last),
        });
    }

    None
}
