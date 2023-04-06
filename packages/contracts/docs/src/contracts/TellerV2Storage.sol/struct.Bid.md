# Bid
[Git Source](https://github.com/teller-protocol/teller-protocol-v2/blob/06ebc3cc034145956680b0db36c29ffb293ae345/contracts/TellerV2Storage.sol)

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

