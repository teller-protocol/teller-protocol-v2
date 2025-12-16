// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Testable } from "../Testable.sol";
import { TellerV2Context_Override, TellerV2Context } from "./TellerV2Context_Override.sol";

contract TellerV2Context_hasApprovedMarketForwarder is Testable {
    TellerV2Context_Override private context;

    function setUp() public {
        context = new TellerV2Context_Override(address(0), address(111));
    }

    function test_False_for_untrusted_forwarders() public {
        uint256 marketId = 7;
        address stubbedMarketForwarder = address(123);

        context.mock_setApprovedMarketForwarder(
            marketId,
            stubbedMarketForwarder,
            address(this),
            true
        );

        assertFalse(
            context.hasApprovedMarketForwarder(
                marketId,
                stubbedMarketForwarder,
                address(this)
            ),
            "by default forwarder should not be approved"
        );
    }

    function test_False_for_unapproved_forwarders() public {
        uint256 marketId = 7;
        address stubbedMarketForwarder = address(123);

        context.mock_setTrustedMarketForwarder(
            marketId,
            stubbedMarketForwarder
        );

        assertFalse(
            context.hasApprovedMarketForwarder(
                marketId,
                stubbedMarketForwarder,
                address(this)
            ),
            "by default forwarder should not be approved"
        );
    }

    function test_True_for_trusted_and_approved_forwarders() public {
        uint256 marketId = 7;
        address stubbedMarketForwarder = address(123);

        context.mock_setTrustedMarketForwarder(
            marketId,
            stubbedMarketForwarder
        );
        context.mock_setApprovedMarketForwarder(
            marketId,
            stubbedMarketForwarder,
            address(this),
            true
        );

        assertTrue(
            context.hasApprovedMarketForwarder(
                marketId,
                stubbedMarketForwarder,
                address(this)
            ),
            "forwarder should be approved"
        );
    }

    function test_True_for_protocol_trusted_forwarder_without_market_trust()
        public
    {
        uint256 marketId = 7;
        address protocolForwarder = address(456);

        // Set as protocol trusted forwarder (but NOT market trusted)
        context.mock_setProtocolTrustedForwarder(protocolForwarder, true);

        // Should return true even without market-specific trust or approval
        assertTrue(
            context.hasApprovedMarketForwarder(
                marketId,
                protocolForwarder,
                address(this)
            ),
            "protocol trusted forwarder should be approved for any market"
        );
    }

    function test_True_for_protocol_trusted_forwarder_without_account_approval()
        public
    {
        uint256 marketId = 7;
        address protocolForwarder = address(456);
        address randomAccount = address(789);

        // Set as protocol trusted forwarder
        context.mock_setProtocolTrustedForwarder(protocolForwarder, true);

        // Should return true even without explicit account approval
        assertTrue(
            context.hasApprovedMarketForwarder(
                marketId,
                protocolForwarder,
                randomAccount
            ),
            "protocol trusted forwarder should bypass account approval requirement"
        );
    }

    function test_True_for_protocol_trusted_forwarder_overrides_market_settings()
        public
    {
        uint256 marketId = 7;
        address protocolForwarder = address(456);
        address differentMarketForwarder = address(789);

        // Set a different forwarder as trusted for the market
        context.mock_setTrustedMarketForwarder(
            marketId,
            differentMarketForwarder
        );

        // Set another forwarder as protocol trusted
        context.mock_setProtocolTrustedForwarder(protocolForwarder, true);

        // Protocol trusted forwarder should still return true
        assertTrue(
            context.hasApprovedMarketForwarder(
                marketId,
                protocolForwarder,
                address(this)
            ),
            "protocol trusted forwarder should work regardless of market-specific settings"
        );
    }

    function test_False_when_protocol_trusted_forwarder_is_unset() public {
        uint256 marketId = 7;
        address protocolForwarder = address(456);

        // Set as protocol trusted then unset
        context.mock_setProtocolTrustedForwarder(protocolForwarder, true);
        context.mock_setProtocolTrustedForwarder(protocolForwarder, false);

        // Should return false after being unset (and no market approval)
        assertFalse(
            context.hasApprovedMarketForwarder(
                marketId,
                protocolForwarder,
                address(this)
            ),
            "unset protocol forwarder without market trust should not be approved"
        );
    }

    function test_Protocol_trusted_forwarder_works_across_multiple_markets()
        public
    {
        address protocolForwarder = address(456);

        // Set as protocol trusted forwarder
        context.mock_setProtocolTrustedForwarder(protocolForwarder, true);

        // Should work for multiple different markets
        assertTrue(
            context.hasApprovedMarketForwarder(
                1,
                protocolForwarder,
                address(this)
            ),
            "should work for market 1"
        );
        assertTrue(
            context.hasApprovedMarketForwarder(
                2,
                protocolForwarder,
                address(this)
            ),
            "should work for market 2"
        );
        assertTrue(
            context.hasApprovedMarketForwarder(
                999,
                protocolForwarder,
                address(this)
            ),
            "should work for market 999"
        );
    }
}
