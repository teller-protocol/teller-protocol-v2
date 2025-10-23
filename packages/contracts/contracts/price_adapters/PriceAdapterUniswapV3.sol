// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

 

// Interfaces
import "./interfaces/IPriceAdapter.sol";

 
contract PriceAdapterUniswapV3 is
    IPriceAdapter,
     
{
     

   
    mapping(bytes32 => bytes) public priceRoutes; 
     
    /* Modifiers */
 

    /* Events */

    event RouteRegistered(bytes32 hash, bytes route);
   

    /* External Functions */
 
 
    function registerPriceRoute(
       bytes calldata route
    ) external returns (bytes32 hash) {
        

    		// validate the route for length, other restrictions 


    		// hash the route with keccak256 


    		// store the route by its hash in the priceRoutes mapping 


    }

     
    function getPrice(
        bytes32 route , uint256 inAmount
    ) external returns (uint256 outAmount_) {
        

    	// lookup the route from the mapping 


    	// use the route to query uniswapV3 for the price  using inAmount 



    }
 
}
