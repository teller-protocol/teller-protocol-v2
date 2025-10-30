// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*

    see https://docs.uniswap.org/contracts/v4/deployments 


    https://docs.uniswap.org/contracts/v4/guides/read-pool-state



*/
 

// Interfaces
import "../interfaces/IPriceAdapter.sol";

import {IStateView} from "../interfaces/uniswapv4/IStateView.sol";
 
import {FixedPointQ96} from "../libraries/FixedPointQ96.sol";
import {FullMath} from "../libraries/uniswap/FullMath.sol";
import {TickMath} from "../libraries/uniswap/TickMath.sol";

import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";




contract PriceAdapterUniswapV4 is
    IPriceAdapter

{ 

    

    using PoolIdLibrary for PoolKey;

    IPoolManager public immutable poolManager;


    using StateLibrary for IPoolManager;
   // address immutable POOL_MANAGER_V4; 


        // 0x7ffe42c4a5deea5b0fec41c94c136cf115597227 on mainnet  
    //address immutable UNISWAP_V4_STATE_VIEW; 

    struct PoolRoute {
        PoolId pool;
        bool zeroForOne;
        uint32 twapInterval;
        uint256 token0Decimals;
        uint256 token1Decimals;
    } 

    

  constructor(IPoolManager _poolManager) {
        poolManager = _poolManager;
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

    function getPoolState(PoolId poolId) internal view returns (
        uint160 sqrtPriceX96,
        int24 tick,
        uint24 protocolFee,
        uint24 lpFee
    ) {
        return poolManager.getSlot0(poolId);
    }





   function getUniswapPriceRatioForPool(
        PoolRoute memory _poolRoute
    ) internal view returns (uint256 priceRatioQ96) {

           // this is expanded by 2**96
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

    function getSqrtTwapX96(PoolId poolId, uint32 twapInterval)
        internal
        view
        returns (uint160 sqrtPriceX96)
    {



        if (twapInterval == 0) {
            // return the current price if twapInterval == 0
            (sqrtPriceX96, , , ) = getPoolState(poolId);
        } else {

        revert("twap price not impl ");

        
           /*  uint32[] memory secondsAgos = new uint32[](2);
            secondsAgos[0] = twapInterval + 1; // from (before)
            secondsAgos[1] = 1; // one block prior

            (int56[] memory tickCumulatives, ) = IUniswapV3Pool(uniswapV3Pool)
                .observe(secondsAgos);

            // tick(imprecise as it's an integer) to price
            sqrtPriceX96 = TickMath.getSqrtRatioAtTick(
                int24(
                    (tickCumulatives[1] - tickCumulatives[0]) /
                        int32(twapInterval)
                )
            ); */
        }
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
