 // SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

 

/**
 * @title IPool
 * @author Aave
 * @notice Defines the basic interface for an Aave Pool.
 */
interface IAerodromePool {
  
 
    function observations(uint256 ticks ) external view returns ( uint256, uint256, uint256  );

    
}
