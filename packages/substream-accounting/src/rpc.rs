 
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



const TELLERV2_TRACKED_CONTRACT: &str =  "0x00182fdb0b880ee24d428e3cc39383717677c37e" ;


pub fn fetch_loan_summary_from_rpc(teller_v2_address: &Address, bid_id: &BigInt) -> Option<LoanSummaryData> {
            
        
    let bid_id = BigInt::from(0);
      
    //let teller_v2_address_decoded = Hex::decode(teller_v2_address).unwrap(); 
         let teller_v2_address_decoded =   Hex::decode(TELLERV2_TRACKED_CONTRACT).unwrap(); 
      //TELLERV2_TRACKED_CONTRACT .to_vec() ; // for now ? 
    
    let loan_summary_function = abi::tellerv2_contract::functions::GetLoanSummary {u_bid_id: bid_id.clone()};
    let Some((
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
         
         
    };
      
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