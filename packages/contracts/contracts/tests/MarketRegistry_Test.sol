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

contract MarketRegistry_Test is Testable, TellerV2 {
    User private marketOwner;
    User private borrower;
    User private lender;

    WethMock wethMock;

    constructor() TellerV2(address(address(0))) {}

    function setup_beforeAll() public {
        wethMock = new WethMock();

        marketOwner = new User(this, wethMock);
        borrower = new User(this, wethMock);
        lender = new User(this, wethMock);

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
        ( ,PaymentCycleType paymentCycle) = marketRegistry
            .getPaymentCycleDuration(1);

        require(
            paymentCycle == PaymentCycleType.Seconds,
            "Market payment cycle type incorrectly created"
        );

        // Monthly payment cycle
        marketOwner.createMarket(
            address(marketRegistry),
            8000,
            7000,
            5000,
            500,
            false,
            false,
            PaymentType.EMI,
            PaymentCycleType.Monthly,
            "uri://"
        );
        (, paymentCycle) = marketRegistry.getPaymentCycleDuration(2);

        require(
            paymentCycle == PaymentCycleType.Monthly,
            "Market payment cycle type incorrectly created"
        );
    }
}

contract User {
    TellerV2 public immutable tellerV2;
    WethMock public immutable wethMock;

    constructor(TellerV2 _tellerV2, WethMock _wethMock) {
        tellerV2 = _tellerV2;
        wethMock = _wethMock;
    }

    function depositToWeth(uint256 amount) public {
        wethMock.deposit{ value: amount }();
    }

    function createMarket(
        address marketRegistry,
        uint32 _paymentCycleDuration,
        uint32 _paymentDefaultDuration,
        uint32 _bidExpirationTime,
        uint16 _feePercent,
        bool _requireLenderAttestation,
        bool _requireBorrowerAttestation,
        PaymentType _paymentType,
        PaymentCycleType _paymentCycleType,
        string calldata _uri
    ) public {
        IMarketRegistry(marketRegistry).createMarket(
            address(this),
            _paymentCycleDuration,
            _paymentDefaultDuration,
            _bidExpirationTime,
            _feePercent,
            _requireLenderAttestation,
            _requireBorrowerAttestation,
            _paymentType,
            _paymentCycleType,
            _uri
        );
    }
}
