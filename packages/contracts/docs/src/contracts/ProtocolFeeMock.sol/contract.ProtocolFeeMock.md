# ProtocolFeeMock
[Git Source](https://github.com/teller-protocol/teller-protocol-v2/blob/cc7fb9358a2518de7ee33e518ebac21eac498b0d/contracts/ProtocolFeeMock.sol)

**Inherits:**
[ProtocolFee](/contracts/ProtocolFee.sol/contract.ProtocolFee.md)


## State Variables
### setProtocolFeeCalled

```solidity
bool public setProtocolFeeCalled;
```


## Functions
### initialize


```solidity
function initialize(uint16 _initFee) external initializer;
```

### setProtocolFee


```solidity
function setProtocolFee(uint16 newFee) public override onlyOwner;
```

