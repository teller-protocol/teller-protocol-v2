// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IPriceAdapter.sol";

contract MockPriceAdapter is IPriceAdapter {
    uint256 public mockPriceRatioQ96;
    mapping(bytes32 => bytes) public priceRoutes;

    function setMockPriceRatioQ96(uint256 _price) external {
        mockPriceRatioQ96 = _price;
    }

    function registerPriceRoute(bytes memory route) external returns (bytes32) {
        bytes32 routeHash = keccak256(route);
        priceRoutes[routeHash] = route;
        return routeHash;
    }

    function getPriceRatioQ96(bytes32 route) external view returns (uint256) {
        require(priceRoutes[route].length > 0, "Route not found");
        return mockPriceRatioQ96;
    }
}
