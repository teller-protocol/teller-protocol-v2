use crate::abi::lendergroup_contract::functions;
use crate::{abi, eth };
use ethabi::Address;
use ethabi::ethereum_types::H160;
use prost::Message;

use substreams::log;
use substreams::scalar::BigInt;
use substreams::Hex;
use substreams_ethereum::rpc::RpcBatch;


/*

Example 

https://github.com/streamingfast/substreams-uniswap-v3/blob/develop/src/rpc.rs


*/

pub struct LenderGroupPoolInitializationDataFromRpc {
        
    pub teller_v2_address: Address,

    //pub uniswap_v3_pool_address: Address ,

    pub smart_commitment_forwarder_address: Address 

}


//maybe this is broken ?
pub fn fetch_lender_group_pool_initialization_data_from_rpc(pool_contract_address: &String) -> Option<LenderGroupPoolInitializationDataFromRpc> {
        
    let pool_contract_address_decoded = Hex::decode(pool_contract_address).unwrap(); 
        
        
 
    
    let teller_v2_function = abi::lendergroup_contract::functions::TellerV2 {};
    let Some(teller_v2_address) = teller_v2_function.call(
        pool_contract_address_decoded.clone()
     ) else {return None};
    
       /*  let uniswap_v3_pool_function = abi::lendergroup_contract::functions::UniswapV3Pool {};
        let Some(uniswap_v3_pool_address) = uniswap_v3_pool_function.call(
            pool_contract_address_decoded.clone()
        ) else {return None}; */
        
    
            
        let smart_commitment_forwarder_function = abi::lendergroup_contract::functions::SmartCommitmentForwarder {};
        let Some(smart_commitment_forwarder_address) = smart_commitment_forwarder_function.call(
              pool_contract_address_decoded.clone()
         ) else {return None};
            
            
     
    
    return Some(  
        LenderGroupPoolInitializationDataFromRpc{ 
              
              
              
            teller_v2_address: H160::from_slice(&teller_v2_address ) ,
            //uniswap_v3_pool_address: H160::from_slice(&uniswap_v3_pool_address ) ,
            smart_commitment_forwarder_address: H160::from_slice(&smart_commitment_forwarder_address ) ,
             
            

        }
    ); 
 
 
}


pub fn fetch_min_interest_rate_from_rpc(pool_contract_address: &String, amount_delta: BigInt) -> Option<BigInt> {
        
    let pool_contract_address_decoded = Hex::decode(pool_contract_address).unwrap(); 
        
         
    
        let get_min_interest_rate_function = abi::lendergroup_contract::functions::GetMinInterestRate { amount_delta  };
        let  min_interest_rate  = get_min_interest_rate_function.call(
            pool_contract_address_decoded.clone()
        )  ;
        
      
    
    return  min_interest_rate ; 
 
 
}