# LoanDetails
[Git Source](https://github.com/teller-protocol/teller-protocol-v2/blob/991530423d15c8e2846d3c24bb6245b3416dd233/contracts/TellerV2Storage.sol)

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

