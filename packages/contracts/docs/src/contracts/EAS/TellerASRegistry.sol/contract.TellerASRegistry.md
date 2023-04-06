# TellerASRegistry
[Git Source](https://github.com/teller-protocol/teller-protocol-v2/blob/cc7fb9358a2518de7ee33e518ebac21eac498b0d/contracts/EAS/TellerASRegistry.sol)

**Inherits:**
[IASRegistry](/contracts/interfaces/IASRegistry.sol/interface.IASRegistry.md)


## State Variables
### VERSION

```solidity
string public constant VERSION = "0.8";
```


### _registry

```solidity
mapping(bytes32 => ASRecord) private _registry;
```


### _asCount

```solidity
uint256 private _asCount;
```


## Functions
### register

*Submits and reserve a new AS*


```solidity
function register(bytes calldata schema, IASResolver resolver) external override returns (bytes32);
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
function getAS(bytes32 uuid) external view override returns (ASRecord memory);
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
function getASCount() external view override returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The global counter for the total number of attestations.|


### _getUUID

*Calculates a UUID for a given AS.*


```solidity
function _getUUID(ASRecord memory asRecord) private pure returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asRecord`|`ASRecord`|The input AS.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|AS UUID.|


## Errors
### AlreadyExists

```solidity
error AlreadyExists();
```

