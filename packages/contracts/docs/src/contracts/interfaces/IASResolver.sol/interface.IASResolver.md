# IASResolver
[Git Source](https://github.com/teller-protocol/teller-protocol-v2/blob/cc7fb9358a2518de7ee33e518ebac21eac498b0d/contracts/interfaces/IASResolver.sol)


## Functions
### isPayable

*Returns whether the resolver supports ETH transfers*


```solidity
function isPayable() external pure returns (bool);
```

### resolve

*Resolves an attestation and verifier whether its data conforms to the spec.*


```solidity
function resolve(
    address recipient,
    bytes calldata schema,
    bytes calldata data,
    uint256 expirationTime,
    address msgSender
) external payable returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipient`|`address`|The recipient of the attestation.|
|`schema`|`bytes`|The AS data schema.|
|`data`|`bytes`|The actual attestation data.|
|`expirationTime`|`uint256`|The expiration time of the attestation.|
|`msgSender`|`address`|The sender of the original attestation message.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the data is valid according to the scheme.|


