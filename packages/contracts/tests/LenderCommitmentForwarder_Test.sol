// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../contracts/TellerV2MarketForwarder.sol";

import "./tokens/TestERC20Token.sol";
import "./tokens/TestERC721Token.sol";
import "./tokens/TestERC1155Token.sol";
import "../contracts/TellerV2Context.sol";

import { Testable } from "./Testable.sol";
import { LenderCommitmentForwarder } from "../contracts/LenderCommitmentForwarder.sol";

import { Collateral, CollateralType } from "../contracts/interfaces/escrow/ICollateralEscrowV1.sol";

import { User } from "./Test_Helpers.sol";

import "../contracts/mock/MarketRegistryMock.sol";

import { LenderCommitmentForwarder_Override } from "./LenderCommitmentForwarder_Override.sol";

contract LenderCommitmentForwarder_Test is Testable {
    LenderCommitmentForwarderTest_TellerV2Mock private tellerV2Mock;
    MarketRegistryMock mockMarketRegistry;

    LenderCommitmentUser private marketOwner;
    LenderCommitmentUser private lender;
    LenderCommitmentUser private borrower;

    address[] emptyArray;
    address[] borrowersArray;

    TestERC20Token principalToken;
    uint8 constant principalTokenDecimals = 18;

    TestERC20Token collateralToken;
    uint8 constant collateralTokenDecimals = 6;

    TestERC721Token erc721Token;
    TestERC1155Token erc1155Token;

    LenderCommitmentForwarder_Override lenderCommitmentForwarder;

    uint256 maxPrincipal;
    uint32 expiration;
    uint32 maxDuration;
    uint16 minInterestRate;
    // address collateralTokenAddress;
    uint256 collateralTokenId;
    uint256 maxPrincipalPerCollateralAmount;
    LenderCommitmentForwarder.CommitmentCollateralType collateralTokenType;

    uint256 marketId;

    //  address principalTokenAddress;

    /*
 
           
            FNDA:0,LenderCommitmentForwarder.getCommitmentBorrowers
            FNDA:0,LenderCommitmentForwarder._getEscrowCollateralType



    */

    constructor() {}

    function setUp() public {
        tellerV2Mock = new LenderCommitmentForwarderTest_TellerV2Mock();
        mockMarketRegistry = new MarketRegistryMock();

        lenderCommitmentForwarder = new LenderCommitmentForwarder_Override(
            address(tellerV2Mock),
            address(mockMarketRegistry)
        );

        marketOwner = new LenderCommitmentUser(
            address(tellerV2Mock),
            address(lenderCommitmentForwarder)
        );
        borrower = new LenderCommitmentUser(
            address(tellerV2Mock),
            address(lenderCommitmentForwarder)
        );
        lender = new LenderCommitmentUser(
            address(tellerV2Mock),
            address(lenderCommitmentForwarder)
        );

        tellerV2Mock.__setMarketRegistry(address(mockMarketRegistry));
        mockMarketRegistry.setMarketOwner(address(marketOwner));

        //tokenAddress = address(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
        marketId = 2;
        maxPrincipal = 100000000000000000000;
        maxPrincipalPerCollateralAmount = 100;
        maxDuration = 2480000;
        minInterestRate = 3000;
        expiration = uint32(block.timestamp) + uint32(64000);

        marketOwner.setTrustedMarketForwarder(
            marketId,
            address(lenderCommitmentForwarder)
        );
        lender.approveMarketForwarder(
            marketId,
            address(lenderCommitmentForwarder)
        );

        borrowersArray = new address[](1);
        borrowersArray[0] = address(borrower);

        principalToken = new TestERC20Token(
            "Test Wrapped ETH",
            "TWETH",
            0,
            principalTokenDecimals
        );

        collateralToken = new TestERC20Token(
            "Test USDC",
            "TUSDC",
            0,
            collateralTokenDecimals
        );

        erc721Token = new TestERC721Token("ERC721", "ERC721");

        erc1155Token = new TestERC1155Token("Test 1155");
    }

    function test_createCommitment() public {
        LenderCommitmentForwarder.Commitment
            memory c = LenderCommitmentForwarder.Commitment({
                maxPrincipal: maxPrincipal,
                expiration: expiration,
                maxDuration: maxDuration,
                minInterestRate: minInterestRate,
                collateralTokenAddress: address(collateralToken),
                collateralTokenId: collateralTokenId,
                maxPrincipalPerCollateralAmount: maxPrincipalPerCollateralAmount,
                collateralTokenType: collateralTokenType,
                lender: address(lender),
                marketId: marketId,
                principalTokenAddress: address(principalToken)
            });

        uint256 c_id = lender._createCommitment(c, emptyArray);

        assertEq(
            lenderCommitmentForwarder.getCommitmentLender(c_id),
            address(lender),
            "unexpected lender for created commitment"
        );
    }

    function test_createCommitment_invalid_lender() public {
        LenderCommitmentForwarder.Commitment
            memory c = LenderCommitmentForwarder.Commitment({
                maxPrincipal: maxPrincipal,
                expiration: expiration,
                maxDuration: maxDuration,
                minInterestRate: minInterestRate,
                collateralTokenAddress: address(collateralToken),
                collateralTokenId: collateralTokenId,
                maxPrincipalPerCollateralAmount: maxPrincipalPerCollateralAmount,
                collateralTokenType: collateralTokenType,
                lender: address(borrower),
                marketId: marketId,
                principalTokenAddress: address(principalToken)
            });

        vm.expectRevert("unauthorized commitment creator");

        lender._createCommitment(c, emptyArray);
    }

    function test_createCommitment_invalid_principal() public {
        LenderCommitmentForwarder.Commitment
            memory c = LenderCommitmentForwarder.Commitment({
                maxPrincipal: 0,
                expiration: expiration,
                maxDuration: maxDuration,
                minInterestRate: minInterestRate,
                collateralTokenAddress: address(collateralToken),
                collateralTokenId: collateralTokenId,
                maxPrincipalPerCollateralAmount: maxPrincipalPerCollateralAmount,
                collateralTokenType: collateralTokenType,
                lender: address(lender),
                marketId: marketId,
                principalTokenAddress: address(principalToken)
            });

        vm.expectRevert("commitment principal allocation 0");

        lender._createCommitment(c, emptyArray);
    }

    function test_createCommitment_expired() public {
        LenderCommitmentForwarder.Commitment
            memory c = LenderCommitmentForwarder.Commitment({
                maxPrincipal: maxPrincipal,
                expiration: 0,
                maxDuration: maxDuration,
                minInterestRate: minInterestRate,
                collateralTokenAddress: address(collateralToken),
                collateralTokenId: collateralTokenId,
                maxPrincipalPerCollateralAmount: maxPrincipalPerCollateralAmount,
                collateralTokenType: collateralTokenType,
                lender: address(lender),
                marketId: marketId,
                principalTokenAddress: address(principalToken)
            });

        vm.expectRevert("expired commitment");

        lender._createCommitment(c, emptyArray);
    }

    function test_createCommitment_collateralType() public {}

    function test_updateCommitment() public {
        LenderCommitmentForwarder.Commitment
            memory c = LenderCommitmentForwarder.Commitment({
                maxPrincipal: maxPrincipal,
                expiration: expiration,
                maxDuration: maxDuration,
                minInterestRate: minInterestRate,
                collateralTokenAddress: address(collateralToken),
                collateralTokenId: collateralTokenId,
                maxPrincipalPerCollateralAmount: maxPrincipalPerCollateralAmount,
                collateralTokenType: collateralTokenType,
                lender: address(lender),
                marketId: 99,
                principalTokenAddress: address(principalToken)
            });

        lenderCommitmentForwarder.setCommitment(0, c);

        vm.prank(address(lender));
        lenderCommitmentForwarder.updateCommitment(0, c);

        assertEq(
            lenderCommitmentForwarder.getCommitmentMarketId(0),
            c.marketId,
            "unexpected marketId after update"
        );
    }

    function test_updateCommitment_invalid_lender() public {
        LenderCommitmentForwarder.Commitment
            memory c = LenderCommitmentForwarder.Commitment({
                maxPrincipal: maxPrincipal,
                expiration: 0,
                maxDuration: maxDuration,
                minInterestRate: minInterestRate,
                collateralTokenAddress: address(collateralToken),
                collateralTokenId: collateralTokenId,
                maxPrincipalPerCollateralAmount: maxPrincipalPerCollateralAmount,
                collateralTokenType: collateralTokenType,
                lender: address(lender),
                marketId: marketId,
                principalTokenAddress: address(principalToken)
            });

        vm.expectRevert("unauthorized commitment lender");

        vm.prank(address(lender));
        lenderCommitmentForwarder.updateCommitment(99, c);
    }

    function test_updateCommitment_prevent_update_principal_token() public {
        LenderCommitmentForwarder.Commitment
            memory c = LenderCommitmentForwarder.Commitment({
                maxPrincipal: maxPrincipal,
                expiration: expiration,
                maxDuration: maxDuration,
                minInterestRate: minInterestRate,
                collateralTokenAddress: address(collateralToken),
                collateralTokenId: collateralTokenId,
                maxPrincipalPerCollateralAmount: maxPrincipalPerCollateralAmount,
                collateralTokenType: collateralTokenType,
                lender: address(lender),
                marketId: 99,
                principalTokenAddress: address(principalToken)
            });

        lenderCommitmentForwarder.setCommitment(0, c);

        c.principalTokenAddress = address(collateralToken);

        vm.expectRevert("Principal token address cannot be updated.");
        vm.prank(address(lender));
        lenderCommitmentForwarder.updateCommitment(0, c);
    }

    function test_updateCommitment_prevent_update_market_id() public {
        LenderCommitmentForwarder.Commitment
            memory c = LenderCommitmentForwarder.Commitment({
                maxPrincipal: maxPrincipal,
                expiration: expiration,
                maxDuration: maxDuration,
                minInterestRate: minInterestRate,
                collateralTokenAddress: address(collateralToken),
                collateralTokenId: collateralTokenId,
                maxPrincipalPerCollateralAmount: maxPrincipalPerCollateralAmount,
                collateralTokenType: collateralTokenType,
                lender: address(lender),
                marketId: 99,
                principalTokenAddress: address(principalToken)
            });

        lenderCommitmentForwarder.setCommitment(0, c);

        c.marketId = 100;

        vm.expectRevert("Market Id cannot be updated.");
        vm.prank(address(lender));
        lenderCommitmentForwarder.updateCommitment(0, c);
    }

    function test_updateCommitmentBorrowers() public {
        LenderCommitmentForwarder.Commitment
            memory c = LenderCommitmentForwarder.Commitment({
                maxPrincipal: maxPrincipal,
                expiration: expiration,
                maxDuration: maxDuration,
                minInterestRate: minInterestRate,
                collateralTokenAddress: address(collateralToken),
                collateralTokenId: collateralTokenId,
                maxPrincipalPerCollateralAmount: maxPrincipalPerCollateralAmount,
                collateralTokenType: collateralTokenType,
                lender: address(lender),
                marketId: 99,
                principalTokenAddress: address(principalToken)
            });

        lenderCommitmentForwarder.setCommitment(0, c);

        address[] memory newBorrowers = new address[](1);
        newBorrowers[0] = address(1);

        vm.prank(address(lender));
        lenderCommitmentForwarder.updateCommitmentBorrowers(0, newBorrowers);

        //check an assertion
        assertEq(
            lenderCommitmentForwarder.getCommitmentBorrowers(0).length,
            1,
            "unexpected borrower count after update"
        );
    }

    function test_updateCommitmentBorrowers_cannot_update_empty() public {
        vm.expectRevert("unauthorized commitment lender");
        lenderCommitmentForwarder.updateCommitmentBorrowers(0, emptyArray);
    }

    function test_updateCommitmentBorrowers_unauthorized() public {
        LenderCommitmentForwarder.Commitment
            memory c = LenderCommitmentForwarder.Commitment({
                maxPrincipal: maxPrincipal,
                expiration: expiration,
                maxDuration: maxDuration,
                minInterestRate: minInterestRate,
                collateralTokenAddress: address(collateralToken),
                collateralTokenId: collateralTokenId,
                maxPrincipalPerCollateralAmount: maxPrincipalPerCollateralAmount,
                collateralTokenType: collateralTokenType,
                lender: address(lender),
                marketId: 99,
                principalTokenAddress: address(principalToken)
            });

        lenderCommitmentForwarder.setCommitment(0, c);

        vm.expectRevert("unauthorized commitment lender");
        lenderCommitmentForwarder.updateCommitmentBorrowers(0, emptyArray);
    }

    function test_deleteCommitment() public {
        LenderCommitmentForwarder.Commitment
            memory c = LenderCommitmentForwarder.Commitment({
                maxPrincipal: maxPrincipal,
                expiration: expiration,
                maxDuration: maxDuration,
                minInterestRate: minInterestRate,
                collateralTokenAddress: address(collateralToken),
                collateralTokenId: collateralTokenId,
                maxPrincipalPerCollateralAmount: maxPrincipalPerCollateralAmount,
                collateralTokenType: collateralTokenType,
                lender: address(lender),
                marketId: marketId,
                principalTokenAddress: address(principalToken)
            });

        lenderCommitmentForwarder.setCommitment(0, c);

        lender._deleteCommitment(0);

        assertEq(
            lenderCommitmentForwarder.getCommitmentLender(0),
            address(0),
            "commitment data was not deleted"
        );
    }

    function test_deleteCommitment_unauthorized() public {
        LenderCommitmentForwarder.Commitment
            memory c = LenderCommitmentForwarder.Commitment({
                maxPrincipal: maxPrincipal,
                expiration: expiration,
                maxDuration: maxDuration,
                minInterestRate: minInterestRate,
                collateralTokenAddress: address(collateralToken),
                collateralTokenId: collateralTokenId,
                maxPrincipalPerCollateralAmount: maxPrincipalPerCollateralAmount,
                collateralTokenType: collateralTokenType,
                lender: address(lender),
                marketId: marketId,
                principalTokenAddress: address(principalToken)
            });

        lenderCommitmentForwarder.setCommitment(0, c);

        vm.expectRevert("unauthorized commitment lender");

        lenderCommitmentForwarder.deleteCommitment(0);
    }

    function test_decrementCommitment() public {
        LenderCommitmentForwarder.Commitment
            memory c = LenderCommitmentForwarder.Commitment({
                maxPrincipal: maxPrincipal,
                expiration: expiration,
                maxDuration: maxDuration,
                minInterestRate: minInterestRate,
                collateralTokenAddress: address(collateralToken),
                collateralTokenId: collateralTokenId,
                maxPrincipalPerCollateralAmount: maxPrincipalPerCollateralAmount,
                collateralTokenType: collateralTokenType,
                lender: address(lender),
                marketId: marketId,
                principalTokenAddress: address(principalToken)
            });

        uint256 commitmentId = 0;

        lenderCommitmentForwarder.setCommitment(commitmentId, c);

        lenderCommitmentForwarder._decrementCommitmentSuper(commitmentId, 100);

        assertEq(
            lenderCommitmentForwarder.getCommitmentMaxPrincipal(commitmentId),
            maxPrincipal - 100,
            "Max principal not decremented"
        );
    }

    function test_validateCommitment() public {
        LenderCommitmentForwarder.Commitment
            memory c = LenderCommitmentForwarder.Commitment({
                maxPrincipal: maxPrincipal,
                expiration: expiration,
                maxDuration: maxDuration,
                minInterestRate: minInterestRate,
                collateralTokenAddress: address(collateralToken),
                collateralTokenId: collateralTokenId,
                maxPrincipalPerCollateralAmount: maxPrincipalPerCollateralAmount,
                collateralTokenType: collateralTokenType,
                lender: address(lender),
                marketId: marketId,
                principalTokenAddress: address(principalToken)
            });

        uint256 commitmentId = 0;

        lenderCommitmentForwarder.setCommitment(commitmentId, c);

        lenderCommitmentForwarder.validateCommitmentSuper(commitmentId);
    }

    function test_validateCommitment_expired() public {
        LenderCommitmentForwarder.Commitment
            memory c = LenderCommitmentForwarder.Commitment({
                maxPrincipal: maxPrincipal,
                expiration: expiration,
                maxDuration: maxDuration,
                minInterestRate: minInterestRate,
                collateralTokenAddress: address(collateralToken),
                collateralTokenId: collateralTokenId,
                maxPrincipalPerCollateralAmount: maxPrincipalPerCollateralAmount,
                collateralTokenType: collateralTokenType,
                lender: address(lender),
                marketId: marketId,
                principalTokenAddress: address(principalToken)
            });

        uint256 commitmentId = 0;

        lenderCommitmentForwarder.setCommitment(commitmentId, c);

        vm.warp(expiration + 1);

        vm.expectRevert("expired commitment");
        lenderCommitmentForwarder.validateCommitmentSuper(commitmentId);
    }

    function test_validateCommitment_zero_principal_allocation() public {
        LenderCommitmentForwarder.Commitment
            memory c = LenderCommitmentForwarder.Commitment({
                maxPrincipal: 0,
                expiration: expiration,
                maxDuration: maxDuration,
                minInterestRate: minInterestRate,
                collateralTokenAddress: address(collateralToken),
                collateralTokenId: collateralTokenId,
                maxPrincipalPerCollateralAmount: maxPrincipalPerCollateralAmount,
                collateralTokenType: collateralTokenType,
                lender: address(lender),
                marketId: marketId,
                principalTokenAddress: address(principalToken)
            });

        uint256 commitmentId = 0;

        lenderCommitmentForwarder.setCommitment(commitmentId, c);

        vm.expectRevert("commitment principal allocation 0");
        lenderCommitmentForwarder.validateCommitmentSuper(commitmentId);
    }

    function test_validateCommitment_zero_collateral_ratio() public {
        LenderCommitmentForwarder.Commitment
            memory c = LenderCommitmentForwarder.Commitment({
                maxPrincipal: maxPrincipal,
                expiration: expiration,
                maxDuration: maxDuration,
                minInterestRate: minInterestRate,
                collateralTokenAddress: address(collateralToken),
                collateralTokenId: collateralTokenId,
                maxPrincipalPerCollateralAmount: 0,
                collateralTokenType: LenderCommitmentForwarder
                    .CommitmentCollateralType
                    .ERC20,
                lender: address(lender),
                marketId: marketId,
                principalTokenAddress: address(principalToken)
            });

        uint256 commitmentId = 0;

        lenderCommitmentForwarder.setCommitment(commitmentId, c);

        vm.expectRevert("commitment collateral ratio 0");
        lenderCommitmentForwarder.validateCommitmentSuper(commitmentId);
    }

    function test_validateCommitment_erc20_with_token_id() public {
        LenderCommitmentForwarder.Commitment
            memory c = LenderCommitmentForwarder.Commitment({
                maxPrincipal: maxPrincipal,
                expiration: expiration,
                maxDuration: maxDuration,
                minInterestRate: minInterestRate,
                collateralTokenAddress: address(collateralToken),
                collateralTokenId: 66,
                maxPrincipalPerCollateralAmount: maxPrincipalPerCollateralAmount,
                collateralTokenType: LenderCommitmentForwarder
                    .CommitmentCollateralType
                    .ERC20,
                lender: address(lender),
                marketId: marketId,
                principalTokenAddress: address(principalToken)
            });

        uint256 commitmentId = 0;

        lenderCommitmentForwarder.setCommitment(commitmentId, c);

        vm.expectRevert("commitment collateral token id must be 0 for ERC20");
        lenderCommitmentForwarder.validateCommitmentSuper(commitmentId);
    }

    function test_acceptCommitment() public {
        LenderCommitmentForwarder.Commitment
            memory c = LenderCommitmentForwarder.Commitment({
                maxPrincipal: maxPrincipal,
                expiration: expiration,
                maxDuration: maxDuration,
                minInterestRate: minInterestRate,
                collateralTokenAddress: address(collateralToken),
                collateralTokenId: collateralTokenId,
                maxPrincipalPerCollateralAmount: maxPrincipalPerCollateralAmount,
                collateralTokenType: collateralTokenType,
                lender: address(lender),
                marketId: marketId,
                principalTokenAddress: address(principalToken)
            });

        uint256 commitmentId = 0;

        lenderCommitmentForwarder.setCommitment(commitmentId, c);

        uint256 bidId = borrower._acceptCommitment(
            commitmentId,
            maxPrincipal - 100, //principal
            maxPrincipal, //collateralAmount
            0, //collateralTokenId
            address(collateralToken),
            minInterestRate,
            maxDuration
        );

        assertEq(
            lenderCommitmentForwarder.acceptBidWasCalled(),
            true,
            "Expect accept bid called after exercise"
        );
    }

    function test_acceptCommitment_exact_principal() public {
        LenderCommitmentForwarder.Commitment
            memory c = LenderCommitmentForwarder.Commitment({
                maxPrincipal: maxPrincipal,
                expiration: expiration,
                maxDuration: maxDuration,
                minInterestRate: minInterestRate,
                collateralTokenAddress: address(collateralToken),
                collateralTokenId: collateralTokenId,
                maxPrincipalPerCollateralAmount: maxPrincipalPerCollateralAmount,
                collateralTokenType: collateralTokenType,
                lender: address(lender),
                marketId: marketId,
                principalTokenAddress: address(principalToken)
            });

        uint256 commitmentId = 0;

        lenderCommitmentForwarder.setCommitment(commitmentId, c);

        uint256 principalAmount = maxPrincipal;
        uint256 collateralAmount = 1000;
        uint16 interestRate = minInterestRate;
        uint32 loanDuration = maxDuration;

        // vm.expectRevert("collateral token mismatch");
        lenderCommitmentForwarder.acceptCommitment(
            commitmentId,
            principalAmount,
            collateralAmount,
            collateralTokenId,
            address(collateralToken),
            interestRate,
            loanDuration
        );

        assertEq(
            lenderCommitmentForwarder.getCommitmentMaxPrincipal(commitmentId),
            principalAmount - maxPrincipal,
            "Max principal not decremented"
        );
    }

    function test_acceptCommitment_mismatch_collateral_token() public {
        LenderCommitmentForwarder.Commitment
            memory c = LenderCommitmentForwarder.Commitment({
                maxPrincipal: maxPrincipal,
                expiration: expiration,
                maxDuration: maxDuration,
                minInterestRate: minInterestRate,
                collateralTokenAddress: address(collateralToken),
                collateralTokenId: collateralTokenId,
                maxPrincipalPerCollateralAmount: maxPrincipalPerCollateralAmount,
                collateralTokenType: collateralTokenType,
                lender: address(lender),
                marketId: marketId,
                principalTokenAddress: address(principalToken)
            });

        uint256 commitmentId = 0;

        lenderCommitmentForwarder.setCommitment(commitmentId, c);

        uint256 principalAmount = maxPrincipal;
        uint256 collateralAmount = 1000;
        uint16 interestRate = minInterestRate;
        uint32 loanDuration = maxDuration;

        vm.expectRevert("Mismatching collateral token");
        lenderCommitmentForwarder.acceptCommitment(
            commitmentId,
            principalAmount,
            collateralAmount,
            collateralTokenId,
            address(principalToken),
            interestRate,
            loanDuration
        );
    }

    function test_acceptCommitment_invalid_interest_rate() public {
        LenderCommitmentForwarder.Commitment
            memory c = LenderCommitmentForwarder.Commitment({
                maxPrincipal: maxPrincipal,
                expiration: expiration,
                maxDuration: maxDuration,
                minInterestRate: minInterestRate,
                collateralTokenAddress: address(collateralToken),
                collateralTokenId: collateralTokenId,
                maxPrincipalPerCollateralAmount: maxPrincipalPerCollateralAmount,
                collateralTokenType: collateralTokenType,
                lender: address(lender),
                marketId: marketId,
                principalTokenAddress: address(principalToken)
            });

        uint256 commitmentId = 0;

        lenderCommitmentForwarder.setCommitment(commitmentId, c);

        uint256 principalAmount = maxPrincipal;
        uint256 collateralAmount = 1000;
        uint16 interestRate = 0;
        uint32 loanDuration = maxDuration;

        vm.expectRevert("Invalid interest rate");
        lenderCommitmentForwarder.acceptCommitment(
            commitmentId,
            principalAmount,
            collateralAmount,
            collateralTokenId,
            address(collateralToken),
            interestRate,
            loanDuration
        );
    }

    function test_acceptCommitment_invalid_duration() public {
        LenderCommitmentForwarder.Commitment
            memory c = LenderCommitmentForwarder.Commitment({
                maxPrincipal: maxPrincipal,
                expiration: expiration,
                maxDuration: maxDuration,
                minInterestRate: minInterestRate,
                collateralTokenAddress: address(collateralToken),
                collateralTokenId: collateralTokenId,
                maxPrincipalPerCollateralAmount: maxPrincipalPerCollateralAmount,
                collateralTokenType: collateralTokenType,
                lender: address(lender),
                marketId: marketId,
                principalTokenAddress: address(principalToken)
            });

        uint256 commitmentId = 0;

        lenderCommitmentForwarder.setCommitment(commitmentId, c);

        uint256 principalAmount = maxPrincipal;
        uint256 collateralAmount = 1000;
        uint16 interestRate = minInterestRate;
        uint32 loanDuration = maxDuration + 100;

        vm.expectRevert("Invalid loan max duration");
        lenderCommitmentForwarder.acceptCommitment(
            commitmentId,
            principalAmount,
            collateralAmount,
            collateralTokenId,
            address(collateralToken),
            interestRate,
            loanDuration
        );
    }

    function test_acceptCommitment_invalid_commitment_borrower() public {
        LenderCommitmentForwarder.Commitment
            memory c = LenderCommitmentForwarder.Commitment({
                maxPrincipal: maxPrincipal,
                expiration: expiration,
                maxDuration: maxDuration,
                minInterestRate: minInterestRate,
                collateralTokenAddress: address(collateralToken),
                collateralTokenId: collateralTokenId,
                maxPrincipalPerCollateralAmount: maxPrincipalPerCollateralAmount,
                collateralTokenType: collateralTokenType,
                lender: address(lender),
                marketId: marketId,
                principalTokenAddress: address(principalToken)
            });

        uint256 commitmentId = 0;

        lenderCommitmentForwarder.setCommitment(commitmentId, c);

        uint256 principalAmount = maxPrincipal;
        uint256 collateralAmount = 1000;
        uint16 interestRate = minInterestRate;
        uint32 loanDuration = maxDuration;

        address[] memory newBorrowers = new address[](1);
        newBorrowers[0] = address(1);

        vm.prank(address(lender));
        lenderCommitmentForwarder.updateCommitmentBorrowers(
            commitmentId,
            newBorrowers
        );

        vm.expectRevert("unauthorized commitment borrower");
        lenderCommitmentForwarder.acceptCommitment(
            commitmentId,
            principalAmount,
            collateralAmount,
            collateralTokenId,
            address(collateralToken),
            interestRate,
            loanDuration
        );
    }

    function test_acceptCommitment_insufficient_commitment_allocation() public {
        LenderCommitmentForwarder.Commitment
            memory c = LenderCommitmentForwarder.Commitment({
                maxPrincipal: maxPrincipal,
                expiration: expiration,
                maxDuration: maxDuration,
                minInterestRate: minInterestRate,
                collateralTokenAddress: address(collateralToken),
                collateralTokenId: collateralTokenId,
                maxPrincipalPerCollateralAmount: maxPrincipalPerCollateralAmount,
                collateralTokenType: collateralTokenType,
                lender: address(lender),
                marketId: marketId,
                principalTokenAddress: address(principalToken)
            });

        uint256 commitmentId = 0;

        lenderCommitmentForwarder.setCommitment(commitmentId, c);

        uint256 principalAmount = maxPrincipal + 100;
        uint256 collateralAmount = 1000;
        uint16 interestRate = minInterestRate;
        uint32 loanDuration = maxDuration;

        vm.expectRevert(
            abi.encodeWithSelector(
                LenderCommitmentForwarder
                    .InsufficientCommitmentAllocation
                    .selector,
                c.maxPrincipal,
                principalAmount
            )
        );
        lenderCommitmentForwarder.acceptCommitment(
            commitmentId,
            principalAmount,
            collateralAmount,
            collateralTokenId,
            address(collateralToken),
            interestRate,
            loanDuration
        );
    }

    function test_acceptCommitment_insufficient_borrower_collateral() public {
        LenderCommitmentForwarder.Commitment
            memory c = LenderCommitmentForwarder.Commitment({
                maxPrincipal: maxPrincipal,
                expiration: expiration,
                maxDuration: maxDuration,
                minInterestRate: minInterestRate,
                collateralTokenAddress: address(collateralToken),
                collateralTokenId: collateralTokenId,
                maxPrincipalPerCollateralAmount: 10000,
                collateralTokenType: LenderCommitmentForwarder
                    .CommitmentCollateralType
                    .ERC20,
                lender: address(lender),
                marketId: marketId,
                principalTokenAddress: address(principalToken)
            });

        uint256 commitmentId = 0;

        lenderCommitmentForwarder.setCommitment(commitmentId, c);

        uint256 principalAmount = maxPrincipal;
        uint256 collateralAmount = 0;
        uint16 interestRate = minInterestRate;
        uint32 loanDuration = maxDuration;

        uint256 requiredCollateralAmount = lenderCommitmentForwarder
            .getRequiredCollateral(
                principalAmount,
                c.maxPrincipalPerCollateralAmount,
                c.collateralTokenType,
                c.collateralTokenAddress,
                c.principalTokenAddress
            );

        vm.expectRevert(
            abi.encodeWithSelector(
                LenderCommitmentForwarder
                    .InsufficientBorrowerCollateral
                    .selector,
                requiredCollateralAmount,
                collateralAmount
            )
        );
        lenderCommitmentForwarder.acceptCommitment(
            commitmentId,
            principalAmount,
            collateralAmount,
            collateralTokenId,
            address(collateralToken),
            interestRate,
            loanDuration
        );
    }

    function test_acceptCommitment_invalid_721_collateral_amount() public {
        LenderCommitmentForwarder.Commitment memory c = LenderCommitmentForwarder
            .Commitment({
                maxPrincipal: 100,
                expiration: expiration,
                maxDuration: maxDuration,
                minInterestRate: minInterestRate,
                collateralTokenAddress: address(erc721Token),
                collateralTokenId: 0,
                maxPrincipalPerCollateralAmount: 100 * 1e18, //expand by token decimals
                collateralTokenType: LenderCommitmentForwarder
                    .CommitmentCollateralType
                    .ERC721,
                lender: address(lender),
                marketId: marketId,
                principalTokenAddress: address(principalToken)
            });

        uint256 commitmentId = 0;

        lenderCommitmentForwarder.setCommitment(commitmentId, c);

        uint256 principalAmount = c.maxPrincipal;
        uint256 collateralAmount = 12;
        uint16 interestRate = minInterestRate;
        uint32 loanDuration = maxDuration;

        vm.expectRevert("invalid commitment collateral amount for ERC721");
        lenderCommitmentForwarder.acceptCommitment(
            commitmentId,
            principalAmount,
            collateralAmount,
            collateralTokenId,
            address(erc721Token),
            interestRate,
            loanDuration
        );
    }

    function test_acceptCommitment_invalid_collateral_id() public {}

    function test_getRequiredCollateral_erc20() public {
        LenderCommitmentForwarder.Commitment
            memory c = LenderCommitmentForwarder.Commitment({
                maxPrincipal: maxPrincipal,
                expiration: expiration,
                maxDuration: maxDuration,
                minInterestRate: minInterestRate,
                collateralTokenAddress: address(collateralToken),
                collateralTokenId: collateralTokenId,
                maxPrincipalPerCollateralAmount: 10000,
                collateralTokenType: LenderCommitmentForwarder
                    .CommitmentCollateralType
                    .ERC20,
                lender: address(lender),
                marketId: marketId,
                principalTokenAddress: address(principalToken)
            });

        uint256 commitmentId = 0;

        lenderCommitmentForwarder.setCommitment(commitmentId, c);

        uint256 principalAmount = maxPrincipal;
        uint256 collateralAmount = 0;
        uint16 interestRate = minInterestRate;
        uint32 loanDuration = maxDuration;

        uint256 requiredCollateral = lenderCommitmentForwarder
            .getRequiredCollateral(
                principalAmount,
                c.maxPrincipalPerCollateralAmount,
                c.collateralTokenType,
                c.collateralTokenAddress,
                c.principalTokenAddress
            );

        assertEq(requiredCollateral, 1e40, "unexpected required collateral");
    }

    function test_getRequiredCollateral_type_none() public {
        LenderCommitmentForwarder.Commitment
            memory c = LenderCommitmentForwarder.Commitment({
                maxPrincipal: maxPrincipal,
                expiration: expiration,
                maxDuration: maxDuration,
                minInterestRate: minInterestRate,
                collateralTokenAddress: address(collateralToken),
                collateralTokenId: collateralTokenId,
                maxPrincipalPerCollateralAmount: 10000,
                collateralTokenType: LenderCommitmentForwarder
                    .CommitmentCollateralType
                    .NONE,
                lender: address(lender),
                marketId: marketId,
                principalTokenAddress: address(principalToken)
            });

        uint256 commitmentId = 0;

        lenderCommitmentForwarder.setCommitment(commitmentId, c);

        uint256 principalAmount = maxPrincipal;
        uint256 collateralAmount = 0;
        uint16 interestRate = minInterestRate;
        uint32 loanDuration = maxDuration;

        uint256 requiredCollateral = lenderCommitmentForwarder
            .getRequiredCollateral(
                principalAmount,
                c.maxPrincipalPerCollateralAmount,
                c.collateralTokenType,
                c.collateralTokenAddress,
                c.principalTokenAddress
            );

        assertEq(requiredCollateral, 0, "unexpected required collateral");
    }

    function test_getRequiredCollateral_type_erc721() public {
        LenderCommitmentForwarder.Commitment
            memory c = LenderCommitmentForwarder.Commitment({
                maxPrincipal: 100,
                expiration: expiration,
                maxDuration: maxDuration,
                minInterestRate: minInterestRate,
                collateralTokenAddress: address(erc721Token),
                collateralTokenId: 0,
                maxPrincipalPerCollateralAmount: 100 * 1e18,
                collateralTokenType: LenderCommitmentForwarder
                    .CommitmentCollateralType
                    .ERC721,
                lender: address(lender),
                marketId: marketId,
                principalTokenAddress: address(principalToken)
            });

        uint256 commitmentId = 0;

        lenderCommitmentForwarder.setCommitment(commitmentId, c);

        uint256 principalAmount = c.maxPrincipal;

        uint256 requiredCollateral = lenderCommitmentForwarder
            .getRequiredCollateral(
                principalAmount,
                c.maxPrincipalPerCollateralAmount,
                c.collateralTokenType,
                c.collateralTokenAddress,
                c.principalTokenAddress
            );

        assertEq(requiredCollateral, 1, "unexpected required collateral");
    }

    function test_getEscrowCollateralType_erc20() public {
        CollateralType cType = lenderCommitmentForwarder
            ._getEscrowCollateralTypeSuper(
                LenderCommitmentForwarder.CommitmentCollateralType.ERC20
            );

        assertEq(
            uint16(cType),
            uint16(CollateralType.ERC20),
            "unexpected collateral type"
        );
    }

    function test_getEscrowCollateralType_erc721() public {
        CollateralType cType = lenderCommitmentForwarder
            ._getEscrowCollateralTypeSuper(
                LenderCommitmentForwarder.CommitmentCollateralType.ERC721
            );

        assertEq(
            uint16(cType),
            uint16(CollateralType.ERC721),
            "unexpected collateral type"
        );
    }

    function test_getEscrowCollateralType_erc1155() public {
        CollateralType cType = lenderCommitmentForwarder
            ._getEscrowCollateralTypeSuper(
                LenderCommitmentForwarder.CommitmentCollateralType.ERC1155
            );

        assertEq(
            uint16(cType),
            uint16(CollateralType.ERC1155),
            "unexpected collateral type"
        );
    }

    function test_getEscrowCollateralType_unknown() public {
        vm.expectRevert("Unknown Collateral Type");
        CollateralType cType = lenderCommitmentForwarder
            ._getEscrowCollateralTypeSuper(
                LenderCommitmentForwarder.CommitmentCollateralType.NONE
            );

        ///assertEq(uint16(cType), uint16(CollateralType.NONE), "unexpected collateral type");
    }

    function test_submitBidFromCommitment() public {
        address _borrower = address(borrower);
        uint256 _marketId = marketId;
        address _principalTokenAddress = address(principalToken);
        uint256 _principalAmount = 100;
        address _collateralTokenAddress = address(collateralToken);
        uint256 _collateralAmount = 1;
        uint256 _collateralTokenId = 0;
        LenderCommitmentForwarder.CommitmentCollateralType _collateralTokenType = LenderCommitmentForwarder
                .CommitmentCollateralType
                .ERC20;
        uint32 _loanDuration = 100;
        uint16 _interestRate = 100;

        uint256 bidId = lenderCommitmentForwarder._submitBidFromCommitmentSuper(
            _borrower,
            _marketId,
            _principalTokenAddress,
            _principalAmount,
            _collateralTokenAddress,
            _collateralAmount,
            _collateralTokenId,
            _collateralTokenType,
            _loanDuration,
            _interestRate
        );
    }

    function test_submitBidFromCommitment_collateral_none() public {
        address _borrower = address(borrower);
        uint256 _marketId = marketId;
        address _principalTokenAddress = address(principalToken);
        uint256 _principalAmount = 100;
        address _collateralTokenAddress = address(collateralToken);
        uint256 _collateralAmount = 1;
        uint256 _collateralTokenId = 0;
        LenderCommitmentForwarder.CommitmentCollateralType _collateralTokenType = LenderCommitmentForwarder
                .CommitmentCollateralType
                .NONE;
        uint32 _loanDuration = 100;
        uint16 _interestRate = 100;

        uint256 bidId = lenderCommitmentForwarder._submitBidFromCommitmentSuper(
            _borrower,
            _marketId,
            _principalTokenAddress,
            _principalAmount,
            _collateralTokenAddress,
            _collateralAmount,
            _collateralTokenId,
            _collateralTokenType,
            _loanDuration,
            _interestRate
        );
    }

    /*
        Overrider methods for exercise 
    */
    /*

    function _submitBid(CreateLoanArgs memory, address)
        internal
        override
        returns (uint256 bidId)
    {
        submitBidWasCalled = true;
        return 1;
    }

    function _submitBidWithCollateral(
        CreateLoanArgs memory,
        Collateral[] memory,
        address
    ) internal override returns (uint256 bidId) {
        submitBidWithCollateralWasCalled = true;
        return 1;
    }

    function _acceptBid(uint256, address) internal override returns (bool) {
        acceptBidWasCalled = true;

        assertEq(
            submitBidWithCollateralWasCalled,
            true,
            "Submit bid must be called before accept bid"
        );

        return true;
    }

    */
}

