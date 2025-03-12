// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import {IUniswapPricingLibrary} from "../interfaces/IUniswapPricingLibrary.sol";
interface ILenderCommitmentGroup_V2 {



    struct CommitmentGroupConfig {
        address principalTokenAddress;
        address collateralTokenAddress;
        uint256 marketId;
        uint32 maxLoanDuration;
        uint16 interestRateLowerBound;
        uint16 interestRateUpperBound;
        uint16 liquidityThresholdPercent;
        uint16 collateralRatio;  
        
    }


    function initialize(
        CommitmentGroupConfig calldata _commitmentGroupConfig,

        IUniswapPricingLibrary.PoolRouteConfig[] calldata _poolOracleRoutes  ,

        address sharesToken 
    )
        external
        returns ( 
            address poolSharesToken
        );

   

     function liquidateDefaultedLoanWithIncentive(
        uint256 _bidId,
        int256 _tokenAmountDifference
    ) external ;

    function getTokenDifferenceFromLiquidations() external view returns (int256);

}
