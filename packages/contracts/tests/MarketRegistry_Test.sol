// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Testable } from "./Testable.sol";

import { TellerV2 } from "../contracts/TellerV2.sol";
import { MarketRegistry } from "../contracts/MarketRegistry.sol";

import "../contracts/TellerV2Context.sol";

import "../contracts/TellerV2Storage.sol";

import "../contracts/interfaces/IMarketRegistry.sol";
import "../contracts/interfaces/IMarketRegistry_V2.sol";

import "../contracts/EAS/TellerAS.sol";

import "../contracts/mock/WethMock.sol";
import "../contracts/interfaces/IWETH.sol";

import { PaymentType, PaymentCycleType } from "../contracts/libraries/V2Calculations.sol";

import { MarketRegistry_Override } from "./MarketRegistry_Override.sol";

import { TellerASMock } from "../contracts/mock/TellerASMock.sol";

contract MarketRegistry_Test is Testable {
    User private marketOwner;
    User private borrower;
    User private lender;
    //User private stakeholder;
    User private feeRecipient;

    WethMock wethMock;

    TellerV2Mock tellerV2;
    MarketRegistry_Override marketRegistry;

    TellerASMock tellerASMock;

    uint32 expirationTime = 5000;
    uint256 marketId = 2;

    bytes32 uuid = bytes32("0x042");

    uint8 v = 1;
    bytes32 r = 0x0;
    bytes32 s = 0x0;

    constructor() {}

    function setUp() public {
        tellerV2 = new TellerV2Mock();
        marketRegistry = new MarketRegistry_Override();

        tellerASMock = new TellerASMock();

        marketOwner = new User();
        borrower = new User();
        lender = new User();
        feeRecipient = new User();

        marketRegistry.setMarketOwner(address(marketOwner));

        tellerV2.setMarketRegistry(address(marketRegistry));

        // reputationManager = IReputationManager(new ReputationManager());
    }

    /*


FNDA:0,MarketRegistry.initialize
 
  
FNDA:0,MarketRegistry._attestStakeholderViaDelegation


    */

    function test_marketIsClosed() public {
        assertEq(
            marketRegistry.isMarketClosed(0),
            false,
            "Null market should not be closed"
        );
    }

    function test_createMarket_simple() public {
        // Standard seconds payment cycle

        IMarketRegistry_V2.MarketplaceTerms
            memory marketTerms = IMarketRegistry_V2.MarketplaceTerms({
                paymentCycleDuration: uint32(8000),
                paymentDefaultDuration: uint32(7000),
                bidExpirationTime: uint32(5000),
                marketplaceFeePercent: uint16(500),
                paymentType: PaymentType.EMI,
                paymentCycleType: PaymentCycleType.Seconds,
                feeRecipient: address(marketRegistry)
            });

        vm.prank(address(marketOwner));
        (uint256 marketId, ) = marketRegistry.createMarket(
            address(marketOwner),
            false,
            false,
            "uri://",
            marketTerms
        );

        (address owner, , , , ) = marketRegistry.getMarketData(marketId);

        assertEq(owner, address(marketOwner), "Market not created");
    }

    function test_closeMarket() public {
        IMarketRegistry_V2.MarketplaceTerms
            memory marketTerms = IMarketRegistry_V2.MarketplaceTerms({
                paymentCycleDuration: uint32(8000),
                paymentDefaultDuration: uint32(7000),
                bidExpirationTime: uint32(5000),
                marketplaceFeePercent: uint16(500),
                paymentType: PaymentType.EMI,
                paymentCycleType: PaymentCycleType.Seconds,
                feeRecipient: address(marketRegistry)
            });

        vm.prank(address(marketOwner));
        (uint256 marketId, ) = marketRegistry.createMarket(
            address(marketRegistry),
            false,
            false,
            "uri://",
            marketTerms
        );

        vm.prank(address(marketOwner));
        marketRegistry.closeMarket(marketId);

        bool marketIsClosed = marketRegistry.isMarketClosed(marketId);

        assertEq(marketIsClosed, true, "Market not closed");
    }

    function test_closeMarket_twice() public {
        IMarketRegistry_V2.MarketplaceTerms
            memory marketTerms = IMarketRegistry_V2.MarketplaceTerms({
                paymentCycleDuration: uint32(8000),
                paymentDefaultDuration: uint32(7000),
                bidExpirationTime: uint32(5000),
                marketplaceFeePercent: uint16(500),
                paymentType: PaymentType.EMI,
                paymentCycleType: PaymentCycleType.Seconds,
                feeRecipient: address(marketRegistry)
            });

        vm.prank(address(marketOwner));
        (uint256 marketId, ) = marketRegistry.createMarket(
            address(marketRegistry),
            false,
            false,
            "uri://",
            marketTerms
        );

        vm.prank(address(marketOwner));
        marketRegistry.closeMarket(marketId);

        vm.prank(address(marketOwner));
        marketRegistry.closeMarket(marketId);

        bool marketIsClosed = marketRegistry.isMarketClosed(marketId);

        assertEq(marketIsClosed, true, "Market not closed");
    }

    function test_closeMarket_invalid_owner() public {
        IMarketRegistry_V2.MarketplaceTerms
            memory marketTerms = IMarketRegistry_V2.MarketplaceTerms({
                paymentCycleDuration: uint32(8000),
                paymentDefaultDuration: uint32(7000),
                bidExpirationTime: uint32(5000),
                marketplaceFeePercent: uint16(500),
                paymentType: PaymentType.EMI,
                paymentCycleType: PaymentCycleType.Seconds,
                feeRecipient: address(marketRegistry)
            });

        vm.prank(address(marketOwner));
        (uint256 marketId, ) = marketRegistry.createMarket(
            address(marketRegistry),
            false,
            false,
            "uri://",
            marketTerms
        );

        vm.expectRevert("Not the owner");
        marketRegistry.closeMarket(marketId);
    }

    function test_createMarket() public {
        // Standard seconds payment cycle

        IMarketRegistry_V2.MarketplaceTerms
            memory marketTerms = IMarketRegistry_V2.MarketplaceTerms({
                paymentCycleDuration: uint32(8000),
                paymentDefaultDuration: uint32(7000),
                bidExpirationTime: uint32(5000),
                marketplaceFeePercent: uint16(500),
                paymentType: PaymentType.EMI,
                paymentCycleType: PaymentCycleType.Seconds,
                feeRecipient: address(marketRegistry)
            });

        vm.prank(address(marketOwner));
        (uint256 marketId, ) = marketRegistry.createMarket(
            address(marketRegistry),
            false,
            false,
            "uri://",
            marketTerms
        );

        uint256 _marketId = 1;

        bytes32 marketTermsId = marketRegistry.getCurrentTermsForMarket(
            _marketId
        );

        (
            uint32 paymentCycleDuration,
            PaymentCycleType paymentCycleType,
            ,
            ,

        ) = marketRegistry.getMarketTermsForLending(marketTermsId);

        require(
            paymentCycleType == PaymentCycleType.Seconds,
            "Market payment cycle type incorrectly created"
        );

        assertEq(
            paymentCycleDuration,
            8000,
            "Market payment cycle duration set incorrectly"
        );

        marketTerms = IMarketRegistry_V2.MarketplaceTerms({
            paymentCycleDuration: uint32(0),
            paymentDefaultDuration: uint32(7000),
            bidExpirationTime: uint32(5000),
            marketplaceFeePercent: uint16(500),
            paymentType: PaymentType.EMI,
            paymentCycleType: PaymentCycleType.Monthly,
            feeRecipient: address(marketRegistry)
        });

        vm.prank(address(marketOwner));
        (marketId, ) = marketRegistry.createMarket(
            address(marketRegistry),
            false,
            false,
            "uri://",
            marketTerms
        );

        _marketId = 2;

        marketTermsId = marketRegistry.getCurrentTermsForMarket(_marketId);

        (paymentCycleDuration, paymentCycleType, , , ) = marketRegistry
            .getMarketTermsForLending(marketTermsId);

        require(
            paymentCycleType == PaymentCycleType.Monthly,
            "Monthly market payment cycle type incorrectly created"
        );

        assertEq(
            paymentCycleDuration,
            30 days,
            "Monthly market payment cycle duration returned incorrectly"
        );

        // Monthly payment cycle should fail

        marketTerms = IMarketRegistry_V2.MarketplaceTerms({
            paymentCycleDuration: uint32(3000),
            paymentDefaultDuration: uint32(7000),
            bidExpirationTime: uint32(5000),
            marketplaceFeePercent: uint16(500),
            paymentType: PaymentType.EMI,
            paymentCycleType: PaymentCycleType.Monthly,
            feeRecipient: address(marketRegistry)
        });

        //payment cycle duration must be zero for monthly type
        vm.expectRevert(
            "Monthly payment cycle duration invalid for cycle type"
        );
        vm.prank(address(marketOwner));
        (marketId, ) = marketRegistry.createMarket(
            address(marketRegistry),
            false,
            false,
            "uri://",
            marketTerms
        );

        /*  marketOwner.createMarket(
            address(marketRegistry),
            3000,
            7000,
            5000,
            500,
            false,
            false,
            PaymentType.EMI,
            PaymentCycleType.Monthly,
             address(marketRegistry),
            "uri://"
        ); */
    }

    function test_createMarket_invalid_initial_owner() public {
        IMarketRegistry_V2.MarketplaceTerms
            memory marketTerms = IMarketRegistry_V2.MarketplaceTerms({
                paymentCycleDuration: uint32(0),
                paymentDefaultDuration: uint32(7000),
                bidExpirationTime: uint32(5000),
                marketplaceFeePercent: uint16(500),
                paymentType: PaymentType.EMI,
                paymentCycleType: PaymentCycleType.Monthly,
                feeRecipient: address(marketRegistry)
            });

        vm.expectRevert(); //"Invalid owner address"
        (uint256 marketId, ) = marketRegistry.createMarket(
            address(0),
            false,
            false,
            "uri://",
            marketTerms
        );
    }

    /*
    function test_attestStakeholder() public {
        bool isLender = true;
        vm.prank(address(marketOwner));
        marketRegistry.attestStakeholderInternal(
            marketId,
            address(lender),
            expirationTime,
            isLender
        );

        assertEq(
            marketRegistry.attestStakeholderVerificationWasCalled(),
            true,
            "Attest stakeholder verification was not called"
        );
    }

    function test_attestStakeholder_notMarketOwner() public {
        bool isLender = true;

        vm.expectRevert("Not the market owner");

        marketRegistry.attestStakeholder(
            marketId,
            address(lender),
            expirationTime,
            isLender
        );
    }*/

    function test_attestStakeholderVerification_lender() public {
        bool isLender = true;

        marketRegistry.attestStakeholderVerification(
            marketId,
            address(lender),
            uuid,
            isLender
        );

        //expect that the lender is attested

        assertEq(
            marketRegistry.marketVerifiedLendersContains(
                marketId,
                address(lender)
            ),
            true,
            "Did not add lender to verified set"
        );
    }

    function test_attestStakeholderVerification_borrower() public {
        bool isLender = false;

        marketRegistry.attestStakeholderVerification(
            marketId,
            address(borrower),
            uuid,
            isLender
        );

        //expect that the borrower is attested

        assertEq(
            marketRegistry.marketVerifiedBorrowersContains(
                marketId,
                address(borrower)
            ),
            true,
            "Did not add lender to verified set"
        );
    }

    function test_attestLender() public {
        marketRegistry.attestLender(marketId, address(lender), expirationTime);

        assertEq(
            marketRegistry.attestStakeholderWasCalled(),
            true,
            "Attest stakeholder was not called"
        );
    }

    function test_attestLender_expired() public {}

    function test_attestBorrower() public {
        marketRegistry.attestBorrower(
            marketId,
            address(borrower),
            expirationTime
        );

        assertEq(
            marketRegistry.attestStakeholderWasCalled(),
            true,
            "Attest stakeholder was not called"
        );
    }

    function test_revokeLender() public {
        marketRegistry.revokeLender(marketId, address(lender));

        assertEq(
            marketRegistry.revokeStakeholderWasCalled(),
            true,
            "Revoke stakeholder was not called"
        );
    }

    function test_revokeBorrower() public {
        marketRegistry.revokeBorrower(marketId, address(borrower));

        assertEq(
            marketRegistry.revokeStakeholderWasCalled(),
            true,
            "Revoke stakeholder was not called"
        );
    }

    /*  function test_revokeStakeholder() public {
        bool isLender = true;

        vm.prank(address(marketOwner));
        marketRegistry.revokeStakeholder(marketId, address(lender), isLender);

        assertEq(
            marketRegistry.revokeStakeholderVerificationWasCalled(),
            true,
            "Revoke stakeholder verification was not called"
        );
    }

    function test_revokeStakeholder_notMarketOwner() public {
        bool isLender = true;

        vm.expectRevert("Not the market owner");

        marketRegistry.revokeStakeholder(marketId, address(lender), isLender);
    }

    */

    function test_revokeStakeholderVerification() public {
        bool isLender = true;

        marketRegistry.forceVerifyLenderForMarket(marketId, address(lender));

        marketRegistry.revokeStakeholderVerification(
            marketId,
            address(lender),
            isLender
        );

        assertEq(
            marketRegistry.marketVerifiedLendersContains(
                marketId,
                address(lender)
            ),
            false,
            "Lender was not revoked"
        );
    }

    function test_lenderExitMarket() public {
        marketRegistry.forceVerifyLenderForMarket(marketId, address(lender));

        vm.prank(address(lender));
        marketRegistry.lenderExitMarket(marketId);

        assertEq(
            marketRegistry.marketVerifiedLendersContains(
                marketId,
                address(lender)
            ),
            false,
            "Lender was not able to exit market"
        );
    }

    function test_borrowerExitMarket() public {
        marketRegistry.forceVerifyBorrowerForMarket(
            marketId,
            address(borrower)
        );
        vm.prank(address(borrower));
        marketRegistry.borrowerExitMarket(marketId);

        assertEq(
            marketRegistry.marketVerifiedBorrowersContains(
                marketId,
                address(borrower)
            ),
            false,
            "Borrower was not able to exit market"
        );
    }

    function test_resolve() public {}

    function test_transferMarketOwnership() public {
        marketRegistry.setMarketOwner(address(this));

        marketRegistry.stubMarket(marketId, address(this));

        marketRegistry.transferMarketOwnership(marketId, address(lender));

        assertEq(
            marketRegistry.getMarketOwner(marketId),
            address(lender),
            "Could not transfer ownership"
        );
    }

    function test_transferMarketOwnership_notOwner() public {
        vm.expectRevert("Not the owner");

        marketRegistry.transferMarketOwnership(marketId, address(lender));
    }

    function test_updateMarketSettings() public {
        marketRegistry.setMarketOwner(address(this));

        marketRegistry.stubMarket(marketId, address(this));

        IMarketRegistry_V2.MarketplaceTerms
            memory marketTerms = IMarketRegistry_V2.MarketplaceTerms({
                paymentCycleDuration: 111,
                paymentDefaultDuration: 200,
                bidExpirationTime: 300,
                marketplaceFeePercent: 10,
                paymentType: PaymentType.EMI,
                paymentCycleType: PaymentCycleType.Seconds,
                feeRecipient: address(address(this))
            });

        marketRegistry.updateMarketSettings(marketId, marketTerms);

        bytes32 marketTermsId = marketRegistry.getCurrentTermsForMarket(
            marketId
        );

        (uint32 paymentCycleDuration, , , , , , ) = marketRegistry
            .getMarketTermsData(marketTermsId);

        assertEq(paymentCycleDuration, 111, "Market not updated");
    }

    function test_updateMarketSettings_not_owner() public {
        IMarketRegistry_V2.MarketplaceTerms
            memory marketTerms = IMarketRegistry_V2.MarketplaceTerms({
                paymentCycleDuration: 111,
                paymentDefaultDuration: 200,
                bidExpirationTime: 300,
                marketplaceFeePercent: 10,
                paymentType: PaymentType.EMI,
                paymentCycleType: PaymentCycleType.Seconds,
                feeRecipient: address(address(this))
            });

        vm.expectRevert("Not the owner");
        marketRegistry.updateMarketSettings(marketId, marketTerms);
    }

    function test_getMarketFeeRecipient_when_unset() public {
        marketRegistry.setMarketOwner(address(marketOwner));

        marketRegistry.stubMarket(marketId, address(this));

        address feeRecipient = marketRegistry.getMarketFeeRecipient(marketId);

        assertEq(
            feeRecipient,
            address(address(marketOwner)),
            "Could not get market fee recipient"
        );
    }

    function test_getMarketFeeRecipient_when_set() public {
        marketRegistry.setMarketOwner(address(marketOwner));
        marketRegistry.setFeeRecipient(marketId, address(feeRecipient));

        marketRegistry.stubMarket(marketId, address(this));

        address feeRecipient = marketRegistry.getMarketFeeRecipient(marketId);

        assertEq(
            feeRecipient,
            address(address(feeRecipient)),
            "Could not get market fee recipient"
        );
    }

    /* function test_setMarketFeeRecipient() public {
        marketRegistry.setMarketOwner(address(this));

        marketRegistry.stubMarket(marketId, address(this));

        marketRegistry.setMarketFeeRecipient(marketId, address(lender));

        assertEq(
            marketRegistry.getMarketFeeRecipient(marketId),
            address(lender),
            "Could not set market fee recipient"
        );
    }

    function test_setMarketFeeRecipient_not_owner() public {
        marketRegistry.setMarketOwner(address(this));

        marketRegistry.stubMarket(marketId, address(this));

        vm.expectRevert("Not the owner");
        vm.prank(address(borrower));
        marketRegistry.setMarketFeeRecipient(marketId, address(lender));
    }*/

    function test_setMarketURI() public {
        marketRegistry.setMarketOwner(address(this));

        marketRegistry.stubMarket(marketId, address(this));

        marketRegistry.setMarketURI(marketId, "ipfs://");

        assertEq(
            marketRegistry.getMarketURI(marketId),
            "ipfs://",
            "Could not set market uri"
        );
    }

    function test_setMarketURI_not_owner() public {
        marketRegistry.setMarketOwner(address(this));

        marketRegistry.stubMarket(marketId, address(this));

        vm.expectRevert("Not the owner");
        vm.prank(address(borrower));
        marketRegistry.setMarketURI(marketId, "ipfs://");
    }

    /* function test_setPaymentCycle() public {
        marketRegistry.setMarketOwner(address(this));

        marketRegistry.stubMarket(marketId, address(this));

        marketRegistry.setPaymentCycle(marketId, PaymentCycleType.Seconds, 555);

        (uint32 duration, PaymentCycleType cType) = marketRegistry
            .getPaymentCycle(marketId);

        assertEq(duration, 555, "Could not set market payment cycle");

        require(
            cType == PaymentCycleType.Seconds,
            "Could not set market payment type"
        );
    }

    function test_setPaymentCycle_not_owner() public {
        marketRegistry.setMarketOwner(address(this));

        marketRegistry.stubMarket(marketId, address(this));

        vm.expectRevert("Not the owner");
        vm.prank(address(borrower));
        marketRegistry.setPaymentCycle(marketId, PaymentCycleType.Seconds, 555);
    }

    function test_setPaymentCycle_monthly() public {
        marketRegistry.setMarketOwner(address(this));

        marketRegistry.stubMarket(marketId, address(this));

        marketRegistry.setPaymentCycle(marketId, PaymentCycleType.Monthly, 0);

        (uint32 duration, PaymentCycleType cType) = marketRegistry
            .getPaymentCycle(marketId);

        assertEq(duration, 30 days, "Could not set market payment cycle");

        require(
            cType == PaymentCycleType.Monthly,
            "Could not set market payment type"
        );
    }

    function test_setPaymentCycle_monthly_invalid() public {
        marketRegistry.setMarketOwner(address(this));

        marketRegistry.stubMarket(marketId, address(this));

        vm.expectRevert("monthly payment cycle duration cannot be set");

        marketRegistry.setPaymentCycle(marketId, PaymentCycleType.Monthly, 555);
    }*/
    /*
    function test_setPaymentDefaultDuration() public {
        marketRegistry.setMarketOwner(address(this));

        marketRegistry.stubMarket(marketId, address(this));

        marketRegistry.setPaymentDefaultDuration(marketId, 555);

        assertEq(
            marketRegistry.getPaymentDefaultDuration(marketId),
            555,
            "Could not set payment default duration"
        );
    }

    function test_setPaymentDefaultDuration_not_owner() public {
        marketRegistry.setMarketOwner(address(this));

        marketRegistry.stubMarket(marketId, address(this));

        vm.expectRevert("Not the owner");
        vm.prank(address(borrower));
        marketRegistry.setPaymentDefaultDuration(marketId, 555);
    }
*/
    /*
    function test_setBidExpirationTime() public {
        marketRegistry.setMarketOwner(address(this));

        marketRegistry.stubMarket(marketId, address(this));

        marketRegistry.setBidExpirationTime(marketId, 555);

        assertEq(
            marketRegistry.getBidExpirationTime(marketId),
            555,
            "Could not set bid expiration time"
        );
    }

    function test_setBidExpirationTime_not_owner() public {
        marketRegistry.setMarketOwner(address(this));

        marketRegistry.stubMarket(marketId, address(this));

        vm.expectRevert("Not the owner");
        vm.prank(address(borrower));
        marketRegistry.setBidExpirationTime(marketId, 555);
    }
*/
    /*
    function test_setMarketFeePercent() public {
        marketRegistry.setMarketOwner(address(this));

        marketRegistry.stubMarket(marketId, address(this));

        marketRegistry.setMarketFeePercent(marketId, 555);

        assertEq(
            marketRegistry.getMarketplaceFee(marketId),
            555,
            "Could not set market fee percent"
        );
    }

    function test_setMarketFeePercent_not_owner() public {
        marketRegistry.setMarketOwner(address(this));

        marketRegistry.stubMarket(marketId, address(this));

        vm.expectRevert("Not the owner");
        vm.prank(address(borrower));
        marketRegistry.setMarketFeePercent(marketId, 555);
    }
*/
    /*
    function test_setMarketPaymentType() public {
        marketRegistry.setMarketOwner(address(this));

        marketRegistry.stubMarket(marketId, address(this));

        marketRegistry.setMarketPaymentType(marketId, PaymentType.EMI);

        require(
            marketRegistry.getPaymentType(marketId) == PaymentType.EMI,
            "Could not set market payment type"
        );
    }

    function test_setMarketPaymentType_not_owner() public {
        marketRegistry.setMarketOwner(address(this));

        marketRegistry.stubMarket(marketId, address(this));

        vm.expectRevert("Not the owner");
        vm.prank(address(borrower));
        marketRegistry.setMarketPaymentType(marketId, PaymentType.EMI);
    }

    function test_setMarketPaymentType_bullet() public {
        marketRegistry.setMarketOwner(address(this));

        marketRegistry.stubMarket(marketId, address(this));

        marketRegistry.setMarketPaymentType(marketId, PaymentType.Bullet);

        require(
            marketRegistry.getPaymentType(marketId) == PaymentType.Bullet,
            "Could not set market payment type"
        );
    }
*/
    function test_setLenderAttestationRequired() public {
        marketRegistry.setMarketOwner(address(this));

        marketRegistry.stubMarket(marketId, address(this));

        marketRegistry.setLenderAttestationRequired(marketId, true);

        (bool lenderReq, bool borrowerReq) = marketRegistry
            .getMarketAttestationRequirements(marketId);

        assertEq(lenderReq, true, "Could not set lender attestation required");
    }

    function test_setLenderAttestationRequired_not_owner() public {
        marketRegistry.setMarketOwner(address(this));

        marketRegistry.stubMarket(marketId, address(this));

        vm.prank(address(borrower));
        vm.expectRevert("Not the owner");
        marketRegistry.setLenderAttestationRequired(marketId, true);
    }

    function test_setLenderAttestationRequired_twice() public {
        marketRegistry.setMarketOwner(address(this));

        marketRegistry.stubMarket(marketId, address(this));

        marketRegistry.setLenderAttestationRequired(marketId, true);
        marketRegistry.setLenderAttestationRequired(marketId, true);

        (bool lenderReq, bool borrowerReq) = marketRegistry
            .getMarketAttestationRequirements(marketId);

        assertEq(lenderReq, true, "Could not set lender attestation required");
    }

    function test_setBorrowerAttestationRequired() public {
        marketRegistry.setMarketOwner(address(this));

        marketRegistry.stubMarket(marketId, address(this));

        marketRegistry.setBorrowerAttestationRequired(marketId, true);

        (bool lenderReq, bool borrowerReq) = marketRegistry
            .getMarketAttestationRequirements(marketId);

        assertEq(
            borrowerReq,
            true,
            "Could not set borrower attestation required"
        );
    }

    function test_setBorrowerAttestationRequired_not_owner() public {
        marketRegistry.setMarketOwner(address(this));

        marketRegistry.stubMarket(marketId, address(this));

        vm.prank(address(borrower));
        vm.expectRevert("Not the owner");
        marketRegistry.setBorrowerAttestationRequired(marketId, true);
    }

    function test_setBorrowerAttestationRequired_twice() public {
        marketRegistry.setMarketOwner(address(this));

        marketRegistry.stubMarket(marketId, address(this));

        marketRegistry.setBorrowerAttestationRequired(marketId, true);
        marketRegistry.setBorrowerAttestationRequired(marketId, true);

        (bool lenderReq, bool borrowerReq) = marketRegistry
            .getMarketAttestationRequirements(marketId);

        assertEq(
            borrowerReq,
            true,
            "Could not set borrower attestation required"
        );
    }

    function test_isVerifiedLender() public {
        (bool isVerified, bytes32 uuid) = marketRegistry.isVerifiedLender(
            marketId,
            address(lender)
        );

        assertEq(isVerified, true, "is verified was not called");
    }

    function test_isVerifiedBorrower() public {
        (bool isVerified, bytes32 uuid) = marketRegistry.isVerifiedBorrower(
            marketId,
            address(lender)
        );

        assertEq(isVerified, true, "is verified was not called");
    }

    function test_isVerified_require_attestation_valid() public {
        marketRegistry.setMarketOwner(address(this));

        marketRegistry.stubMarket(marketId, address(this));

        marketRegistry.setLenderAttestationRequired(marketId, true);

        marketRegistry.attestStakeholderVerification(
            marketId,
            address(lender),
            uuid,
            true
        );

        (bool isVerified, bytes32 uuid) = marketRegistry.isVerified(
            address(lender),
            marketId
        );

        assertEq(isVerified, true, "is verified did not return correct result");
    }

    function test_isVerified_require_attestation_invalid() public {
        marketRegistry.setMarketOwner(address(this));

        marketRegistry.stubMarket(marketId, address(this));

        marketRegistry.setLenderAttestationRequired(marketId, true);

        (bool isVerified, bytes32 uuid) = marketRegistry.isVerified(
            address(lender),
            marketId
        );

        assertEq(
            isVerified,
            false,
            "is verified did not return correct result"
        );
    }

    function test_isVerified_no_attestation() public {
        marketRegistry.setMarketOwner(address(this));

        marketRegistry.stubMarket(marketId, address(this));

        marketRegistry.setLenderAttestationRequired(marketId, false);

        (bool isVerified, bytes32 uuid) = marketRegistry.isVerified(
            address(lender),
            marketId
        );

        assertEq(isVerified, true, "is verified did not return correct result");
    }

    function test_getAllVerifiedBorrowersForMarket() public {
        bool isLender = false;

        marketRegistry.attestStakeholderVerification(
            marketId,
            address(borrower),
            uuid,
            isLender
        );

        marketRegistry.setMarketOwner(address(this));

        marketRegistry.stubMarket(marketId, address(this));

        address[] memory borrowers = marketRegistry
            .getAllVerifiedBorrowersForMarket(marketId, 0, 5);

        assertEq(
            borrowers.length,
            1,
            "Did not return correct number of borrowers"
        );

        assertEq(
            borrowers[0],
            address(borrower),
            "Did not return correct borrower"
        );
    }

    function test_getAllVerifiedLendersForMarket() public {
        bool isLender = true;

        marketRegistry.attestStakeholderVerification(
            marketId,
            address(lender),
            uuid,
            isLender
        );

        marketRegistry.setMarketOwner(address(this));

        marketRegistry.stubMarket(marketId, address(this));

        address[] memory lenders = marketRegistry
            .getAllVerifiedLendersForMarket(marketId, 0, 5);

        assertEq(lenders.length, 1, "Did not return correct number of lenders");

        assertEq(lenders[0], address(lender), "Did not return correct lender");
    }
}

