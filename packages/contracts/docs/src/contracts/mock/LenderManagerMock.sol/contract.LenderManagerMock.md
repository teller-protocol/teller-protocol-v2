# LenderManagerMock
[Git Source](https://github.com/teller-protocol/teller-protocol-v2/blob/cc7fb9358a2518de7ee33e518ebac21eac498b0d/contracts/mock/LenderManagerMock.sol)

**Inherits:**
[ILenderManager](/contracts/interfaces/ILenderManager.sol/abstract.ILenderManager.md), ERC721Upgradeable


## State Variables
### registeredLoan

```solidity
mapping(uint256 => address) public registeredLoan;
```


## Functions
### constructor


```solidity
constructor();
```

### registerLoan


```solidity
function registerLoan(uint256 _bidId, address _newLender) external override;
```

### ownerOf


```solidity
function ownerOf(uint256 _bidId) public view override(ERC721Upgradeable, IERC721Upgradeable) returns (address);
```

