// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;


import "./MarketRegistry_G2.sol";

contract MarketRegistry is 
    MarketRegistry_G2
{
    /*constructor(address _tellerV2, address _marketRegistry)
        MarketRegistry_G2(_tellerV2, _marketRegistry)
    {
        // we only want this on an proxy deployment so it only affects the impl
        //_disableInitializers();
    }*/
}