contract LenderCommitmentUser is User {
    LenderCommitmentForwarder public immutable commitmentForwarder;

    constructor(address _tellerV2, address _commitmentForwarder)
        User(_tellerV2)
    {
        commitmentForwarder = LenderCommitmentForwarder(_commitmentForwarder);
    }

    function _createCommitment(
        LenderCommitmentForwarder.Commitment calldata _commitment,
        address[] calldata borrowerAddressList
    ) public returns (uint256) {
        return
            commitmentForwarder.createCommitment(
                _commitment,
                borrowerAddressList
            );
    }

    function _acceptCommitment(
        uint256 commitmentId,
        uint256 principal,
        uint256 collateralAmount,
        uint256 collateralTokenId,
        address collateralTokenAddress,
        uint16 interestRate,
        uint32 loanDuration
    ) public returns (uint256) {
        return
            commitmentForwarder.acceptCommitment(
                commitmentId,
                principal,
                collateralAmount,
                collateralTokenId,
                collateralTokenAddress,
                interestRate,
                loanDuration
            );
    }

    function _deleteCommitment(uint256 _commitmentId) public {
        commitmentForwarder.deleteCommitment(_commitmentId);
    }
}

//Move to a helper file !
contract LenderCommitmentForwarderTest_TellerV2Mock is TellerV2Context {
    constructor() TellerV2Context(address(0)) {}

    function __setMarketRegistry(address _marketRegistry) external {
        marketRegistry = IMarketRegistry(_marketRegistry);
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
}
