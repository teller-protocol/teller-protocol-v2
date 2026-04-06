// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

/**
 * @title IAlgebraPool
 * @notice Interface for Algebra V1 pools (used by Camelot V3 on ApeChain).
 *         Algebra pools use globalState() and getTimepoints() instead of
 *         Uniswap V3's slot0() and observe().
 */
interface IAlgebraPool {
    function token0() external view returns (address);
    function token1() external view returns (address);

    function globalState() external view returns (
        uint160 price,
        int24 tick,
        uint16 feeZto,
        uint16 feeOtz,
        uint16 timepointIndex,
        uint8 communityFeeToken0,
        uint8 communityFeeToken1,
        bool unlocked
    );

    function getTimepoints(uint32[] calldata secondsAgos) external view returns (
        int56[] memory tickCumulatives,
        uint160[] memory secondsPerLiquidityCumulatives
    );
}
