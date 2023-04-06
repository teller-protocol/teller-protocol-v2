# TellerASMock
[Git Source](https://github.com/teller-protocol/teller-protocol-v2/blob/cc7fb9358a2518de7ee33e518ebac21eac498b0d/contracts/mock/TellerASMock.sol)

**Inherits:**
[TellerAS](/contracts/EAS/TellerAS.sol/contract.TellerAS.md)


## Functions
### constructor


```solidity
constructor() TellerAS(IASRegistry(new TellerASRegistry()), IEASEIP712Verifier(new TellerASEIP712Verifier()));
```

### isAttestationActive


```solidity
function isAttestationActive(bytes32 uuid) public view override returns (bool);
```

