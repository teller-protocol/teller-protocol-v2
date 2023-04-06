# NumbersLib
[Git Source](https://github.com/teller-protocol/teller-protocol-v2/blob/cc7fb9358a2518de7ee33e518ebac21eac498b0d/contracts/libraries/NumbersLib.sol)

**Author:**
develop@teller.finance

*Utility library for uint256 numbers*


## State Variables
### PCT_100
*It represents 100% with 2 decimal places.*


```solidity
uint16 internal constant PCT_100 = 10000;
```


## Functions
### percentFactor


```solidity
function percentFactor(uint256 decimals) internal pure returns (uint256);
```

### percent

Returns a percentage value of a number.


```solidity
function percent(uint256 self, uint16 percentage) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`self`|`uint256`|The number to get a percentage of.|
|`percentage`|`uint16`|The percentage value to calculate with 2 decimal places (10000 = 100%).|


### percent

Returns a percentage value of a number.


```solidity
function percent(uint256 self, uint256 percentage, uint256 decimals) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`self`|`uint256`|The number to get a percentage of.|
|`percentage`|`uint256`|The percentage value to calculate with.|
|`decimals`|`uint256`|The number of decimals the percentage value is in.|


### abs

it returns the absolute number of a specified parameter


```solidity
function abs(int256 self) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`self`|`int256`|the number to be returned in it's absolute|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|the absolute number|


### ratioOf

Returns a ratio percentage of {num1} to {num2}.

*Returned value is type uint16.*


```solidity
function ratioOf(uint256 num1, uint256 num2) internal pure returns (uint16);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`num1`|`uint256`|The number used to get the ratio for.|
|`num2`|`uint256`|The number used to get the ratio from.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint16`|Ratio percentage with 2 decimal places (10000 = 100%).|


### ratioOf

Returns a ratio percentage of {num1} to {num2}.


```solidity
function ratioOf(uint256 num1, uint256 num2, uint256 decimals) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`num1`|`uint256`|The number used to get the ratio for.|
|`num2`|`uint256`|The number used to get the ratio from.|
|`decimals`|`uint256`|The number of decimals the percentage value is returned in.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Ratio percentage value.|


### pmt

Calculates the payment amount for a cycle duration.
The formula is calculated based on the standard Estimated Monthly Installment (https://en.wikipedia.org/wiki/Equated_monthly_installment)
EMI = [P x R x (1+R)^N]/[(1+R)^N-1]


```solidity
function pmt(uint256 principal, uint32 loanDuration, uint32 cycleDuration, uint16 apr, uint256 daysInYear)
    internal
    pure
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`principal`|`uint256`|The starting amount that is owed on the loan.|
|`loanDuration`|`uint32`|The length of the loan.|
|`cycleDuration`|`uint32`|The length of the loan's payment cycle.|
|`apr`|`uint16`|The annual percentage rate of the loan.|
|`daysInYear`|`uint256`||


