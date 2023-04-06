# ICollateralEscrowV1
[Git Source](https://github.com/teller-protocol/teller-protocol-v2/blob/cc7fb9358a2518de7ee33e518ebac21eac498b0d/contracts/interfaces/escrow/ICollateralEscrowV1.sol)


## Functions
### depositAsset

Deposits a collateral asset into the escrow.


```solidity
function depositAsset(CollateralType _collateralType, address _collateralAddress, uint256 _amount, uint256 _tokenId)
    external
    payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_collateralType`|`CollateralType`|The type of collateral asset to deposit (ERC721, ERC1155).|
|`_collateralAddress`|`address`|The address of the collateral token.|
|`_amount`|`uint256`|The amount to deposit.|
|`_tokenId`|`uint256`||


### withdraw

Withdraws a collateral asset from the escrow.


```solidity
function withdraw(address _collateralAddress, uint256 _amount, address _recipient) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_collateralAddress`|`address`|The address of the collateral contract.|
|`_amount`|`uint256`|The amount to withdraw.|
|`_recipient`|`address`|The address to send the assets to.|


### getBid


```solidity
function getBid() external view returns (uint256);
```

### initialize


```solidity
function initialize(uint256 _bidId) external;
```

