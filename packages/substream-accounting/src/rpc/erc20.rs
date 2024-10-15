use crate::{abi, eth};
use ethabi::ethereum_types::H160;
use ethabi::Address;
use hex_literal::hex;
use prost::Message;
use substreams::log;
use substreams::scalar::BigInt;
use substreams::Hex;
use substreams_ethereum::rpc::RpcBatch;

pub fn fetch_token_decimals(token_address: &Address) -> Option<BigInt> {
    //let factory_address_decoded = Hex::decode( factory_address ).unwrap();   //  invalid a

    let token_address_bytes = token_address.as_bytes().to_vec();

    // Define the getPair function call
    let get_decimals_function = abi::erc20::functions::Decimals {};

    // Call the getPair function and fetch the pair address
    if let Some(decimals) = get_decimals_function.call(token_address_bytes.clone()) {
        return Some(decimals);
    }

    None
}
