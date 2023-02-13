// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Testable } from "./Testable.sol";

import { TellerV2 } from "../TellerV2.sol";
import { MarketRegistry } from "../MarketRegistry.sol";
import { ReputationManager } from "../ReputationManager.sol";

import "../TellerV2Storage.sol";

import "../interfaces/IMarketRegistry.sol";
import "../interfaces/IReputationManager.sol";

import "../EAS/TellerAS.sol";

import "../mock/WethMock.sol";
import "../interfaces/IWETH.sol";

import { PaymentType, PaymentCycleType } from "../libraries/V2Calculations.sol";
import "./Test_Helpers.sol";

/*

This should have more unit tests that operate on MarketRegistry.sol 

*/

contract MarketRegistry_Test is Testable, TellerV2 {
    User private marketOwner;
    User private borrower;
    User private lender;

    WethMock wethMock;

    constructor() TellerV2(address(address(0))) {}

    function setup_beforeAll() public {
        //wethMock = new WethMock();

        marketOwner = new User(address(this));
        borrower = new User(address(this));
        lender = new User(address(this));

        lenderCommitmentForwarder = address(0);
        marketRegistry = IMarketRegistry(new MarketRegistry());
        reputationManager = IReputationManager(new ReputationManager());
    }

    function createMarket_test() public {
        // Standard seconds payment cycle
        marketOwner.createMarket(
            address(marketRegistry),
            8000,
            7000,
            5000,
            500,
            false,
            false,
            PaymentType.EMI,
            PaymentCycleType.Seconds,
            "uri://"
        );
        (
            uint32 paymentCycleDuration,
            PaymentCycleType paymentCycle
        ) = marketRegistry.getPaymentCycle(1);

        require(
            paymentCycle == PaymentCycleType.Seconds,
            "Market payment cycle type incorrectly created"
        );

        require(
            paymentCycleDuration == 8000,
            "Market payment cycle duration set incorrectly"
        );

        // Monthly payment cycle
        marketOwner.createMarket(
            address(marketRegistry),
            0,
            7000,
            5000,
            500,
            false,
            false,
            PaymentType.EMI,
            PaymentCycleType.Monthly,
            "uri://"
        );
        (paymentCycleDuration, paymentCycle) = marketRegistry.getPaymentCycle(
            2
        );

        require(
            paymentCycle == PaymentCycleType.Monthly,
            "Monthly market payment cycle type incorrectly created"
        );

        require(
            paymentCycleDuration == 30 days,
            "Monthly market payment cycle duration set incorrectly"
        );

        // Monthly payment cycle should fail
        bool createFailed;
        try
            marketOwner.createMarket(
                address(marketRegistry),
                3000,
                7000,
                5000,
                500,
                false,
                false,
                PaymentType.EMI,
                PaymentCycleType.Monthly,
                "uri://"
            )
        {} catch {
            createFailed = true;
        }
        require(createFailed, "Monthly market should not have been created");
    }
}
