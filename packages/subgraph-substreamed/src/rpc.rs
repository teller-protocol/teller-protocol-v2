use crate::abi::groupp_contract::functions;
use crate::{abi, eth };
use ethabi::Address;
use ethabi::ethereum_types::H160;
use prost::Message;

use substreams::log;
use substreams::scalar::BigInt;
use substreams::Hex;
use substreams_ethereum::rpc::RpcBatch;



pub struct LenderGroupPoolInitializationDataFromRpc {
        
    pub principal_token_address: Address,
    pub collateral_token_address: Address,
    pub pool_shares_token_address: Address,
     
     pub interest_rate_lower_bound: BigInt,
     pub interest_rate_upper_bound: BigInt,
     pub liquidity_threshold_percent: BigInt,
     pub collateral_ratio: BigInt,
     pub market_id: BigInt,
     pub maximum_loan_duration: BigInt,
     
     pub twap_interval: BigInt,
     pub uniswap_pool_fee:BigInt,
     
     
     

    pub uniswap_v3_pool: Address //not used? 

}


pub fn fetch_lender_group_pool_initialization_data_from_rpc(pool_contract_address: &String) -> Option<LenderGroupPoolInitializationDataFromRpc> {
        
    let pool_contract_address_decoded = hex::decode(pool_contract_address).unwrap(); 
        
        
    let collateral_token_address_function = abi::groupp_contract::functions::GetCollateralTokenAddress {};
    let Some(collateral_token_address) = collateral_token_address_function.call(
        pool_contract_address_decoded.clone()
        ) else {return None};
        
        
    let principal_token_address_function = abi::groupp_contract::functions::GetPrincipalTokenAddress {};
    let Some(principal_token_address) = principal_token_address_function.call(
        pool_contract_address_decoded.clone()
        ) else {return None};
        
    
          // Fetching pool shares token address
     let pool_shares_token_address_function = abi::groupp_contract::functions::PoolSharesToken {}; 
     let Some( pool_shares_token_address)  =   pool_shares_token_address_function.call(pool_contract_address_decoded.clone() ) else{
         return None;
     };
     
    
    let uniswap_v3_pool_function = abi::groupp_contract::functions::UniswapV3Pool {};
    let Some(uniswap_v3_pool) = uniswap_v3_pool_function.call(
        pool_contract_address_decoded.clone()
        ) else {return None};
    
    
    
    


    // Fetching interest rate lower bound
    let interest_rate_lower_bound_function = abi::groupp_contract::functions::InterestRateLowerBound {};
      let Some( interest_rate_lower_bound )  =   interest_rate_lower_bound_function.call(pool_contract_address_decoded.clone()  ) else{
         return None;
     };

    // Fetching interest rate upper bound
    let interest_rate_upper_bound_function = abi::groupp_contract::functions::InterestRateUpperBound {};
      let Some( interest_rate_upper_bound )  =   interest_rate_upper_bound_function.call(pool_contract_address_decoded.clone() ) else{
         return None;
     };

    // Fetching liquidity threshold percent
    let liquidity_threshold_percent_function = abi::groupp_contract::functions::LiquidityThresholdPercent {};
        let Some( liquidity_threshold_percent )  =  liquidity_threshold_percent_function.call(pool_contract_address_decoded.clone()) else{
         return None;
     };

    // Fetching collateral ratio
    let collateral_ratio_function = abi::groupp_contract::functions::LoanToValuePercent {};
        let Some( collateral_ratio )  =  collateral_ratio_function.call(pool_contract_address_decoded.clone()) else{
         return None;
     };

    // Fetching market ID
    let market_id_function = abi::groupp_contract::functions::GetMarketId {};
        let Some( market_id )  =  market_id_function.call(pool_contract_address_decoded.clone()) else{
         return None;
     };
     
     
     let maximum_loan_duration_function = abi::groupp_contract::functions::MaxLoanDuration {};
        let Some( maximum_loan_duration )  =  maximum_loan_duration_function.call(pool_contract_address_decoded.clone()) else{
         return None;
     };

    // Fetching TWAP interval
    let twap_interval_function = abi::groupp_contract::functions::TwapInterval {};
      let Some( twap_interval )  =  twap_interval_function.call(pool_contract_address_decoded.clone()) else{
         return None;
     };
    
    //NEED TO ADD THIS !!! 
    // Fetching Uniswap pool fee
 /*   let uniswap_pool_fee_function = abi::groupp_contract::functions::UniswapPoolFee {};
    let uniswap_pool_fee = match uniswap_pool_fee_function.call(decoded_address.clone()) {
        Some(data) => BigInt::from_unsigned_bytes_be(&data),
        None => return None,
    };*/
    
    let uniswap_pool_fee =  BigInt::from( 3000 ) ; // FOR NOW 

  
    
    
    
    return Some(  
        LenderGroupPoolInitializationDataFromRpc{ 
             principal_token_address: H160::from_slice(&principal_token_address ) ,
             collateral_token_address: H160::from_slice(&collateral_token_address ) ,
              pool_shares_token_address: H160::from_slice(&pool_shares_token_address ) ,
              
              interest_rate_upper_bound,
              interest_rate_lower_bound,
              liquidity_threshold_percent,
              collateral_ratio,
              twap_interval,
              uniswap_pool_fee,
              market_id,
              
              maximum_loan_duration,
              
              
              
             uniswap_v3_pool: H160::from_slice(&uniswap_v3_pool ) ,
             
            

        }
    ); 
 
 
}