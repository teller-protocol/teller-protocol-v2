use crate::abi;
use ethabi::Address;
use ethabi::ethereum_types::H160;


/*

Example 

https://github.com/streamingfast/substreams-uniswap-v3/blob/develop/src/rpc.rs


*/

pub struct LenderGroupPoolInitializationDataFromRpc {
        
    pub teller_v2_address: Address,

    pub uniswap_v3_pool_address: Address ,

    pub smart_commitment_forwarder_address: Address 

}


pub fn fetch_lender_group_pool_initialization_data_from_rpc(pool_contract_address: &String) -> Option<LenderGroupPoolInitializationDataFromRpc> {
        
    let pool_contract_address_decoded = hex::decode(pool_contract_address).unwrap(); 
        
        
 
    
    let teller_v2_function = abi::lendergroup_contract::functions::TellerV2 {};
    let Some(teller_v2_address) = teller_v2_function.call(
        pool_contract_address_decoded.clone()
     ) else {return None};
    
        let uniswap_v3_pool_function = abi::lendergroup_contract::functions::UniswapV3Pool {};
        let Some(uniswap_v3_pool_address) = uniswap_v3_pool_function.call(
            pool_contract_address_decoded.clone()
        ) else {return None};
        
    
            
        let smart_commitment_forwarder_function = abi::lendergroup_contract::functions::SmartCommitmentForwarder {};
        let Some(smart_commitment_forwarder_address) = smart_commitment_forwarder_function.call(
              pool_contract_address_decoded.clone()
         ) else {return None};
            
            
     
    
    return Some(  
        LenderGroupPoolInitializationDataFromRpc{ 
              
              
              
            teller_v2_address: H160::from_slice(&teller_v2_address ) ,
            uniswap_v3_pool_address: H160::from_slice(&uniswap_v3_pool_address ) ,
            smart_commitment_forwarder_address: H160::from_slice(&smart_commitment_forwarder_address ) ,
             
            

        }
    ); 
 
 
}