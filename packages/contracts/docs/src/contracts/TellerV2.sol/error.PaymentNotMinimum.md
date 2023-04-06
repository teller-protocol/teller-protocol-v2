# PaymentNotMinimum
[Git Source](https://github.com/teller-protocol/teller-protocol-v2/blob/06ebc3cc034145956680b0db36c29ffb293ae345/contracts/TellerV2.sol)

This error is reverted when repayment amount is less than the required minimum


```solidity
error PaymentNotMinimum(uint256 bidId, uint256 payment, uint256 minimumOwed);
```

