# IReputationManager
[Git Source](https://github.com/teller-protocol/teller-protocol-v2/blob/cc7fb9358a2518de7ee33e518ebac21eac498b0d/contracts/interfaces/IReputationManager.sol)


## Functions
### initialize


```solidity
function initialize(address protocolAddress) external;
```

### getDelinquentLoanIds


```solidity
function getDelinquentLoanIds(address _account) external returns (uint256[] memory);
```

### getDefaultedLoanIds


```solidity
function getDefaultedLoanIds(address _account) external returns (uint256[] memory);
```

### getCurrentDelinquentLoanIds


```solidity
function getCurrentDelinquentLoanIds(address _account) external returns (uint256[] memory);
```

### getCurrentDefaultLoanIds


```solidity
function getCurrentDefaultLoanIds(address _account) external returns (uint256[] memory);
```

### updateAccountReputation


```solidity
function updateAccountReputation(address _account) external;
```

### updateAccountReputation


```solidity
function updateAccountReputation(address _account, uint256 _bidId) external returns (RepMark);
```

