// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title ISwapAdapter
/// @notice Abstraction over DEX-specific swap and quote logic.
///         Implementations handle path encoding, router calls, and quoter calls
///         for a specific DEX (Uniswap V3, Algebra/Camelot V3, etc.).
interface ISwapAdapter {

    /// @notice Execute an exact-input swap.
    /// @dev Caller must have approved this adapter for `amountIn` of `tokenIn`.
    ///      The adapter transfers tokens from caller, approves the DEX router,
    ///      and routes output tokens to `recipient`.
    /// @param tokenIn  Input token address
    /// @param tokenOut Final output token address
    /// @param intermediateTokens Tokens between input and output for multi-hop (empty for single-hop)
    /// @param amountIn Exact amount of tokenIn to swap
    /// @param amountOutMinimum Minimum acceptable output (slippage protection)
    /// @param recipient Address that receives the output tokens
    /// @return amountOut Actual amount of tokenOut received
    function swap(
        address tokenIn,
        address tokenOut,
        address[] calldata intermediateTokens,
        uint256 amountIn,
        uint256 amountOutMinimum,
        address recipient
    ) external returns (uint256 amountOut);

    /// @notice Quote the expected output for an exact-input swap without executing.
    /// @dev Not marked `view` because many DEX quoters use state-reverting simulation.
    /// @param tokenIn  Input token address
    /// @param tokenOut Final output token address
    /// @param intermediateTokens Tokens between input and output for multi-hop (empty for single-hop)
    /// @param amountIn Amount of tokenIn to quote
    /// @return amountOut Expected amount of tokenOut
    function quote(
        address tokenIn,
        address tokenOut,
        address[] calldata intermediateTokens,
        uint256 amountIn
    ) external returns (uint256 amountOut);
}
