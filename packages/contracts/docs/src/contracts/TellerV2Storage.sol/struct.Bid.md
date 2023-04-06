# Bid
[Git Source](https://github.com/teller-protocol/teller-protocol-v2/blob/991530423d15c8e2846d3c24bb6245b3416dd233/contracts/TellerV2Storage.sol)

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

