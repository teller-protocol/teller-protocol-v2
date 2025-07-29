// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IPriceAdapter {
    
    function registerPriceRoute(bytes[] route) external returns (bytes32);

    function getPrice(bytes32 route, uint256 inAmount) external ;
}
