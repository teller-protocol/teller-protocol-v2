 
use crate::{abi, eth };
use ethabi::Address;
use ethabi::ethereum_types::H160;
use prost::Message;

use substreams::log;
use substreams::scalar::BigInt;
use substreams::Hex;
use substreams_ethereum::rpc::RpcBatch;
use hex_literal::hex;

/*

Example 

https://github.com/streamingfast/substreams-uniswap-v3/blob/develop/src/rpc.rs


*/


/*

[ getLoanSummary(uint256) method Response ]
  borrower   address :  0x8EC0bcFC6Fca34c5dAD0680306f0242EA87E7703
  lender   address :  0x62C04179D85f2D776A028a1453F2Ded314b18BC8
  marketId   uint256 :  1
  principalTokenAddress   address :  0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
  principalAmount   uint256 :  8362295945234333859
  acceptedTimestamp   uint32 :  1657426010
  lastRepaidTimestamp   uint32 :  1664926967
  bidState   uint8 :  4



*/
pub struct LoanSummaryData {
    
    pub bid_id: BigInt,
        
    pub borrower_address: Address,

    pub lender_address: Address ,
    
    pub market_id: BigInt ,
    
    pub principal_token_address: Address ,

    pub principal_amount: BigInt ,
    
    pub accepted_timestamp: BigInt ,
    
    pub last_repaid_timestamp: BigInt ,
     
    pub bid_state: BigInt ,
     
}



const TELLERV2_TRACKED_CONTRACT: &str =  "00182FdB0B880eE24D428e3Cc39383717677C37e" ;


pub fn fetch_loan_summary_from_rpc(teller_v2_address: &Address, bid_id: &BigInt) -> Option<LoanSummaryData> {
            
    
    
        //let  contract_address = Hex(& TELLERV2_TRACKED_CONTRACT ).to_string();
                       
                       let bid_id = BigInt::from( 0 );
                       
                       
    let teller_v2_address_decoded =   Hex::decode( TELLERV2_TRACKED_CONTRACT ).unwrap(); 
       
    let loan_summary_function = abi::tellerv2_contract::functions::GetLoanSummary {u_bid_id: bid_id.clone()};
  
    
    
    
    call_custom(
        teller_v2_address_decoded.clone(),
        loan_summary_function.encode()
    );

      let (
        borrower_address,
        lender_address,
        market_id,
        principal_token_address,
        principal_amount,
        accepted_timestamp,
        last_repaid_timestamp,
        bid_state
        )  = loan_summary_function.call(
        teller_v2_address_decoded.clone()
    ) .unwrap();
      
    return Some(  
        LoanSummaryData{ 
              bid_id: bid_id.clone(),
              borrower_address: H160::from_slice(&borrower_address ),
              lender_address: H160::from_slice(&lender_address ),
              market_id,
              principal_token_address: H160::from_slice(&principal_token_address ),
              principal_amount,
              accepted_timestamp,
              last_repaid_timestamp,
              bid_state
              
             
        }
    ); 
 
 
} 



        /*let Some((
        borrower_address,
        lender_address,
        market_id,
        principal_token_address,
        principal_amount,
        accepted_timestamp,
        last_repaid_timestamp,
        bid_state
        )) = loan_summary_function.call(
        teller_v2_address_decoded.clone()
    ) else {
        
         return None
         
         
    };*/
    
    
fn call_custom(
    
    
    to_address: Vec<u8>,
    raw_data: Vec<u8>, 
){
    
                    use substreams_ethereum::pb::eth::rpc;
                      let rpc_calls = rpc::RpcCalls {
                    calls: vec![
                        rpc::RpcCall { to_addr : to_address, data : raw_data, }
                    ],
                };
                let responses = substreams_ethereum::rpc::eth_call(&rpc_calls).responses;
                let response = responses
                    .get(0)
                    .expect("one response should have existed");
               
                
               //   use substreams_ethereum::Function;
                        substreams::log::info!(
                            "Call output for function {} raw : {:?}   ",
                               response.failed,
                             response.raw,
                             
                        );
                        
                      
                        
                   /*       if response.failed {
                    return None;
                }
                match Self::output(response.raw.as_ref()) {
                    Ok(data) => Some(data),
                    Err(err) => {
                        use substreams_ethereum::Function;
                        substreams::log::info!(
                            "Call output for function `{}` failed to decode with error: {}",
                            Self::NAME, err
                        );
                        None
                    }
                }*/
                
                
}