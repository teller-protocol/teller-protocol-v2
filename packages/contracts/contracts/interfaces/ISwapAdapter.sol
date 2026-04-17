// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title ISwapAdapter
/// @notice Abstraction over DEX-specific swap and quote logic.
///         Callers provide a pre-encoded `path` in the format expected by
///         the target DEX (e.g. Uniswap V3: tokenIn ++ fee ++ tokenOut,
///         Algebra: tokenIn ++ tokenOut). This is consistent with how
///         IPriceAdapter handles arbitrary oracle routes via `bytes`.
interface ISwapAdapter {

    /// @notice Execute an exact-input swap.
    /// @dev Caller must have approved this adapter for `amountIn` of the input token.
    ///      The adapter transfers tokens from caller, approves the DEX router,
    ///      and routes output tokens to `recipient`.
    /// @param path DEX-encoded swap path (token addresses + fees as needed)
    /// @param amountIn Exact amount of input token to swap
    /// @param amountOutMinimum Minimum acceptable output (slippage protection)
    /// @param recipient Address that receives the output tokens
    /// @return amountOut Actual amount of output token received
    function swap(
        bytes calldata path,
        uint256 amountIn,
        uint256 amountOutMinimum,
        address recipient
    ) external returns (uint256 amountOut);

    /// @notice Quote the expected output for an exact-input swap without executing.
    /// @dev Not marked `view` because many DEX quoters use state-reverting simulation.
    /// @param path DEX-encoded swap path
    /// @param amountIn Amount of input token to quote
    /// @return amountOut Expected amount of output token
    function quote(
        bytes calldata path,
        uint256 amountIn
    ) external returns (uint256 amountOut);
}
