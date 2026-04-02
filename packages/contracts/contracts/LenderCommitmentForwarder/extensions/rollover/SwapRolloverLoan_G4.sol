// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SwapRolloverLoan_G3.sol";

/// @notice Minimal interface for Algebra (Camelot V3) factory — no fee tiers
interface IAlgebraFactory {
    function poolByPair(address tokenA, address tokenB) external view returns (address pool);
}

/**
 * @title SwapRolloverLoan_G4
 * @notice Adds Algebra (Camelot V3) flash callback compatibility.
 * @dev Algebra pools call `algebraFlashCallback` instead of `uniswapV3FlashCallback` or
 *      `pancakeV3FlashCallback`. Additionally, Algebra factories use `poolByPair(tokenA, tokenB)`
 *      instead of `getPool(tokenA, tokenB, fee)` — there are no fee tiers.
 *
 *      This generation:
 *        1. Adds `algebraFlashCallback()` routed through `_flashCallback()`
 *        2. Overrides `_verifyFlashCallback()` to fall back to `poolByPair()` when `getPool()` reverts
 *        3. Overrides `getUniswapPoolAddress()` with the same fallback
 */
contract SwapRolloverLoan_G4 is SwapRolloverLoan_G3 {

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address _tellerV2,
        address _factory,
        address _WETH9
    ) SwapRolloverLoan_G3(_tellerV2, _factory, _WETH9) {}

    /**
     * @dev Algebra (Camelot V3) uses a different callback name than Uniswap V3 and PancakeSwap V3.
     *      This allows the contract to work on chains using Camelot V3 (e.g. ApeChain).
     */
    function algebraFlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external {
        _flashCallback(fee0, fee1, data);
    }

    /**
     * @dev Overrides verification to support Algebra factory which uses `poolByPair` instead of `getPool`.
     *      Tries standard `getPool(token0, token1, fee)` first; falls back to `poolByPair(token0, token1)`.
     */
    function _verifyFlashCallback(
        address token0,
        address token1,
        uint24 fee,
        address _msgSender
    ) internal override {
        address poolAddress = _resolvePool(token0, token1, fee);
        require(_msgSender == poolAddress, "Invalid flash callback caller");
    }

    /**
     * @dev Overrides pool lookup to support Algebra factory.
     */
    function getUniswapPoolAddress(
        address token0,
        address token1,
        uint24 fee
    ) public view override returns (address) {
        return _resolvePool(token0, token1, fee);
    }

    /**
     * @dev Tries `getPool(token0, token1, fee)` on the factory. If that reverts (Algebra factory),
     *      falls back to `poolByPair(token0, token1)`.
     */
    function _resolvePool(
        address token0,
        address token1,
        uint24 fee
    ) internal view returns (address) {
        // Try standard Uniswap V3 / PancakeSwap V3 factory first
        (bool success, bytes memory data) = factory.staticcall(
            abi.encodeWithSelector(IUniswapV3Factory.getPool.selector, token0, token1, fee)
        );

        if (success && data.length >= 32) {
            address pool = abi.decode(data, (address));
            if (pool != address(0)) return pool;
        }

        // Fall back to Algebra factory (poolByPair — no fee parameter)
        return IAlgebraFactory(factory).poolByPair(token0, token1);
    }
}
