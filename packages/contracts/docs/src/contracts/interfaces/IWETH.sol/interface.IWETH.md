# IWETH
[Git Source](https://github.com/teller-protocol/teller-protocol-v2/blob/cc7fb9358a2518de7ee33e518ebac21eac498b0d/contracts/interfaces/IWETH.sol)

**Author:**
develop@teller.finance

It is the interface of functions that we use for the canonical WETH contract.


## Functions
### withdraw

It withdraws ETH from the contract by sending it to the caller and reducing the caller's internal balance of WETH.


```solidity
function withdraw(uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount of ETH to withdraw.|


### deposit

It deposits ETH into the contract and increases the caller's internal balance of WETH.


```solidity
function deposit() external payable;
```

### balanceOf

It gets the ETH deposit balance of an {account}.


```solidity
function balanceOf(address account) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|Address to get balance of.|


### transfer

It transfers the WETH amount specified to the given {account}.


```solidity
function transfer(address to, uint256 value) external returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|Address to transfer to|
|`value`|`uint256`|Amount of WETH to transfer|


