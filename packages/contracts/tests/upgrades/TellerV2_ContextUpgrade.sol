// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Testable } from "../Testable.sol";
import "../../contracts/TellerV2.sol";
import "../../contracts/TellerV2Storage.sol";

contract TellerV2_ContextUpgrade_Test is Testable {

    // Mainnet TellerV2 proxy address
    address constant TELLER_V2_MAINNET = 0x00182FdB0B880eE24D428e3Cc39383717677C37e;

    // Bid ID to test
    uint256 constant TEST_BID_ID = 400;

    TellerV2 tellerV2;

    // Struct to store bid snapshot
    struct BidSnapshot {
        address borrower;
        address lender;
        uint256 marketplaceId;
        address lendingToken;
        uint256 principal;
        uint32 acceptedTimestamp;
        uint32 lastRepaidTimestamp;
        BidState state;
    }

    function setUp() public {
        // Fork mainnet at a recent block
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));

        tellerV2 = TellerV2(TELLER_V2_MAINNET);
    }

    function test_storage_preserved_after_etch_upgrade() public {
        // Get bid details before the upgrade
        BidSnapshot memory bidBefore = _getBidSnapshot(TEST_BID_ID);

        // Get protocol fee recipient before the upgrade
        address protocolFeeRecipientBefore = tellerV2.getProtocolFeeRecipient();

        address metaforwarderAddress = address(0);

        // Deploy new TellerV2 implementation
        TellerV2 newImplementation = new TellerV2( metaforwarderAddress );

        // Get the runtime code of the new implementation
        bytes memory newCode = address(newImplementation).code;

        // Use vm.etch to replace the code at the proxy address
        // Note: This simulates an upgrade by replacing the implementation code
        // In a real upgrade, this would be done through the proxy admin
        vm.etch(TELLER_V2_MAINNET, newCode);

        // Get bid details after the etch
        BidSnapshot memory bidAfter = _getBidSnapshot(TEST_BID_ID);

        // Get protocol fee recipient after the upgrade
        address protocolFeeRecipientAfter = tellerV2.getProtocolFeeRecipient();

        // Assert all bid details are unchanged
        assertEq(bidAfter.borrower, bidBefore.borrower, "Borrower address changed");
        assertEq(bidAfter.lender, bidBefore.lender, "Lender address changed");
        assertEq(bidAfter.marketplaceId, bidBefore.marketplaceId, "Marketplace ID changed");
        assertEq(bidAfter.lendingToken, bidBefore.lendingToken, "Lending token address changed");
        assertEq(bidAfter.principal, bidBefore.principal, "Principal amount changed");
        assertEq(bidAfter.acceptedTimestamp, bidBefore.acceptedTimestamp, "Accepted timestamp changed");
        assertEq(bidAfter.lastRepaidTimestamp, bidBefore.lastRepaidTimestamp, "Last repaid timestamp changed");
        assertEq(uint8(bidAfter.state), uint8(bidBefore.state), "Bid state changed");

        // Assert protocol fee recipient is unchanged
        assertEq(protocolFeeRecipientAfter, protocolFeeRecipientBefore, "Protocol fee recipient changed");
    }

    function _getBidSnapshot(uint256 bidId) internal view returns (BidSnapshot memory snapshot) {
        // Get loan summary which provides all the key fields we need to verify
        (
            address borrower,
            address lender,
            uint256 marketId,
            address principalTokenAddress,
            uint256 principalAmount,
            uint32 acceptedTimestamp,
            uint32 lastRepaidTimestamp,
            BidState bidState
        ) = tellerV2.getLoanSummary(bidId);

        snapshot.borrower = borrower;
        snapshot.lender = lender;
        snapshot.marketplaceId = marketId;
        snapshot.lendingToken = principalTokenAddress;
        snapshot.principal = principalAmount;
        snapshot.acceptedTimestamp = acceptedTimestamp;
        snapshot.lastRepaidTimestamp = lastRepaidTimestamp;
        snapshot.state = bidState;
    }
}
