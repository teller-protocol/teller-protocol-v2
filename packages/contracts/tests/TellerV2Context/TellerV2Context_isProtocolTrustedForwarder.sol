// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Testable } from "../Testable.sol";
import { TellerV2Context_Override, TellerV2Context } from "./TellerV2Context_Override.sol";

contract TellerV2Context_isProtocolTrustedForwarder is Testable {
    TellerV2Context_Override private context;

    address stubbedForwarder = address(0x123);

    function setUp() public {
        context = new TellerV2Context_Override(address(0), address(111));
    }

    function test_Returns_false_for_untrusted_forwarder() public {
        assertFalse(
            context.isProtocolTrustedForwarder(stubbedForwarder),
            "Forwarder should not be trusted by default"
        );
    }

    function test_Returns_false_for_zero_address() public {
        assertFalse(
            context.isProtocolTrustedForwarder(address(0)),
            "Zero address should not be trusted"
        );
    }

    function test_Returns_true_for_trusted_forwarder() public {
        // Setup: Set forwarder as trusted
        context.mock_setProtocolTrustedForwarder(stubbedForwarder, true);

        // Verify
        assertTrue(
            context.isProtocolTrustedForwarder(stubbedForwarder),
            "Forwarder should be trusted"
        );
    }

    function test_Returns_false_after_forwarder_is_untrusted() public {
        // Setup: Set forwarder as trusted then untrusted
        context.mock_setProtocolTrustedForwarder(stubbedForwarder, true);
        context.mock_setProtocolTrustedForwarder(stubbedForwarder, false);

        // Verify
        assertFalse(
            context.isProtocolTrustedForwarder(stubbedForwarder),
            "Forwarder should not be trusted after being set to false"
        );
    }

    function test_Returns_true_after_using_setProtocolTrustedForwarder()
        public
    {
        // Use the actual function (not mock)
        context.setProtocolTrustedForwarder(stubbedForwarder, true);

        // Verify
        assertTrue(
            context.isProtocolTrustedForwarder(stubbedForwarder),
            "Forwarder should be trusted after calling setProtocolTrustedForwarder"
        );
    }

    function test_Multiple_forwarders_can_be_trusted_independently() public {
        address forwarder1 = address(0x111);
        address forwarder2 = address(0x222);
        address forwarder3 = address(0x333);

        // Set some forwarders as trusted
        context.mock_setProtocolTrustedForwarder(forwarder1, true);
        context.mock_setProtocolTrustedForwarder(forwarder3, true);

        // Verify individual states
        assertTrue(
            context.isProtocolTrustedForwarder(forwarder1),
            "Forwarder 1 should be trusted"
        );
        assertFalse(
            context.isProtocolTrustedForwarder(forwarder2),
            "Forwarder 2 should not be trusted"
        );
        assertTrue(
            context.isProtocolTrustedForwarder(forwarder3),
            "Forwarder 3 should be trusted"
        );
    }

    function test_State_persists_across_multiple_calls() public {
        // Set forwarder as trusted
        context.mock_setProtocolTrustedForwarder(stubbedForwarder, true);

        // Call multiple times to verify state persistence
        assertTrue(
            context.isProtocolTrustedForwarder(stubbedForwarder),
            "First call should return true"
        );
        assertTrue(
            context.isProtocolTrustedForwarder(stubbedForwarder),
            "Second call should return true"
        );
        assertTrue(
            context.isProtocolTrustedForwarder(stubbedForwarder),
            "Third call should return true"
        );
    }

    function test_Different_addresses_return_different_states() public {
        address trustedForwarder = address(0x111);
        address untrustedForwarder = address(0x222);

        // Set only one as trusted
        context.mock_setProtocolTrustedForwarder(trustedForwarder, true);

        // Verify they have different states
        assertTrue(
            context.isProtocolTrustedForwarder(trustedForwarder),
            "Trusted forwarder should return true"
        );
        assertFalse(
            context.isProtocolTrustedForwarder(untrustedForwarder),
            "Untrusted forwarder should return false"
        );
    }
}
