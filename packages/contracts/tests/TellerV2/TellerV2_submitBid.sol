// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { StdStorage, stdStorage } from "forge-std/StdStorage.sol";
import { Testable } from "../Testable.sol";
import { TellerV2_Override } from "./TellerV2_Override.sol";
import { Bid, BidState, Collateral } from "../../contracts/TellerV2.sol";

contract TellerV2_submitBid is Testable {
    using stdStorage for StdStorage;

    TellerV2_Override tellerV2;

    function setUp() public {
        tellerV2 = new TellerV2_Override();

        stdstore.target(address(tellerV2)).sig("marketRegistry()").checked_write(address(0x1234));
    }

    function test_Reverts_when_protocol_IS_paused() public {
        tellerV2.mock_pause(true);

        vm.expectRevert("Pausable: paused");
        tellerV2.submitBid(
            address(1),    // lending token
            1,             // market ID
            100,           // principal
            365 days,      // duration
            20_00,         // interest rate
            "",            // metadata URI
            address(this)  // receiver
        );
    }

    function test_Reverts_when_protocol_IS_paused__with_collateral() public {
        tellerV2.mock_pause(true);

        Collateral[] memory collateral = new Collateral[](1);

        vm.expectRevert("Pausable: paused");
        tellerV2.submitBid(
            address(1),    // lending token
            1,             // market ID
            100,           // principal
            365 days,      // duration
            20_00,         // interest rate
            "",            // metadata URI
            address(this), // receiver
            collateral     // collateral
        );
    }
}
