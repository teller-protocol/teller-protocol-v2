# PaymentNotMinimum
[Git Source](https://github.com/teller-protocol/teller-protocol-v2/blob/991530423d15c8e2846d3c24bb6245b3416dd233/contracts/TellerV2.sol)

This error is reverted when repayment amount is less than the required minimum


```solidity
error PaymentNotMinimum(uint256 bidId, uint256 payment, uint256 minimumOwed);
```

