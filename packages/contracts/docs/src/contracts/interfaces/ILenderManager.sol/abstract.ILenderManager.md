# ILenderManager
[Git Source](https://github.com/teller-protocol/teller-protocol-v2/blob/cc7fb9358a2518de7ee33e518ebac21eac498b0d/contracts/interfaces/ILenderManager.sol)

**Inherits:**
IERC721Upgradeable


## Functions
### registerLoan

Registers a new active lender for a loan, minting the nft.


```solidity
function registerLoan(uint256 _bidId, address _newLender) external virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_bidId`|`uint256`|The id for the loan to set.|
|`_newLender`|`address`|The address of the new active lender.|


