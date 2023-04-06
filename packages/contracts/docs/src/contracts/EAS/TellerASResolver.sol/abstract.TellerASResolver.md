# TellerASResolver
[Git Source](https://github.com/teller-protocol/teller-protocol-v2/blob/cc7fb9358a2518de7ee33e518ebac21eac498b0d/contracts/EAS/TellerASResolver.sol)

**Inherits:**
[IASResolver](/contracts/interfaces/IASResolver.sol/interface.IASResolver.md)


## Functions
### isPayable


```solidity
function isPayable() public pure virtual override returns (bool);
```

### receive


```solidity
receive() external payable virtual;
```

## Errors
### NotPayable

```solidity
error NotPayable();
```

