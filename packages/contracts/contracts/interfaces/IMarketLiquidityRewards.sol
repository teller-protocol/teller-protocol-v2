// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMarketLiquidityRewards {
    function allocateRewards(
        uint256 _marketId,
        address _tokenAddress,
        uint256 _tokenAmount
    ) external;

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