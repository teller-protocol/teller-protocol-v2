// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMarketRegistry {

    
     function getMarketOwner(uint256 _marketId) external view returns (address);

    
     function getMarketplaceFee(uint256 _marketId)
        external
        view
        returns (uint16);


}