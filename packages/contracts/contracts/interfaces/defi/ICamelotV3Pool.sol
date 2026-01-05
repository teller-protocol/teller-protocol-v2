

// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

interface ICamelotV3Pool {

	function globalState()
        external
        view
        returns (
           

     uint160 price, // The square root of the current price in Q64.96 format
    int24 tick, // The current tick
    uint16 feeZto, // The current fee for ZtO swap in hundredths of a bip, i.e. 1e-6
    uint16 feeOtz, // The current fee for OtZ swap in hundredths of a bip, i.e. 1e-6
    uint16 timepointIndex, // The index of the last written timepoint
    uint8 communityFeeToken0, // The community fee represented as a percent of all collected fee in thousandths (1e-3)
    uint8 communityFeeToken1,
    bool unlocked // True if the contract is unlocked, otherwise - false
    
        );

 function getTimepoints(uint32[] calldata secondsAgos)
    external
    view
    returns (
      int56[] memory tickCumulatives,
      uint160[] memory secondsPerLiquidityCumulatives,
      uint112[] memory volatilityCumulatives,
      uint256[] memory volumePerAvgLiquiditys
    );

      /// @notice The first of the two tokens of the pool, sorted by address
    /// @return The token contract address
    function token0() external view returns (address);

    /// @notice The second of the two tokens of the pool, sorted by address
    /// @return The token contract address
    function token1() external view returns (address);

    /// @notice The pool's fee in hundredths of a bip, i.e. 1e-6
    /// @dev Can be changed dynamically
    /// @return The fee
    function fee() external view returns (uint16);

    /// @notice The pool tick spacing
    /// @dev Ticks can only be used at multiples of this value
    /// e.g.: a tickSpacing of 60 means ticks can be initialized every 60th tick, i.e., ..., -120, -60, 0, 60, 120, ...
    /// @return The tick spacing
    function tickSpacing() external view returns (int24);

    /// @notice The currently in range liquidity available to the pool
    /// @return The liquidity at the current price of the pool
    function liquidity() external view returns (uint128);
}

 