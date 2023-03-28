// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { StdStorage, stdStorage } from "forge-std/StdStorage.sol";
import { Testable } from "../Testable.sol";
import { TellerV2_Override } from "./TellerV2_Override.sol";
import { Bid, BidState, Collateral } from "../../contracts/TellerV2.sol";

contract TellerV2_initialize is Testable {
    using stdStorage for StdStorage;

    TellerV2_Override tellerV2;

    uint16 protocolFee = 5;

    User marketRegistry;
    User reputationManager;
    User lenderCommitmentForwarder;
    User collateralManager;
    User lenderManager;

    function setUp() public {
        tellerV2 = new TellerV2_Override();

        //stdstore.target(address(tellerV2)).sig("marketRegistry()").checked_write(address(0x1234));
    }

    function test_initialize() public {
      
        tellerV2.initialize(
            protocolFee, 
            address(marketRegistry), 
            address(reputationManager), 
            address(lenderCommitmentForwarder), 
            address(collateralManager),
            address(lenderManager)            
            );


        assertEq(address(tellerV2.marketRegistry()), address(marketRegistry));
        assertEq(address(tellerV2.lenderManager()), address(lenderManager)); 
    }

   
   
}


contract User {}