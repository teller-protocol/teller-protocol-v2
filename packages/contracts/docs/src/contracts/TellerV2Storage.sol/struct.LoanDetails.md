# LoanDetails
[Git Source](https://github.com/teller-protocol/teller-protocol-v2/blob/cc7fb9358a2518de7ee33e518ebac21eac498b0d/contracts/TellerV2Storage.sol)

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

