// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Testable } from "../Testable.sol";
import { TellerV2Context_Override, TellerV2Context } from "./TellerV2Context_Override.sol";

contract TellerV2Context_setProtocolTrustedForwarder is Testable {
    TellerV2Context_Override private context;

    address protocolOwner = address(this);
    address nonOwner = address(0x456);
    address stubbedForwarder = address(0x123);

    function setUp() public {
        context = new TellerV2Context_Override(address(0), address(111));
    }

    event ProtocolTrustedForwarderSet(
        address forwarder,
        address sender,
        bool trusted
    );

    function test_Successfully_set_protocol_trusted_forwarder_to_true() public {
        // Verify initial state
        assertFalse(
            context.isProtocolTrustedForwarder(stubbedForwarder),
            "Forwarder should not be trusted initially"
        );

        // Expect event emission
        vm.expectEmit(true, true, true, true, address(context));
        emit ProtocolTrustedForwarderSet(stubbedForwarder, protocolOwner, true);

        // Set forwarder as trusted
        context.setProtocolTrustedForwarder(stubbedForwarder, true);

        // Verify state changed
        assertTrue(
            context.isProtocolTrustedForwarder(stubbedForwarder),
            "Forwarder should be trusted after setting"
        );
    }

    function test_Successfully_set_protocol_trusted_forwarder_to_false() public {
        // Setup: Set forwarder as trusted first
        context.mock_setProtocolTrustedForwarder(stubbedForwarder, true);
        assertTrue(
            context.isProtocolTrustedForwarder(stubbedForwarder),
            "Forwarder should be trusted initially"
        );

        // Expect event emission
        vm.expectEmit(true, true, true, true, address(context));
        emit ProtocolTrustedForwarderSet(stubbedForwarder, protocolOwner, false);

        // Unset forwarder as trusted
        context.setProtocolTrustedForwarder(stubbedForwarder, false);

        // Verify state changed
        assertFalse(
            context.isProtocolTrustedForwarder(stubbedForwarder),
            "Forwarder should not be trusted after unsetting"
        );
    }

    function test_Fail_when_non_owner_tries_to_set_protocol_trusted_forwarder()
        public
    {
        // Setup: Change to non-owner context
        vm.startPrank(nonOwner);

        // Expect revert
        vm.expectRevert("Sender not authorized");
        context.setProtocolTrustedForwarder(stubbedForwarder, true);

        vm.stopPrank();
    }

    function test_Successfully_set_multiple_protocol_trusted_forwarders()
        public
    {
        address forwarder1 = address(0x111);
        address forwarder2 = address(0x222);
        address forwarder3 = address(0x333);

        // Set multiple forwarders as trusted
        context.setProtocolTrustedForwarder(forwarder1, true);
        context.setProtocolTrustedForwarder(forwarder2, true);
        context.setProtocolTrustedForwarder(forwarder3, true);

        // Verify all are trusted
        assertTrue(
            context.isProtocolTrustedForwarder(forwarder1),
            "Forwarder 1 should be trusted"
        );
        assertTrue(
            context.isProtocolTrustedForwarder(forwarder2),
            "Forwarder 2 should be trusted"
        );
        assertTrue(
            context.isProtocolTrustedForwarder(forwarder3),
            "Forwarder 3 should be trusted"
        );
    }

    function test_Successfully_toggle_protocol_trusted_forwarder_state()
        public
    {
        // Set to true
        context.setProtocolTrustedForwarder(stubbedForwarder, true);
        assertTrue(
            context.isProtocolTrustedForwarder(stubbedForwarder),
            "Should be trusted after setting to true"
        );

        // Set to false
        context.setProtocolTrustedForwarder(stubbedForwarder, false);
        assertFalse(
            context.isProtocolTrustedForwarder(stubbedForwarder),
            "Should not be trusted after setting to false"
        );

        // Set to true again
        context.setProtocolTrustedForwarder(stubbedForwarder, true);
        assertTrue(
            context.isProtocolTrustedForwarder(stubbedForwarder),
            "Should be trusted after setting to true again"
        );
    }

    function test_Event_emitted_with_correct_parameters_when_setting_trusted()
        public
    {
        vm.expectEmit(true, true, true, true, address(context));
        emit ProtocolTrustedForwarderSet(stubbedForwarder, protocolOwner, true);

        context.setProtocolTrustedForwarder(stubbedForwarder, true);
    }

    function test_Event_emitted_with_correct_parameters_when_setting_untrusted()
        public
    {
        vm.expectEmit(true, true, true, true, address(context));
        emit ProtocolTrustedForwarderSet(
            stubbedForwarder,
            protocolOwner,
            false
        );

        context.setProtocolTrustedForwarder(stubbedForwarder, false);
    }
}
