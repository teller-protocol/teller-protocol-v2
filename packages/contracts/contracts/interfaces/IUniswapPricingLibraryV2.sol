// SPDX-Licence-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IUniswapPricingLibraryV2 {
    

    struct PoolRouteConfig {
        address pool;
        bool zeroForOne;
        uint32 twapInterval;
        uint256 token0Decimals;
        uint256 token1Decimals;
    } 



     function getUniswapPriceRatioForPoolRoutes(
        PoolRouteConfig[] memory poolRoutes
    ) external view returns (uint256 priceRatio);


     function getUniswapPriceRatioForPool(
        PoolRouteConfig memory poolRoute
    ) external view returns (uint256 priceRatio);


       function getUniswapPriceRatioForPool(
        IUniswapPricingLibraryV2.PoolRouteConfig memory _poolRouteConfig,
        uint128 expansion_factor 
    ) external view returns (uint256 priceRatio);

}
