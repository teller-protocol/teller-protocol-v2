// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "../contracts/TellerV2MarketForwarder.sol";
import { Testable } from "./Testable.sol";
import { LenderManager } from "../contracts/LenderManager.sol";

import "../contracts/mock/MarketRegistryMock.sol";

import { User } from "./Test_Helpers.sol";

import { TellerV2Context } from "../contracts/TellerV2Context.sol";

contract LenderManager_Override is  LenderManager {
   

    bool mockedHasMarketVerification;

    constructor(address marketRegistry)
        LenderManager( 
            new MarketRegistryMock(marketRegistry)
        )
    {}

    function setHasMarketVerification(bool v) public {
          mockedHasMarketVerification = v;
    }

    //override
    function _hasMarketVerification(address _lender, uint256 _bidId)
        internal
        view
        override
        returns (bool)
    {
        return mockedHasMarketVerification;
    }


    function exists(uint256 tokenId)
        public
        view 
        returns (bool)
    {
        return super._exists(tokenId);
    }

    function mint(address to, uint256 tokenId)
        public    
    {
         super._mint(to,tokenId);
    }


    //should be able to test the negative case-- use foundry
    function _checkOwner() internal view override {
        // do nothing
    }
}
 