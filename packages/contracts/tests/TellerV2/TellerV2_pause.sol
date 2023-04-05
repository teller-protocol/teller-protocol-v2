// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { StdStorage, stdStorage } from "forge-std/StdStorage.sol";
import { Testable } from "../Testable.sol";
import { TellerV2_Override } from "./TellerV2_Override.sol";
import { Bid, BidState, Collateral, Payment, LoanDetails, Terms } from "../../contracts/TellerV2.sol";

import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { PaymentType, PaymentCycleType } from "../../contracts/libraries/V2Calculations.sol";

contract TellerV2_pause_test is Testable {
    TellerV2_Override tellerV2;

    uint16 protocolFee = 5;

    ERC20 lendingToken;

    function setUp() public {
        tellerV2 = new TellerV2_Override();

        lendingToken = new ERC20("Wrapped Ether", "WETH");
    }

    function test_pauseProtocol_invalid_if_not_owner() public {
        vm.expectRevert("Ownable: caller is not the owner");

        tellerV2.pauseProtocol();
    }

    function test_pauseProtocol_invalid_if_paused() public {
        tellerV2.mock_initialize();

        tellerV2.pauseProtocol();

        vm.expectRevert();
        tellerV2.pauseProtocol();
    }

    function test_unpauseProtocol_invalid_if_unpaused() public {
        tellerV2.mock_initialize();

        vm.expectRevert();
        tellerV2.unpauseProtocol();
    }

    function test_pauseProtocol() public {
        tellerV2.mock_initialize();

        tellerV2.pauseProtocol();
        assertTrue(tellerV2.paused());
    }

    function test_unpauseProtocol() public {
        tellerV2.mock_initialize();

        tellerV2.pauseProtocol();
        assertTrue(tellerV2.paused());
        tellerV2.unpauseProtocol();
        assertFalse(tellerV2.paused());
    }
}

contract User {}
