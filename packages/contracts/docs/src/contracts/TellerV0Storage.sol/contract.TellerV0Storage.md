# TellerV0Storage
[Git Source](https://github.com/teller-protocol/teller-protocol-v2/blob/cc7fb9358a2518de7ee33e518ebac21eac498b0d/contracts/TellerV0Storage.sol)


## State Variables
### bids

```solidity
mapping(uint256 => Bid0) public bids;
```


## Structs
### Payment
Represents a total amount for a payment.


```solidity
struct Payment {
    uint256 principal;
    uint256 interest;
}
```

### LoanDetails
Details about the loan.


```solidity
struct LoanDetails {
    ERC20 lendingToken;
    uint256 principal;
    Payment totalRepaid;
    uint32 timestamp;
    uint32 acceptedTimestamp;
    uint32 lastRepaidTimestamp;
    uint32 loanDuration;
}
```

### Bid0
Details about a loan request.


```solidity
struct Bid0 {
    address borrower;
    address receiver;
    address _lender;
    uint256 marketplaceId;
    bytes32 _metadataURI;
    LoanDetails loanDetails;
    Terms terms;
    BidState state;
}
```

### Terms
Information on the terms of a loan request


```solidity
struct Terms {
    uint256 paymentCycleAmount;
    uint32 paymentCycle;
    uint16 APR;
}
```

## Enums
### BidState

```solidity
enum BidState {
    NONEXISTENT,
    PENDING,
    CANCELLED,
    ACCEPTED,
    PAID,
    LIQUIDATED
}
```

