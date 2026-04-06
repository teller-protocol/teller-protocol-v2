// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

/**
 * @title IAerodromePool
 * @notice Defines the basic interface for an Aerodrome Pool.
 */
interface IAerodromePool {
    function lastObservation() external view returns (uint256, uint256, uint256);
    function observationLength() external view returns (uint256 );

    function observations(uint256 ticks) external view returns (uint256, uint256, uint256);

    function token0() external view returns (address);

    function token1() external view returns (address);
}
