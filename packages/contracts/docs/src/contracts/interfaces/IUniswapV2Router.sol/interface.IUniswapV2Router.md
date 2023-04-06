# IUniswapV2Router
[Git Source](https://github.com/teller-protocol/teller-protocol-v2/blob/cc7fb9358a2518de7ee33e518ebac21eac498b0d/contracts/interfaces/IUniswapV2Router.sol)

**Author:**
develop@teller.finance

This interface defines the different functions available for a UniswapV2Router.


## Functions
### factory


```solidity
function factory() external pure returns (address);
```

### addLiquidity


```solidity
function addLiquidity(
    address tokenA,
    address tokenB,
    uint256 amountADesired,
    uint256 amountBDesired,
    uint256 amountAMin,
    uint256 amountBMin,
    address to,
    uint256 deadline
) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);
```

### addLiquidityETH


```solidity
function addLiquidityETH(
    address token,
    uint256 amountTokenDesired,
    uint256 amountTokenMin,
    uint256 amountETHMin,
    address to,
    uint256 deadline
) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);
```

### removeLiquidity


```solidity
function removeLiquidity(
    address tokenA,
    address tokenB,
    uint256 liquidity,
    uint256 amountAMin,
    uint256 amountBMin,
    address to,
    uint256 deadline
) external returns (uint256 amountA, uint256 amountB);
```

### removeLiquidityETH


```solidity
function removeLiquidityETH(
    address token,
    uint256 liquidity,
    uint256 amountTokenMin,
    uint256 amountETHMin,
    address to,
    uint256 deadline
) external returns (uint256 amountToken, uint256 amountETH);
```

### removeLiquidityWithPermit


```solidity
function removeLiquidityWithPermit(
    address tokenA,
    address tokenB,
    uint256 liquidity,
    uint256 amountAMin,
    uint256 amountBMin,
    address to,
    uint256 deadline,
    bool approveMax,
    uint8 v,
    bytes32 r,
    bytes32 s
) external returns (uint256 amountA, uint256 amountB);
```

### removeLiquidityETHWithPermit


```solidity
function removeLiquidityETHWithPermit(
    address token,
    uint256 liquidity,
    uint256 amountTokenMin,
    uint256 amountETHMin,
    address to,
    uint256 deadline,
    bool approveMax,
    uint8 v,
    bytes32 r,
    bytes32 s
) external returns (uint256 amountToken, uint256 amountETH);
```

### quote


```solidity
function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) external pure returns (uint256 amountB);
```

### getAmountOut


```solidity
function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
    external
    pure
    returns (uint256 amountOut);
```

### getAmountIn


```solidity
function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
    external
    pure
    returns (uint256 amountIn);
```

### getAmountsOut


```solidity
function getAmountsOut(uint256 amountIn, address[] calldata path) external view returns (uint256[] memory amounts);
```

### getAmountsIn


```solidity
function getAmountsIn(uint256 amountOut, address[] calldata path) external view returns (uint256[] memory amounts);
```

### WETH

It returns the address of the canonical WETH address;


```solidity
function WETH() external pure returns (address);
```

### swapExactTokensForTokens

Swaps an exact amount of input tokens for as many output tokens as possible, along the route determined by the path. The first element of path is the input token, the last is the output token, and any intermediate elements represent intermediate pairs to trade through (if, for example, a direct pair does not exist).

*msg.sender should have already given the router an allowance of at least amountIn on the input token.*


```solidity
function swapExactTokensForTokens(
    uint256 amountIn,
    uint256 amountOutMin,
    address[] calldata path,
    address to,
    uint256 deadline
) external returns (uint256[] memory amounts);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amountIn`|`uint256`|The amount of input tokens to send.|
|`amountOutMin`|`uint256`|The minimum amount of output tokens that must be received for the transaction not to revert.|
|`path`|`address[]`|An array of token addresses. path.length must be >= 2. Pools for each consecutive pair of addresses must exist and have liquidity.|
|`to`|`address`|Recipient of the output tokens.|
|`deadline`|`uint256`|Unix timestamp after which the transaction will revert.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amounts`|`uint256[]`|The input token amount and all subsequent output token amounts.|


### swapExactTokensForETH

Swaps an exact amount of tokens for as much ETH as possible, along the route determined by the path. The first element of path is the input token, the last must be WETH, and any intermediate elements represent intermediate pairs to trade through (if, for example, a direct pair does not exist).

*If the to address is a smart contract, it must have the ability to receive ETH.*


```solidity
function swapExactTokensForETH(
    uint256 amountIn,
    uint256 amountOutMin,
    address[] calldata path,
    address to,
    uint256 deadline
) external returns (uint256[] memory amounts);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amountIn`|`uint256`|The amount of input tokens to send.|
|`amountOutMin`|`uint256`|The minimum amount of output tokens that must be received for the transaction not to revert.|
|`path`|`address[]`|An array of token addresses. path.length must be >= 2. Pools for each consecutive pair of addresses must exist and have liquidity.|
|`to`|`address`|Recipient of the ETH.|
|`deadline`|`uint256`|Unix timestamp after which the transaction will revert.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amounts`|`uint256[]`|The input token amount and all subsequent output token amounts.|


### swapExactETHForTokens

Swaps an exact amount of ETH for as many output tokens as possible, along the route determined by the path. The first element of path must be WETH, the last is the output token, and any intermediate elements represent intermediate pairs to trade through (if, for example, a direct pair does not exist).


```solidity
function swapExactETHForTokens(uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)
    external
    payable
    returns (uint256[] memory amounts);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amountOutMin`|`uint256`|The minimum amount of output tokens that must be received for the transaction not to revert.|
|`path`|`address[]`|An array of token addresses. path.length must be >= 2. Pools for each consecutive pair of addresses must exist and have liquidity.|
|`to`|`address`|Recipient of the output tokens.|
|`deadline`|`uint256`|Unix timestamp after which the transaction will revert.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amounts`|`uint256[]`|The input token amount and all subsequent output token amounts.|


### swapTokensForExactTokens


```solidity
function swapTokensForExactTokens(
    uint256 amountOut,
    uint256 amountInMax,
    address[] calldata path,
    address to,
    uint256 deadline
) external returns (uint256[] memory amounts);
```

### swapTokensForExactETH


```solidity
function swapTokensForExactETH(
    uint256 amountOut,
    uint256 amountInMax,
    address[] calldata path,
    address to,
    uint256 deadline
) external returns (uint256[] memory amounts);
```

### swapETHForExactTokens


```solidity
function swapETHForExactTokens(uint256 amountOut, address[] calldata path, address to, uint256 deadline)
    external
    payable
    returns (uint256[] memory amounts);
```

