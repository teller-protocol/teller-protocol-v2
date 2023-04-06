# TellerV2Mock
[Git Source](https://github.com/teller-protocol/teller-protocol-v2/blob/cc7fb9358a2518de7ee33e518ebac21eac498b0d/contracts/TellerV2Mock.sol)

**Inherits:**
[TellerV2](/contracts/TellerV2.sol/contract.TellerV2.md)


## Functions
### constructor


```solidity
constructor(address trustedForwarder) TellerV2(trustedForwarder);
```

### mockBid


```solidity
function mockBid(Bid calldata _bid) external;
```

### mockAcceptedTimestamp


```solidity
function mockAcceptedTimestamp(uint256 _bidId, uint32 _timestamp) external;
```

### mockAcceptedTimestamp


```solidity
function mockAcceptedTimestamp(uint256 _bidId) external;
```

### mockLastRepaidTimestamp


```solidity
function mockLastRepaidTimestamp(uint256 _bidId, uint32 _timestamp) external;
```

### setVersion


```solidity
function setVersion(uint256 _version) public;
```

