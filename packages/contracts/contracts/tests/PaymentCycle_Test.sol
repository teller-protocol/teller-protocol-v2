pragma solidity ^0.8.0;
// SPDX-License-Identifier: MIT

import { Testable } from "./Testable.sol";

import { TellerV2, V2Calculations } from "../TellerV2.sol";
import { MarketRegistry } from "../MarketRegistry.sol";
import { ReputationManager } from "../ReputationManager.sol";

import "../interfaces/IMarketRegistry.sol";
import "../interfaces/IReputationManager.sol";

import "../EAS/TellerAS.sol";

import "../mock/WethMock.sol";
import "../interfaces/IWETH.sol";
import "./resolvers/TestERC20Token.sol";

import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "../LenderCommitmentForwarder.sol";

import "@mangrovedao/hardhat-test-solidity/test.sol";

import "../libraries/DateTimeLib.sol";
import "../TellerV2Storage.sol";
import { PaymentType, PaymentCycleType } from "../libraries/V2Calculations.sol";
import "../CollateralManager.sol";
import "../escrow/CollateralEscrowV1.sol";

import { User } from "./Test_Helpers.sol";

contract PaymentCycle_Test is Testable {
    User private marketOwner;
    User private borrower;
    User private lender;

    TellerV2 tellerV2;
    uint256 marketId;

    WethMock wethMock;
    TestERC20Token daiMock;

    function setup_beforeAll() public {
        // Deploy test tokens
        wethMock = new WethMock();
        daiMock = new TestERC20Token("Dai", "DAI", 10000000);

        // Deploy Escrow beacon
        CollateralEscrowV1 escrowImplementation = new CollateralEscrowV1();
        UpgradeableBeacon escrowBeacon = new UpgradeableBeacon(
            address(escrowImplementation)
        );

        // Deploy protocol
        tellerV2 = new TellerV2(address(0));

        // Deploy MarketRegistry & ReputationManager
        IMarketRegistry marketRegistry = IMarketRegistry(new MarketRegistry());
        IReputationManager reputationManager = IReputationManager(
            new ReputationManager()
        );
        reputationManager.initialize(address(tellerV2));

        // Deploy Collateral manager
        CollateralManager collateralManager = new CollateralManager();
        collateralManager.initialize(address(escrowBeacon), address(tellerV2));

        // Deploy LenderCommitmentForwarder
        LenderCommitmentForwarder lenderCommitmentForwarder = new LenderCommitmentForwarder(
                address(tellerV2),
                address(marketRegistry)
            );

        address[] memory lendingTokens = new address[](2);
        lendingTokens[0] = address(wethMock);
        lendingTokens[1] = address(daiMock);

        // Initialize protocol
        tellerV2.initialize(
            50,
            address(marketRegistry),
            address(reputationManager),
            address(lenderCommitmentForwarder),
            lendingTokens,
            address(collateralManager)
        );

        // Instantiate users & balances
        marketOwner = new User(tellerV2, wethMock);
        borrower = new User(tellerV2, wethMock);
        lender = new User(tellerV2, wethMock);

        uint256 balance = 50000;
        payable(address(borrower)).transfer(balance);
        payable(address(lender)).transfer(balance * 10);
        borrower.depositToWeth(balance);
        lender.depositToWeth(balance * 10);

        daiMock.transfer(address(lender), balance * 10);
        daiMock.transfer(address(borrower), balance);
        // Approve Teller V2 for the lender's dai
        lender.addAllowance(address(daiMock), address(tellerV2), balance * 10);

        // Create a market with a monthly payment cycle type
        marketId = marketOwner.createMarket(
            address(marketRegistry),
            2592000, // 30 days
            7000,
            5000,
            500,
            false,
            false,
            PaymentType.EMI,
            PaymentCycleType.Monthly,
            "uri://"
        );

        uint256 cycleValue = marketRegistry.getPaymentCycleValue(marketId);
    }

    function paymentCycleType_test() public {
        // Submit bid as borrower
        uint256 bidId_ = borrower.submitBid(
            address(daiMock),
            marketId,
            100,
            25920000, // 10 months
            500,
            "metadataUri://",
            address(borrower)
        );

        // Accept bid as lender
        lender.acceptBid(bidId_);

        // Get accepted time
        uint256 acceptedTime = tellerV2.lastRepaidTimestamp(bidId_);

        // Check payment cycle type
        PaymentCycleType paymentCycleType = tellerV2.bidPaymentCycleType(
            bidId_
        );
        require(
            paymentCycleType == PaymentCycleType.Monthly,
            "Payment cycle type not set"
        );

        // Check next payment date
        uint32 nextMonth = uint32(
            BokkyPooBahsDateTimeLibrary.addMonths(acceptedTime, 1)
        );
        uint32 nextDueDate = tellerV2.calculateNextDueDate(bidId_);
        require(nextDueDate == nextMonth, "Incorrect due date set");
    }
}
