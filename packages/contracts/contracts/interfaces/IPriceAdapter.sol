// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IPriceAdapter {
    
    function registerPriceRoute(bytes memory route) external returns (bytes32);

    function getPriceRatioQ96( bytes32 route ) external view returns( uint256 );
}
