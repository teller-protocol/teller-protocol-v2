# LoanDetails
[Git Source](https://github.com/teller-protocol/teller-protocol-v2/blob/06ebc3cc034145956680b0db36c29ffb293ae345/contracts/TellerV2Storage.sol)

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

