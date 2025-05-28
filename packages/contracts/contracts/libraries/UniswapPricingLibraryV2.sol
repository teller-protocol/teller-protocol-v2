pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT

 

import {IUniswapPricingLibrary} from "../interfaces/IUniswapPricingLibrary.sol";

 
  
// Libraries 
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";

import "../interfaces/uniswap/IUniswapV3Pool.sol"; 

import "../libraries/uniswap/TickMath.sol";
import "../libraries/uniswap/FixedPoint96.sol";
import "../libraries/uniswap/FullMath.sol";
 
 
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";


/*

Only do decimal expansion if it is an ERC20   not anything else !! 

*/

library UniswapPricingLibraryV2
{
    
    uint256 constant STANDARD_EXPANSION_FACTOR = 1e18;

  
    function getUniswapPriceRatioForPoolRoutes(
        IUniswapPricingLibrary.PoolRouteConfig[] memory poolRoutes
    ) public view returns (uint256 priceRatio) {
        require(poolRoutes.length <= 2, "invalid pool routes length");

        if (poolRoutes.length == 2) {
            uint256 pool0PriceRatio = getUniswapPriceRatioForPool(
                poolRoutes[0]
            );

            uint256 pool1PriceRatio = getUniswapPriceRatioForPool(
                poolRoutes[1]
            );

            return
                FullMath.mulDiv(
                    pool0PriceRatio,
                    pool1PriceRatio,
                    STANDARD_EXPANSION_FACTOR
                );
        } else if (poolRoutes.length == 1) {
            return getUniswapPriceRatioForPool(poolRoutes[0]);
        }

        //else return 0
    }

    /*
        The resultant product is expanded by STANDARD_EXPANSION_FACTOR one time 
    */
    function getUniswapPriceRatioForPool(
        IUniswapPricingLibrary.PoolRouteConfig memory _poolRouteConfig
    ) public view returns (uint256 priceRatio) {

        

           // this is expanded by 2**96 or   1e28 
      uint160 sqrtPriceX96 = getSqrtTwapX96(
            _poolRouteConfig.pool,
            _poolRouteConfig.twapInterval
        );


      bool invert =  ! _poolRouteConfig.zeroForOne; 

         //this output will be expanded by 1e18 
        return getQuoteFromSqrtRatioX96( sqrtPriceX96 , uint128( STANDARD_EXPANSION_FACTOR ), invert) ;


        
    }


    //taken directly from uniswap oracle lib 
    /**
     * @dev Calculates the amount of quote token received for a given amount of base token
     * based on the square root of the price ratio (sqrtRatioX96).
     *
     * @param sqrtRatioX96 The square root of the price ratio(in terms of token1/token0) between two tokens, encoded as a Q64.96 value.
     * @param baseAmount The amount of the base token for which the quote is to be calculated. Specify 1e18 for a price(quoteAmount) with 18 decimals of precision.
     * @param inverse Specifies the direction of the price quote. If true then baseAmount must be the amount of token1, if false then baseAmount must be the amount for token0
     *
     * @return quoteAmount The calculated amount of the quote token for the specified baseAmount
     */

    function getQuoteFromSqrtRatioX96(
        uint160 sqrtRatioX96,
        uint128 baseAmount,
        bool inverse
    ) internal pure returns (uint256 quoteAmount) {
        // Calculate quoteAmount with better precision if it doesn't overflow when multiplied by itself
        if (sqrtRatioX96 <= type(uint128).max) {
            uint256 ratioX192 = uint256(sqrtRatioX96) * sqrtRatioX96;
            quoteAmount = !inverse
                ? FullMath.mulDiv(ratioX192, baseAmount, 1 << 192)
                : FullMath.mulDiv(1 << 192, baseAmount, ratioX192);
        } else {
            uint256 ratioX128 = FullMath.mulDiv(
                sqrtRatioX96,
                sqrtRatioX96,
                1 << 64
            );
            quoteAmount = !inverse
                ? FullMath.mulDiv(ratioX128, baseAmount, 1 << 128)
                : FullMath.mulDiv(1 << 128, baseAmount, ratioX128);
        }
    }
 

    function getSqrtTwapX96(address uniswapV3Pool, uint32 twapInterval)
        internal
        view
        returns (uint160 sqrtPriceX96)
    {
        if (twapInterval == 0) {
            // return the current price if twapInterval == 0
            (sqrtPriceX96, , , , , , ) = IUniswapV3Pool(uniswapV3Pool).slot0();
        } else {
            uint32[] memory secondsAgos = new uint32[](2);
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
            );
        }
    }

    function getPriceX96FromSqrtPriceX96(uint160 sqrtPriceX96)
        internal
        pure
        returns (uint256 priceX96)
    {   

        
        return FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, FixedPoint96.Q96);
    }

}