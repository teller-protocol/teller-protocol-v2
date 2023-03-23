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
     using EnumerableSet for EnumerableSet.AddressSet;
    
    address globalMarketOwner;


    bool public attestStakeholderWasCalled;
    bool public attestStakeholderVerificationWasCalled;

    constructor() MarketRegistry() {}


    function setMarketOwner(
        address _owner
    ) public {
        globalMarketOwner = _owner;
    }
    

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


    function attestStakeholderVerification(
         uint256 _marketId,
        address _stakeholderAddress,
        bytes32 _uuid,
        bool _isLender

    ) public {  
        super._attestStakeholderVerification(_marketId,_stakeholderAddress,_uuid,_isLender);
    }


    //overrides 

    function _getMarketOwner(uint256 marketId) internal view override returns (address) {
        return globalMarketOwner;
    }

    function _attestStakeholder(
         uint256 _marketId,
        address _stakeholderAddress,
        uint256 _expirationTime,
        bool _isLender

    ) internal override {
        attestStakeholderWasCalled = true;
    } 

    function _attestStakeholderVerification(
         uint256 _marketId,
        address _stakeholderAddress,
        bytes32 _uuid,
        bool _isLender

    ) internal override {  
       attestStakeholderVerificationWasCalled = true;
    }


    function marketVerifiedLendersContains(uint256 _marketId, address guy) public returns (bool) {
        return markets[_marketId].verifiedLendersForMarket.contains(guy);
    }

    function marketVerifiedBorrowersContains(uint256 _marketId, address guy) public returns (bool) {
        return markets[_marketId].verifiedBorrowersForMarket.contains(guy);
    }

    function getLenderAttestationId(uint256 _marketId, address guy) public returns (bytes32){

        return markets[_marketId].lenderAttestationIds[guy];

    }

    function getBorrowerAttestationId(uint256 _marketId, address guy) public returns (bytes32){

        return markets[_marketId].borrowerAttestationIds[guy];

    }
  

}

 