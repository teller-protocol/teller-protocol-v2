// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import '../../libraries/uniswap/periphery/interfaces/ISwapRouter02.sol';

contract UniswapV3Router02Mock {
    event SwapExecuted(address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);

  
    function exactInput(
        ISwapRouter02.ExactInputParams memory swapParams 
    ) external payable returns (uint256 amountOut) {
         // decodes the path and performs the swaps 
    }

}