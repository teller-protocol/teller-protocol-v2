// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import '../../libraries/uniswap/periphery/interfaces/IQuoter.sol';

contract UniswapV3QuoterMock {
        
      function quoteExactInput(bytes memory path, uint256 amountIn)
        external view
        returns (
            uint256 amountOut,
            uint160[] memory sqrtPriceX96AfterList,
            uint32[] memory initializedTicksCrossedList,
            uint256 gasEstimate
        ) {

            // mock for now 
        }

}