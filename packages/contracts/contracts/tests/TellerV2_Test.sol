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

import { User } from "./Test_Helpers.sol";

import "../escrow/CollateralEscrowV1.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "../LenderCommitmentForwarder.sol";
import "./resolvers/TestERC20Token.sol";

import "@mangrovedao/hardhat-test-solidity/test.sol";

contract TellerV2_Test is Testable {
    User private marketOwner;
    User private borrower;
    User private lender;

    TellerV2 tellerV2;

    WethMock wethMock;
    TestERC20Token daiMock;

    uint256 marketId1;
    uint256 collateralAmount = 10;

    function setup_beforeAll() public {
        // Deploy test tokens
        wethMock = new WethMock();
        daiMock = new TestERC20Token('Dai', 'DAI', 10000000);

        // Deploy MarketRegistry & ReputationManager
        IMarketRegistry marketRegistry = IMarketRegistry(new MarketRegistry());
        IReputationManager reputationManager = IReputationManager(new ReputationManager());
        // Deploy Escrow factory
        CollateralEscrowV1 escrowImplementation = new CollateralEscrowV1();
        UpgradeableBeacon escrowBeacon = new UpgradeableBeacon(address(escrowImplementation));

        tellerV2 = new TellerV2(address(0));
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
            address(escrowBeacon)
        );

        // Instantiate users & balances
        marketOwner = new User(tellerV2, wethMock);
        borrower = new User(tellerV2, wethMock);
        lender = new User(tellerV2, wethMock);

        uint256 balance = 50000;
        payable(address(borrower)).transfer(balance);
        payable(address(lender)).transfer(balance*10);
        borrower.depositToWeth(balance);
        lender.depositToWeth(balance*10);

        daiMock.transfer(address(lender), balance*10);
        daiMock.transfer(address(borrower), balance);
        // Approve lender's dai
        lender.addAllowance(
            address(daiMock),
            address(tellerV2),
            balance*10
        );

        // Create a market
        marketId1 = marketOwner.createMarket(
            address(marketRegistry),
            8000,
            7000,
            5000,
            500,
            false,
            false,
            V2Calculations.PaymentType.EMI,
            "uri://"
        );
    }

    function submitCollateralBid() public returns(uint256 bidId_) {
        ICollateralEscrowV1.Collateral memory collateralInfo;
        collateralInfo._amount = collateralAmount;
        collateralInfo._tokenId = 0;
        collateralInfo._collateralType = ICollateralEscrowV1.CollateralType.ERC20;
        collateralInfo._collateralAddress = address(wethMock);

        uint256 bal = wethMock.balanceOf(address(borrower));

        // Increase allowance
        // Approve borrower's weth
        borrower.addAllowance(
            address(wethMock),
            address(tellerV2),
            collateralInfo._amount
        );

        bidId_ = borrower.submitCollateralBid(
            address(daiMock),
            marketId1,
            100,
            10000,
            500,
            "metadataUri://",
            address(borrower),
            collateralInfo
        );
    }

    function acceptBid(uint256 _bidId) public {
        // Accept bid
        lender.acceptBid(
            _bidId
        );
    }

    function collateralEscrow_test() public {
        uint256 bidId = submitCollateralBid();
        acceptBid(bidId);

        // Get newly created escrow
        address escrowAddress = tellerV2._escrows(bidId);
        CollateralEscrowV1 escrow = CollateralEscrowV1(escrowAddress);

        uint256 storedBidId = escrow.getBid();

        // Test that the created escrow has the same bidId and collateral stored
        Test.eq(
            bidId,
            storedBidId,
            'Collateral escrow was not created'
        );

        uint256 escrowBalance = wethMock.balanceOf(escrowAddress);

        Test.eq(
            collateralAmount,
            escrowBalance,
            'Collateral was not stored'
        );
    }
}
