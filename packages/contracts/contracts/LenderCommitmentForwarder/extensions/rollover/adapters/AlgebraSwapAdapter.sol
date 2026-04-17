// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../../../interfaces/ISwapAdapter.sol";
import "../../../../libraries/uniswap/periphery/libraries/TransferHelper.sol";

/// @notice Algebra (Camelot V3) swap router — same ExactInputParams struct as Uniswap V3
///         but path encoding has NO fee bytes: just (tokenIn ++ tokenOut) per hop.
interface IAlgebraSwapRouter {
    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);
}

/// @notice Algebra quoter — uses quoteExactInput with fee-less paths,
///         and quoteExactInputSingle for single-hop without path encoding.
interface IAlgebraQuoter {
    function quoteExactInput(bytes memory path, uint256 amountIn)
        external
        returns (uint256 amountOut, uint16[] memory fees);

    function quoteExactInputSingle(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint160 limitSqrtPrice
    ) external returns (uint256 amountOut, uint16 fee);
}

/// @title AlgebraSwapAdapter
/// @notice ISwapAdapter implementation for Algebra-based DEXes (Camelot V3, etc.).
///         Caller provides a pre-encoded Algebra path: (tokenIn ++ tokenOut) per hop (no fee bytes).
contract AlgebraSwapAdapter is ISwapAdapter {

    IAlgebraSwapRouter public immutable SWAP_ROUTER;
    IAlgebraQuoter public immutable QUOTER;

    /// @param _swapRouter Algebra SwapRouter address
    /// @param _quoter Algebra Quoter address
    constructor(address _swapRouter, address _quoter) {
        SWAP_ROUTER = IAlgebraSwapRouter(_swapRouter);
        QUOTER = IAlgebraQuoter(_quoter);
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

        IAlgebraSwapRouter.ExactInputParams memory params = IAlgebraSwapRouter.ExactInputParams({
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
        (amountOut, ) = QUOTER.quoteExactInput(path, amountIn);
    }
}
