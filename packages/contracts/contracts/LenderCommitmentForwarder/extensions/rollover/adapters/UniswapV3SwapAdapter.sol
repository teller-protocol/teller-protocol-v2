// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../../../interfaces/ISwapAdapter.sol";
import "../../../../libraries/uniswap/periphery/interfaces/IQuoterV4.sol";
import "../../../../libraries/uniswap/periphery/libraries/TransferHelper.sol";

/// @notice V3-compatible swap router interface with deadline field.
///         Works with both Uniswap V3 SwapRouter and PancakeSwap V3 SmartRouter.
interface ISwapRouterV3 {
    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);
}

/// @title UniswapV3SwapAdapter
/// @notice ISwapAdapter implementation for Uniswap V3 (and compatible forks like PancakeSwap V3).
///         Caller provides a pre-encoded Uniswap V3 path: (tokenIn ++ fee ++ tokenOut) per hop.
contract UniswapV3SwapAdapter is ISwapAdapter {

    ISwapRouterV3 public immutable SWAP_ROUTER;
    IQuoterV4 public immutable QUOTER;

    /// @param _swapRouter Uniswap V3 / PancakeSwap V3 swap router address
    /// @param _quoter QuoterV2 address
    constructor(address _swapRouter, address _quoter) {
        SWAP_ROUTER = ISwapRouterV3(_swapRouter);
        QUOTER = IQuoterV4(_quoter);
    }

    /// @inheritdoc ISwapAdapter
    function swap(
        bytes calldata path,
        uint256 amountIn,
        uint256 amountOutMinimum,
        address recipient
    ) external override returns (uint256 amountOut) {
        // Extract tokenIn from the first 20 bytes of the path
        address tokenIn;
        assembly { tokenIn := shr(96, calldataload(path.offset)) }

        TransferHelper.safeTransferFrom(tokenIn, msg.sender, address(this), amountIn);
        TransferHelper.safeApprove(tokenIn, address(SWAP_ROUTER), amountIn);

        ISwapRouterV3.ExactInputParams memory params = ISwapRouterV3.ExactInputParams({
            path: path,
            recipient: recipient,
            deadline: block.timestamp,
            amountIn: amountIn,
            amountOutMinimum: amountOutMinimum
        });

        amountOut = SWAP_ROUTER.exactInput(params);
    }

    /// @inheritdoc ISwapAdapter
    function quote(
        bytes calldata path,
        uint256 amountIn
    ) external override returns (uint256 amountOut) {
        (amountOut, , , ) = QUOTER.quoteExactInput(path, amountIn);
    }
}
