# WadRayMath
[Git Source](https://github.com/teller-protocol/teller-protocol-v2/blob/cc7fb9358a2518de7ee33e518ebac21eac498b0d/contracts/libraries/WadRayMath.sol)

**Author:**
Multiplier Finance

*Provides mul and div function for wads (decimal numbers with 18 digits precision) and rays (decimals with 27 digits)*


## State Variables
### WAD

```solidity
uint256 internal constant WAD = 1e18;
```


### halfWAD

```solidity
uint256 internal constant halfWAD = WAD / 2;
```


### RAY

```solidity
uint256 internal constant RAY = 1e27;
```


### halfRAY

```solidity
uint256 internal constant halfRAY = RAY / 2;
```


### WAD_RAY_RATIO

```solidity
uint256 internal constant WAD_RAY_RATIO = 1e9;
```


### PCT_WAD_RATIO

```solidity
uint256 internal constant PCT_WAD_RATIO = 1e14;
```


### PCT_RAY_RATIO

```solidity
uint256 internal constant PCT_RAY_RATIO = 1e23;
```


## Functions
### ray


```solidity
function ray() internal pure returns (uint256);
```

### wad


```solidity
function wad() internal pure returns (uint256);
```

### halfRay


```solidity
function halfRay() internal pure returns (uint256);
```

### halfWad


```solidity
function halfWad() internal pure returns (uint256);
```

### wadMul


```solidity
function wadMul(uint256 a, uint256 b) internal pure returns (uint256);
```

### wadDiv


```solidity
function wadDiv(uint256 a, uint256 b) internal pure returns (uint256);
```

### rayMul


```solidity
function rayMul(uint256 a, uint256 b) internal pure returns (uint256);
```

### rayDiv


```solidity
function rayDiv(uint256 a, uint256 b) internal pure returns (uint256);
```

### rayToWad


```solidity
function rayToWad(uint256 a) internal pure returns (uint256);
```

### rayToPct


```solidity
function rayToPct(uint256 a) internal pure returns (uint16);
```

### wadToPct


```solidity
function wadToPct(uint256 a) internal pure returns (uint16);
```

### wadToRay


```solidity
function wadToRay(uint256 a) internal pure returns (uint256);
```

### pctToRay


```solidity
function pctToRay(uint16 a) internal pure returns (uint256);
```

### pctToWad


```solidity
function pctToWad(uint16 a) internal pure returns (uint256);
```

### rayPow

*calculates base^duration. The code uses the ModExp precompile*


```solidity
function rayPow(uint256 x, uint256 n) internal pure returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|z base^duration, in ray|


### wadPow


```solidity
function wadPow(uint256 x, uint256 n) internal pure returns (uint256);
```

### _pow


```solidity
function _pow(uint256 x, uint256 n, uint256 p, function(uint256, uint256) internal pure returns (uint256) mul)
    internal
    pure
    returns (uint256 z);
```

