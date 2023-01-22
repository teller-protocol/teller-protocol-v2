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

        // Deploy protocol
        tellerV2 = new TellerV2(address(0));

        // Deploy MarketRegistry & ReputationManager
        IMarketRegistry marketRegistry = IMarketRegistry(new MarketRegistry());
        IReputationManager reputationManager = IReputationManager(
            new ReputationManager()
        );
        reputationManager.initialize(address(tellerV2));

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
            lendingTokens
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
            8000,
            7000,
            5000,
            500,
            false,
            false,
            V2Calculations.PaymentType.EMI,
            "uri://",
            IMarketRegistry.PaymentCycleType.Monthly
        );
    }

    function paymentCycleType_Test() public {
        // Get current day
        uint32 currentDay = uint32(BokkyPooBahsDateTimeLibrary.getDay(block.timestamp));

        // Submit bid as borrower
        uint256 bidId_ = borrower.submitBid(
            address(daiMock),
            marketId,
            100,
            10000,
            500,
            "metadataUri://",
            address(borrower)
        );

        // Accept bid as lender
        lender.acceptBid(bidId_);

        // Check payment cycle type
        IMarketRegistry.PaymentCycleType paymentCycleType = tellerV2.bidPaymentCycleType(bidId_);
        require(paymentCycleType == IMarketRegistry.PaymentCycleType.Monthly, 'Payment cycle type not set');
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

    function addAllowance(
        address _assetContractAddress,
        address _spender,
        uint256 _amount
    ) public {
        IERC20(_assetContractAddress).approve(_spender, _amount);
    }

    function createMarket(
        address marketRegistry,
        uint32 _paymentCycleDuration,
        uint32 _paymentDefaultDuration,
        uint32 _bidExpirationTime,
        uint16 _feePercent,
        bool _requireLenderAttestation,
        bool _requireBorrowerAttestation,
        V2Calculations.PaymentType _paymentType,
        string calldata _uri,
        IMarketRegistry.PaymentCycleType _paymentCycleType
    ) public returns (uint256) {
        return
        IMarketRegistry(marketRegistry).createMarket(
            address(this),
            _paymentCycleDuration,
            _paymentDefaultDuration,
            _bidExpirationTime,
            _feePercent,
            _requireLenderAttestation,
            _requireBorrowerAttestation,
            _paymentType,
            _uri,
            _paymentCycleType
        );
    }

    function acceptBid(uint256 _bidId) public {
        ITellerV2(tellerV2).lenderAcceptBid(_bidId);
    }

    function submitBid(
        address _lendingToken,
        uint256 _marketplaceId,
        uint256 _principal,
        uint32 _duration,
        uint16 _APR,
        string calldata _metadataURI,
        address _receiver
    ) public returns (uint256) {
        return
        ITellerV2(tellerV2).submitBid(
            _lendingToken,
            _marketplaceId,
            _principal,
            _duration,
            _APR,
            _metadataURI,
            _receiver
        );
    }
}