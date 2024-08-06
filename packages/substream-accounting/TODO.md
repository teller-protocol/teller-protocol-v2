


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

