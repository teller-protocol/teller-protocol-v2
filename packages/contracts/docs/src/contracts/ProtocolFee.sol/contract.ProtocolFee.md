# ProtocolFee
[Git Source](https://github.com/teller-protocol/teller-protocol-v2/blob/cc7fb9358a2518de7ee33e518ebac21eac498b0d/contracts/ProtocolFee.sol)

**Inherits:**
OwnableUpgradeable


## State Variables
### _protocolFee

```solidity
uint16 private _protocolFee;
```


## Functions
### __ProtocolFee_init

Initialized the protocol fee.


```solidity
function __ProtocolFee_init(uint16 initFee) internal onlyInitializing;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`initFee`|`uint16`|The initial protocol fee to be set on the protocol.|


### __ProtocolFee_init_unchained


```solidity
function __ProtocolFee_init_unchained(uint16 initFee) internal onlyInitializing;
```

### protocolFee

Returns the current protocol fee.


```solidity
function protocolFee() public view virtual returns (uint16);
```

### setProtocolFee

Lets the DAO/owner of the protocol to set a new protocol fee.


```solidity
function setProtocolFee(uint16 newFee) public virtual onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newFee`|`uint16`|The new protocol fee to be set.|


## Events
### ProtocolFeeSet
This event is emitted when the protocol fee has been updated.


```solidity
event ProtocolFeeSet(uint16 newFee, uint16 oldFee);
```

