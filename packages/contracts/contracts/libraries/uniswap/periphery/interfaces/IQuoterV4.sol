// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;
pragma abicoder v2;

/// @title IQuoterV4
/// @notice Non-view version of the Uniswap V3 Quoter interface.
/// @dev QuoterV2 contracts (Uniswap, PancakeSwap, etc.) use state-reverting simulation
///      internally (try a swap, revert, decode the output). The canonical IQuoter marks
///      these functions as `view`, which causes Solidity to emit STATICCALL. This fails
///      in Forge fork tests (and some on-chain contexts) because the simulated swap
///      attempts state modifications inside a static context.
///
///      This interface removes the `view` modifier so Solidity emits a regular CALL,
///      allowing the quoter's internal simulation to work correctly.
interface IQuoterV4 {
    function quoteExactInput(bytes memory path, uint256 amountIn)
        external
        returns (
            uint256 amountOut,
            uint160[] memory sqrtPriceX96AfterList,
            uint32[] memory initializedTicksCrossedList,
            uint256 gasEstimate
        );
}
