


initial block WAS 

15094701




use this block for testing !!   it gets faster results for now 
19094701


## Substreams Accounting 



1.  Build an RPC call that will collect data about teller bid when submitted and store it in a special table DONE

2. collect price data from uniswap for tokens -- which tokens tho?   
    
    I think, for EACH block, i need to do the following 
    
        a. figure out which tokens have been interacted with on teller 
        b. query uniswap at the block, with an RPC or whatever, to find the price ratio at that block 
        c. combine the uniswap data and teller data some how 





___
fix this bug 

  "data": {
    "tokenPrices": [
      {
        "id": "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
        "base_token_address": "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
        "reference_token_address": "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
        "price_ratio": "433169032.9604033"
      },
      {
        "id": "a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
        "base_token_address": "a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
        "reference_token_address": "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
        "price_ratio": "433169032.9604033"
      }
    ]
  }
  