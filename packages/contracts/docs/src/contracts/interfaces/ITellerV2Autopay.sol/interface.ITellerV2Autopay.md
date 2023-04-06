# ITellerV2Autopay
[Git Source](https://github.com/teller-protocol/teller-protocol-v2/blob/cc7fb9358a2518de7ee33e518ebac21eac498b0d/contracts/interfaces/ITellerV2Autopay.sol)


## Functions
### setAutoPayEnabled


```solidity
function setAutoPayEnabled(uint256 _bidId, bool _autoPayEnabled) external;
```

### autoPayLoanMinimum


```solidity
function autoPayLoanMinimum(uint256 _bidId) external;
```

### initialize


```solidity
function initialize(uint16 _newFee, address _newOwner) external;
```

### setAutopayFee


```solidity
function setAutopayFee(uint16 _newFee) external;
```

