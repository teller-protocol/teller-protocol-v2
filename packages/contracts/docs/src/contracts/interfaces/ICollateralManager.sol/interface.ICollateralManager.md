# ICollateralManager
[Git Source](https://github.com/teller-protocol/teller-protocol-v2/blob/cc7fb9358a2518de7ee33e518ebac21eac498b0d/contracts/interfaces/ICollateralManager.sol)


## Functions
### commitCollateral

Checks the validity of a borrower's collateral balance.


```solidity
function commitCollateral(uint256 _bidId, Collateral[] calldata _collateralInfo) external returns (bool validation_);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_bidId`|`uint256`|The id of the associated bid.|
|`_collateralInfo`|`Collateral[]`|Additional information about the collateral asset.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`validation_`|`bool`|Boolean indicating if the collateral balance was validated.|


### commitCollateral

Checks the validity of a borrower's collateral balance and commits it to a bid.


```solidity
function commitCollateral(uint256 _bidId, Collateral calldata _collateralInfo) external returns (bool validation_);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_bidId`|`uint256`|The id of the associated bid.|
|`_collateralInfo`|`Collateral`|Additional information about the collateral asset.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`validation_`|`bool`|Boolean indicating if the collateral balance was validated.|


### checkBalances


```solidity
function checkBalances(address _borrowerAddress, Collateral[] calldata _collateralInfo)
    external
    returns (bool validated_, bool[] memory checks_);
```

### deployAndDeposit

Deploys a new collateral escrow.


```solidity
function deployAndDeposit(uint256 _bidId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_bidId`|`uint256`|The associated bidId of the collateral escrow.|


### getEscrow

Gets the address of a deployed escrow.

_bidId The bidId to return the escrow for.


```solidity
function getEscrow(uint256 _bidId) external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of the escrow.|


### getCollateralInfo

Gets the collateral info for a given bid id.


```solidity
function getCollateralInfo(uint256 _bidId) external view returns (Collateral[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_bidId`|`uint256`|The bidId to return the collateral info for.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`Collateral[]`|The stored collateral info.|


### getCollateralAmount


```solidity
function getCollateralAmount(uint256 _bidId, address collateralAssetAddress) external view returns (uint256 _amount);
```

### withdraw

Withdraws deposited collateral from the created escrow of a bid.


```solidity
function withdraw(uint256 _bidId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_bidId`|`uint256`|The id of the bid to withdraw collateral for.|


### revalidateCollateral

Re-checks the validity of a borrower's collateral balance committed to a bid.


```solidity
function revalidateCollateral(uint256 _bidId) external returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_bidId`|`uint256`|The id of the associated bid.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|validation_ Boolean indicating if the collateral balance was validated.|


### liquidateCollateral

Sends the deposited collateral to a liquidator of a bid.

Can only be called by the protocol.


```solidity
function liquidateCollateral(uint256 _bidId, address _liquidatorAddress) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_bidId`|`uint256`|The id of the liquidated bid.|
|`_liquidatorAddress`|`address`|The address of the liquidator to send the collateral to.|


