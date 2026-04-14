// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../../../interfaces/ISwapAdapter.sol";
import "../../../../libraries/uniswap/periphery/interfaces/ISwapRouter02.sol";
import "../../../../libraries/uniswap/periphery/interfaces/IQuoter.sol";
import "../../../../libraries/uniswap/periphery/libraries/TransferHelper.sol";

/// @title UniswapV3SwapAdapter
/// @notice ISwapAdapter implementation for Uniswap V3 (and compatible forks like SushiSwap V3).
///         Handles Uniswap V3 path encoding: (tokenIn ++ fee ++ tokenOut) with 3-byte fee per hop.
contract UniswapV3SwapAdapter is ISwapAdapter {

    ISwapRouter02 public immutable SWAP_ROUTER;
    IQuoter public immutable QUOTER;
    uint24 public immutable DEFAULT_POOL_FEE;

    /// @param _swapRouter Uniswap V3 SwapRouter02 address
    /// @param _quoter Uniswap V3 Quoter (view-only) address
    /// @param _defaultPoolFee Default pool fee in hundredths of a bip (e.g. 500 = 0.05%, 3000 = 0.3%)
    constructor(address _swapRouter, address _quoter, uint24 _defaultPoolFee) {
        SWAP_ROUTER = ISwapRouter02(_swapRouter);
        QUOTER = IQuoter(_quoter);
        DEFAULT_POOL_FEE = _defaultPoolFee;
    }

    /// @inheritdoc ISwapAdapter
    function swap(
        address tokenIn,
        address tokenOut,
        address[] calldata intermediateTokens,
        uint256 amountIn,
        uint256 amountOutMinimum,
        address recipient
    ) external override returns (uint256 amountOut) {
        TransferHelper.safeTransferFrom(tokenIn, msg.sender, address(this), amountIn);
        TransferHelper.safeApprove(tokenIn, address(SWAP_ROUTER), amountIn);

        bytes memory path = _buildPath(tokenIn, tokenOut, intermediateTokens);

        ISwapRouter02.ExactInputParams memory params = ISwapRouter02.ExactInputParams({
            path: path,
            recipient: recipient,
            amountIn: amountIn,
            amountOutMinimum: amountOutMinimum
        });

        amountOut = SWAP_ROUTER.exactInput(params);
    }

    /// @inheritdoc ISwapAdapter
    function quote(
        address tokenIn,
        address tokenOut,
        address[] calldata intermediateTokens,
        uint256 amountIn
    ) external override returns (uint256 amountOut) {
        bytes memory path = _buildPath(tokenIn, tokenOut, intermediateTokens);
        (amountOut, , , ) = QUOTER.quoteExactInput(path, amountIn);
    }

    /// @dev Builds a Uniswap V3 encoded path: tokenIn ++ fee ++ [intermediate ++ fee ++]* tokenOut
    function _buildPath(
        address tokenIn,
        address tokenOut,
        address[] calldata intermediateTokens
    ) internal view returns (bytes memory path) {
        if (intermediateTokens.length == 0) {
            path = abi.encodePacked(tokenIn, DEFAULT_POOL_FEE, tokenOut);
        } else if (intermediateTokens.length == 1) {
            path = abi.encodePacked(
                tokenIn, DEFAULT_POOL_FEE,
                intermediateTokens[0], DEFAULT_POOL_FEE,
                tokenOut
            );
        } else {
            revert("UniswapV3SwapAdapter: max 2 hops");
        }
    }
}
