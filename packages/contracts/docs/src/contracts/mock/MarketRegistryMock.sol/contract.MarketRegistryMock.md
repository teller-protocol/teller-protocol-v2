# MarketRegistryMock
[Git Source](https://github.com/teller-protocol/teller-protocol-v2/blob/cc7fb9358a2518de7ee33e518ebac21eac498b0d/contracts/mock/MarketRegistryMock.sol)

**Inherits:**
[IMarketRegistry](/contracts/interfaces/IMarketRegistry.sol/interface.IMarketRegistry.md)


## State Variables
### globalMarketOwner

```solidity
address public globalMarketOwner;
```


### globalMarketFeeRecipient

```solidity
address public globalMarketFeeRecipient;
```


### globalMarketsClosed

```solidity
bool public globalMarketsClosed;
```


### globalBorrowerIsVerified

```solidity
bool public globalBorrowerIsVerified = true;
```


### globalLenderIsVerified

```solidity
bool public globalLenderIsVerified = true;
```


## Functions
### constructor


```solidity
constructor();
```

### initialize


```solidity
function initialize(TellerAS _tellerAS) external;
```

### isVerifiedLender


```solidity
function isVerifiedLender(uint256 _marketId, address _lenderAddress)
    public
    view
    returns (bool isVerified_, bytes32 uuid_);
```

### isMarketClosed


```solidity
function isMarketClosed(uint256 _marketId) public view returns (bool);
```

### isVerifiedBorrower


```solidity
function isVerifiedBorrower(uint256 _marketId, address _borrower)
    public
    view
    returns (bool isVerified_, bytes32 uuid_);
```

### getMarketOwner


```solidity
function getMarketOwner(uint256 _marketId) public view override returns (address);
```

### getMarketFeeRecipient


```solidity
function getMarketFeeRecipient(uint256 _marketId) public view returns (address);
```

### getMarketURI


```solidity
function getMarketURI(uint256 _marketId) public view returns (string memory);
```

### getPaymentCycle


```solidity
function getPaymentCycle(uint256 _marketId) public view returns (uint32, PaymentCycleType);
```

### getPaymentDefaultDuration


```solidity
function getPaymentDefaultDuration(uint256 _marketId) public view returns (uint32);
```

### getBidExpirationTime


```solidity
function getBidExpirationTime(uint256 _marketId) public view returns (uint32);
```

### getMarketplaceFee


```solidity
function getMarketplaceFee(uint256 _marketId) public view returns (uint16);
```

### setMarketOwner


```solidity
function setMarketOwner(address _owner) public;
```

### setMarketFeeRecipient


```solidity
function setMarketFeeRecipient(address _feeRecipient) public;
```

### getPaymentType


```solidity
function getPaymentType(uint256 _marketId) public view returns (PaymentType);
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
) public returns (uint256);
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
) public returns (uint256);
```

### closeMarket


```solidity
function closeMarket(uint256 _marketId) public;
```

### mock_setGlobalMarketsClosed


```solidity
function mock_setGlobalMarketsClosed(bool closed) public;
```

### mock_setBorrowerIsVerified


```solidity
function mock_setBorrowerIsVerified(bool verified) public;
```

### mock_setLenderIsVerified


```solidity
function mock_setLenderIsVerified(bool verified) public;
```

