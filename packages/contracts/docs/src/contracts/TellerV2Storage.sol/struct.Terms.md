# Terms
[Git Source](https://github.com/teller-protocol/teller-protocol-v2/blob/cc7fb9358a2518de7ee33e518ebac21eac498b0d/contracts/TellerV2Storage.sol)

Information on the terms of a loan request


```solidity
struct Terms {
    uint256 paymentCycleAmount;
    uint32 paymentCycle;
    uint16 APR;
}
```

