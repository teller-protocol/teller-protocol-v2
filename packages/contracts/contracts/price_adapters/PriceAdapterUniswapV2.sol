// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;



// Interfaces
import "../interfaces/IPriceAdapter.sol";
import "../interfaces/uniswap/IUniswapV2Pair.sol";

import {FixedPointQ96} from "../libraries/FixedPointQ96.sol";
import {FullMath} from "../libraries/uniswap/FullMath.sol";
import {FixedPointMathLib} from "../libraries/erc4626/utils/FixedPointMathLib.sol";

/*

    UniswapV2 Price Adapter (compatible with Sushiswap and other V2 forks)
    Uses reserves for current price 


    Cannot compute TWAP price as uniswapV2 doesnt provide historic data 

*/


contract PriceAdapterUniswapV2 is
    IPriceAdapter

{
        




    struct PoolRoute {
        address pool;
        bool zeroForOne;
        uint32 twapInterval;
        uint256 token0Decimals;
        uint256 token1Decimals;
    } 





   
    mapping(bytes32 => bytes) public priceRoutes; 
     
   


    /* Events */

    event RouteRegistered(bytes32 hash, bytes route);
   

    /* External Functions */
 
 
    function registerPriceRoute(
       bytes memory route
    ) external returns (bytes32 hash) {

             PoolRoute[] memory route_array = decodePoolRoutes( route );

    		// hash the route with keccak256
            bytes32 poolRouteHash = keccak256(route);

    		// store the route by its hash in the priceRoutes mapping
            priceRoutes[poolRouteHash] = route;

            emit RouteRegistered(poolRouteHash, route);

            return poolRouteHash;
    }

  



     function getPriceRatioQ96(
        bytes32 route
    ) external  view returns ( uint256 priceRatioQ96  ) {

        // lookup the route from the mapping
        bytes memory routeData = priceRoutes[route];
        require(routeData.length > 0, "Route not found");

        // decode the route
        PoolRoute[] memory poolRoutes = decodePoolRoutes(routeData);

        // start with Q96 = 1.0 in Q96 format
        priceRatioQ96 = FixedPointQ96.Q96;

        // iterate through each pool and multiply prices
        for (uint256 i = 0; i < poolRoutes.length; i++) {
            uint256 poolPriceQ96 = getUniswapPriceRatioForPool(poolRoutes[i]);
            // multiply using Q96 arithmetic
            priceRatioQ96 = FixedPointQ96.multiplyFixedPoint96(priceRatioQ96, poolPriceQ96);
        }
    }



    // -------



    function encodePoolRoutes( PoolRoute[] memory routes  ) public pure returns (bytes memory encoded)  {

           encoded = abi.encode(routes);

    }


    // validate the route for length, other restrictions
    //must be length 1 or 2

    function decodePoolRoutes( bytes memory data ) public pure returns ( PoolRoute[] memory route_array )  {

        route_array = abi.decode(data, (PoolRoute[]));

        require(route_array.length == 1 || route_array.length == 2, "Route must have 1 or 2 pools");

    }




    // -------



   function getUniswapPriceRatioForPool(
        PoolRoute memory _poolRoute
    ) internal view returns (uint256 priceRatioQ96) {

        // Get sqrtPriceX96 from UniswapV2 reserves
        uint160 sqrtPriceX96 = getSqrtTwapX96(
            _poolRoute.pool,
            _poolRoute.twapInterval
        );

        // Convert sqrtPriceX96 to priceQ96
        // sqrtPriceX96^2 / 2^96 gives us the price in Q96 format
        priceRatioQ96 = getPriceQ96FromSqrtPriceX96(sqrtPriceX96);

        // If we need the inverse (token0 in terms of token1), invert
        bool invert = !_poolRoute.zeroForOne;
        if (invert) {
            // To invert a Q96 number: (Q96 * Q96) / value
            priceRatioQ96 = FullMath.mulDiv(FixedPointQ96.Q96, FixedPointQ96.Q96, priceRatioQ96);
        }
    }

    function getSqrtTwapX96(address uniswapV2Pool, uint32 twapInterval)
        internal
        view
        returns (uint160 sqrtPriceX96)
    {
        IUniswapV2Pair pair = IUniswapV2Pair(uniswapV2Pool);

        if (twapInterval == 0) {
            // Use current reserves for immediate price
            (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
            sqrtPriceX96 = getSqrtPriceX96FromReserves(uint256(reserve0), uint256(reserve1));
        } else {
            // For TWAP, use cumulative prices
            // Note: In a single transaction, we can only get the current cumulative prices
            // This requires storing historical cumulative prices on-chain for proper TWAP calculation
            // For now, we use current reserves as a fallback
            (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
            sqrtPriceX96 = getSqrtPriceX96FromReserves(uint256(reserve0), uint256(reserve1));
        }
    }

    function getSqrtPriceX96FromReserves(uint256 reserve0, uint256 reserve1)
        internal
        pure
        returns (uint160 sqrtPriceX96)
    {
        // Calculate sqrt(reserve1 / reserve0) * 2^96
        // This represents the price of token0 in terms of token1

        require(reserve0 > 0, "Reserve0 cannot be zero");
        require(reserve1 > 0, "Reserve1 cannot be zero");

        uint256 sqrtReserve0 = FixedPointMathLib.sqrt(reserve0);
        uint256 sqrtReserve1 = FixedPointMathLib.sqrt(reserve1);

        sqrtPriceX96 = uint160(
            FullMath.mulDiv(sqrtReserve1, FixedPointQ96.Q96, sqrtReserve0)
        );
    }

    function getPriceQ96FromSqrtPriceX96(uint160 sqrtPriceX96)
        internal
        pure
        returns (uint256 priceQ96)
    {
        // sqrtPriceX96^2 / 2^96 = priceQ96
        return FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, FixedPointQ96.Q96);
    }

















 
}
