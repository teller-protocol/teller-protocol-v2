# ReputationManagerMock
[Git Source](https://github.com/teller-protocol/teller-protocol-v2/blob/cc7fb9358a2518de7ee33e518ebac21eac498b0d/contracts/mock/ReputationManagerMock.sol)

**Inherits:**
[IReputationManager](/contracts/interfaces/IReputationManager.sol/interface.IReputationManager.md)


## Functions
### constructor


```solidity
constructor();
```

### initialize


```solidity
function initialize(address protocolAddress) external override;
```

### getDelinquentLoanIds


```solidity
function getDelinquentLoanIds(address _account) external returns (uint256[] memory _loanIds);
```

### getDefaultedLoanIds


```solidity
function getDefaultedLoanIds(address _account) external returns (uint256[] memory _loanIds);
```

### getCurrentDelinquentLoanIds


```solidity
function getCurrentDelinquentLoanIds(address _account) external returns (uint256[] memory _loanIds);
```

### getCurrentDefaultLoanIds


```solidity
function getCurrentDefaultLoanIds(address _account) external returns (uint256[] memory _loanIds);
```

### updateAccountReputation


```solidity
function updateAccountReputation(address _account) external;
```

### updateAccountReputation


```solidity
function updateAccountReputation(address _account, uint256 _bidId) external returns (RepMark);
```

