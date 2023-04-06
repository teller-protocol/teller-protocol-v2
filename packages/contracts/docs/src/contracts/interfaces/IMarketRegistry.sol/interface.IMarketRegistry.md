# IMarketRegistry
[Git Source](https://github.com/teller-protocol/teller-protocol-v2/blob/cc7fb9358a2518de7ee33e518ebac21eac498b0d/contracts/interfaces/IMarketRegistry.sol)


## Functions
### initialize


```solidity
function initialize(TellerAS tellerAs) external;
```

### isVerifiedLender


```solidity
function isVerifiedLender(uint256 _marketId, address _lender) external view returns (bool, bytes32);
```

### isMarketClosed


```solidity
function isMarketClosed(uint256 _marketId) external view returns (bool);
```

### isVerifiedBorrower


```solidity
function isVerifiedBorrower(uint256 _marketId, address _borrower) external view returns (bool, bytes32);
```

### getMarketOwner


```solidity
function getMarketOwner(uint256 _marketId) external view returns (address);
```

### getMarketFeeRecipient


```solidity
function getMarketFeeRecipient(uint256 _marketId) external view returns (address);
```

### getMarketURI


```solidity
function getMarketURI(uint256 _marketId) external view returns (string memory);
```

### getPaymentCycle


```solidity
function getPaymentCycle(uint256 _marketId) external view returns (uint32, PaymentCycleType);
```

### getPaymentDefaultDuration


```solidity
function getPaymentDefaultDuration(uint256 _marketId) external view returns (uint32);
```

### getBidExpirationTime


```solidity
function getBidExpirationTime(uint256 _marketId) external view returns (uint32);
```

### getMarketplaceFee


```solidity
function getMarketplaceFee(uint256 _marketId) external view returns (uint16);
```

### getPaymentType


```solidity
function getPaymentType(uint256 _marketId) external view returns (PaymentType);
```

### createMarket


```solidity
function createMarket(
    address _initialOwner,
    uint32 _paymentCycleDuration,
    uint32 _paymentDefaultDuration,
    uint32 _bidExpirationTime,
    uint16 _feePercent,
    bool _requireLenderAttestation,
    bool _requireBorrowerAttestation,
    PaymentType _paymentType,
    PaymentCycleType _paymentCycleType,
    string calldata _uri
) external returns (uint256 marketId_);
```

### createMarket


```solidity
function createMarket(
    address _initialOwner,
    uint32 _paymentCycleDuration,
    uint32 _paymentDefaultDuration,
    uint32 _bidExpirationTime,
    uint16 _feePercent,
    bool _requireLenderAttestation,
    bool _requireBorrowerAttestation,
    string calldata _uri
) external returns (uint256 marketId_);
```

### closeMarket


```solidity
function closeMarket(uint256 _marketId) external;
```

