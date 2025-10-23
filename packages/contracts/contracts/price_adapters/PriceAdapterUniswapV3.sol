// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

 

// Interfaces
import "../interfaces/IPriceAdapter.sol";

import {FixedPointQ96} from "../libraries/FixedPointQ96.sol";


 
contract PriceAdapterUniswapV3 is
    IPriceAdapter 
     
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

  


    // can we compress this price ratio?  lets compress it with Q96 ! 

     function getPriceRatioQ96(
        bytes32 route 
    ) external  view returns ( uint256 priceRatioQ96  ) {
        

        // lookup the route from the mapping 


        // use the route to query uniswapV3 for the price  using inAmount 



    }
 
}
