# IMarketLiquidityRewards
[Git Source](https://github.com/teller-protocol/teller-protocol-v2/blob/cc7fb9358a2518de7ee33e518ebac21eac498b0d/contracts/interfaces/IMarketLiquidityRewards.sol)


## Functions
### allocateRewards


```solidity
function allocateRewards(RewardAllocation calldata _allocation) external returns (uint256 allocationId_);
```

### increaseAllocationAmount


```solidity
function increaseAllocationAmount(uint256 _allocationId, uint256 _tokenAmount) external;
```

### deallocateRewards


```solidity
function deallocateRewards(uint256 _allocationId, uint256 _amount) external;
```

### claimRewards


```solidity
function claimRewards(uint256 _allocationId, uint256 _bidId) external;
```

### rewardClaimedForBid


```solidity
function rewardClaimedForBid(uint256 _bidId, uint256 _allocationId) external view returns (bool);
```

### initialize


```solidity
function initialize() external;
```

## Structs
### RewardAllocation

```solidity
struct RewardAllocation {
    address allocator;
    address rewardTokenAddress;
    uint256 rewardTokenAmount;
    uint256 marketId;
    address requiredPrincipalTokenAddress;
    address requiredCollateralTokenAddress;
    uint256 minimumCollateralPerPrincipalAmount;
    uint256 rewardPerLoanPrincipalAmount;
    uint32 bidStartTimeMin;
    uint32 bidStartTimeMax;
    AllocationStrategy allocationStrategy;
}
```

## Enums
### AllocationStrategy

```solidity
enum AllocationStrategy {
    BORROWER,
    LENDER
}
```

