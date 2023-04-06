# Bid
[Git Source](https://github.com/teller-protocol/teller-protocol-v2/blob/cc7fb9358a2518de7ee33e518ebac21eac498b0d/contracts/TellerV2Storage.sol)

Details about a loan request.


```solidity
struct Bid {
    address borrower;
    address receiver;
    address lender;
    uint256 marketplaceId;
    bytes32 _metadataURI;
    LoanDetails loanDetails;
    Terms terms;
    BidState state;
    PaymentType paymentType;
}
```

