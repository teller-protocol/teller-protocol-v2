// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMarketLiquidityRewards {

     struct RewardAllocation {
        address allocator;
        uint256 marketId;
        address rewardTokenAddress;
        uint256 rewardTokenAmount;


        //parametersfor loan which affect claimability 
        address requiredPrincipalTokenAddress; //0 for any 
        address requiredCollateralTokenAddress; //0 for any  -- could be an enumerable set?

        uint256 rewardPerLoanPrincipalAmount; 
       
    } 

    function allocateRewards(
         RewardAllocation calldata _allocation  
    ) external returns (uint256 allocationId_ );

    function increaseAllocationAmount(
        uint256 _allocationId,
        uint256 _tokenAmount
    ) external;

    function deallocateRewards(
        uint256 _allocationId,
        uint256 _amount
    ) external;

    function claimRewards(
        uint256 _allocationId,
        uint256 _bidId
    ) external;

    function allocatedRewards(uint256 _allocationId) external view returns (address allocator, uint256 marketId, address rewardTokenAddress, uint256 rewardTokenAmount, address requiredPrincipalTokenAddress, address requiredCollateralTokenAddress, uint256 rewardPerLoanPrincipalAmount);

    function rewardClaimedForBid(uint256 _bidId, uint256 _allocationId) external view returns (bool);

    function initialize() external;
}