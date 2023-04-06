# PaymentNotMinimum
[Git Source](https://github.com/teller-protocol/teller-protocol-v2/blob/cc7fb9358a2518de7ee33e518ebac21eac498b0d/contracts/TellerV2.sol)

This error is reverted when repayment amount is less than the required minimum


```solidity
error PaymentNotMinimum(uint256 bidId, uint256 payment, uint256 minimumOwed);
```