/*
contract MarketRegistryUser is User {
    MarketRegistry_Override marketRegistry;

    constructor(address _tellerV2, address _marketRegistry) User(_tellerV2) {
        marketRegistry = MarketRegistry_Override(payable(_marketRegistry));
    }

    function closeMarket(uint256 marketId) public {
        marketRegistry.closeMarket(marketId);
    }

    function lenderExitMarket(uint256 marketId) public {
        marketRegistry.lenderExitMarket(marketId);
    }

    function borrowerExitMarket(uint256 marketId) public {
        marketRegistry.borrowerExitMarket(marketId);
    }

    function attestStakeholder(
        uint256 _marketId,
        address _stakeholderAddress,
        uint256 _expirationTime,
        bool _isLender
    ) public {
        marketRegistry.attestStakeholder(
            _marketId,
            _stakeholderAddress,
            _expirationTime,
            _isLender
        );
    }

    function revokeStakeholder(
        uint256 _marketId,
        address _stakeholderAddress,
        bool _isLender
    ) public {
        marketRegistry.revokeStakeholder(
            _marketId,
            _stakeholderAddress,
            _isLender
        );
    }
}
*/

contract User {

}

contract TellerV2Mock is TellerV2Context {
    Bid mockBid;

    constructor() TellerV2Context(address(0)) {}

    function setMarketRegistry(address _marketRegistry) external {
        marketRegistry = IMarketRegistry_V2(_marketRegistry);
    }

    function getSenderForMarket(uint256 _marketId)
        external
        view
        returns (address)
    {
        return _msgSenderForMarket(_marketId);
    }

    function getDataForMarket(uint256 _marketId)
        external
        view
        returns (bytes calldata)
    {
        return _msgDataForMarket(_marketId);
    }

    function setMockBid(Bid calldata bid) public {
        mockBid = bid;
    }

    function getLoanSummary(uint256 _bidId)
        external
        view
        returns (
            address borrower,
            address lender,
            uint256 marketId,
            address principalTokenAddress,
            uint256 principalAmount,
            uint32 acceptedTimestamp,
            BidState bidState
        )
    {
        Bid storage bid = mockBid;

        borrower = bid.borrower;
        lender = bid.lender;
        marketId = bid.marketplaceId;
        principalTokenAddress = address(bid.loanDetails.lendingToken);
        principalAmount = bid.loanDetails.principal;
        acceptedTimestamp = bid.loanDetails.acceptedTimestamp;
        bidState = bid.state;
    }
}
