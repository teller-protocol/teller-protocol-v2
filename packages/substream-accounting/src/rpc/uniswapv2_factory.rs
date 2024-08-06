use crate::{abi, eth};
use ethabi::Address;
use ethabi::ethereum_types::H160;
use prost::Message;

use substreams::log;
use substreams::scalar::BigInt;
use substreams::Hex;
use substreams_ethereum::rpc::RpcBatch;
use hex_literal::hex;


///sample pair 
// https://etherscan.io/address/0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc#code


// Struct to store the pair address returned by getPair
/*pub struct PairData {
    pub pair_address: Address,
}*/

//const UNISWAP_V2_FACTORY_ADDRESS: &str = "5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f";

// Function to fetch the pair address from Uniswap V2 Factory contract
pub fn fetch_pair_from_factory(factory_address: &Address, token_a: &Address, token_b: &Address) -> Option<Address> {
    //let factory_address_decoded = Hex::decode( factory_address ).unwrap();   //  invalid a

 let factory_address_bytes = factory_address.as_bytes().to_vec();

        
    // Define the getPair function call
    let get_pair_function = abi::uniswapv2_factory::functions::GetPair {
        param0: token_a.as_bytes().to_vec(),
        param1: token_b.as_bytes().to_vec(),
    };

    // Call the getPair function and fetch the pair address
    if let Some(pair_address) = get_pair_function.call(factory_address_bytes.clone()) {
        return Some(  H160::from_slice(&pair_address)  );
    }

    None
}
