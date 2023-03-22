// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Testable } from "./Testable.sol";

import { TellerV2 } from "../contracts/TellerV2.sol";
import { MarketRegistry } from "../contracts/MarketRegistry.sol";
 
 import "../contracts/TellerV2Context.sol";

import "../contracts/TellerV2Storage.sol";

import "../contracts/interfaces/IMarketRegistry.sol"; 

import "../contracts/EAS/TellerAS.sol";

import "../contracts/mock/WethMock.sol";
import "../contracts/interfaces/IWETH.sol";

import { User } from "./Test_Helpers.sol";
import { PaymentType, PaymentCycleType } from "../contracts/libraries/V2Calculations.sol";

contract MarketRegistry_Override is MarketRegistry {
   

    bool public attestStakeholderWasCalled;
    
    constructor() MarketRegistry() {}
    

       function attestStakeholder(
        uint256 _marketId,
        address _stakeholderAddress,
        uint256 _expirationTime,
        bool _isLender

    ) public  {
        super._attestStakeholder(
          _marketId,
          _stakeholderAddress,
          _expirationTime,
          _isLender
        );
    } 


    //overrides 

    function _attestStakeholder(
         uint256 _marketId,
        address _stakeholderAddress,
        uint256 _expirationTime,
        bool _isLender

    ) internal override {
        attestStakeholderWasCalled = true;
    } 

 



}

 