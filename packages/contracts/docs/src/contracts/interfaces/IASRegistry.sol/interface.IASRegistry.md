# IASRegistry
[Git Source](https://github.com/teller-protocol/teller-protocol-v2/blob/cc7fb9358a2518de7ee33e518ebac21eac498b0d/contracts/interfaces/IASRegistry.sol)


## Functions
### register

*Submits and reserve a new AS*


```solidity
function register(bytes calldata schema, IASResolver resolver) external returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`schema`|`bytes`|The AS data schema.|
|`resolver`|`IASResolver`|An optional AS schema resolver.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The UUID of the new AS.|


### getAS

*Returns an existing AS by UUID*


```solidity
function getAS(bytes32 uuid) external view returns (ASRecord memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`uuid`|`bytes32`|The UUID of the AS to retrieve.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`ASRecord`|The AS data members.|


### getASCount

*Returns the global counter for the total number of attestations*


```solidity
function getASCount() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The global counter for the total number of attestations.|


## Events
### Registered
*Triggered when a new AS has been registered*


```solidity
event Registered(bytes32 indexed uuid, uint256 indexed index, bytes schema, IASResolver resolver, address attester);
```

## Structs
### ASRecord

```solidity
struct ASRecord {
    bytes32 uuid;
    IASResolver resolver;
    uint256 index;
    bytes schema;
}
```

