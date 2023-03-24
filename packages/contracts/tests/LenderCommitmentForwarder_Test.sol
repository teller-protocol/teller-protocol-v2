// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../contracts/TellerV2MarketForwarder.sol";

import "./tokens/TestERC20Token.sol";
import "../contracts/TellerV2Context.sol";

import { Testable } from "./Testable.sol";
import { LenderCommitmentForwarder } from "../contracts/LenderCommitmentForwarder.sol";

import { Collateral, CollateralType } from "../contracts/interfaces/escrow/ICollateralEscrowV1.sol";

import { User } from "./Test_Helpers.sol";

import "../contracts/mock/MarketRegistryMock.sol";


import {LenderCommitmentForwarder_Override} from "./LenderCommitmentForwarder_Override.sol";

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


          


    constructor()
        
    {}

    function setUp() public {
        tellerV2Mock = new LenderCommitmentForwarderTest_TellerV2Mock( );
        mockMarketRegistry = new MarketRegistryMock( address(0) );
 

        lenderCommitmentForwarder = new LenderCommitmentForwarder_Override( address( tellerV2Mock),  address(mockMarketRegistry));

        marketOwner = new LenderCommitmentUser(address(tellerV2Mock), address(lenderCommitmentForwarder));
        borrower = new LenderCommitmentUser(address(tellerV2Mock), address(lenderCommitmentForwarder));
        lender = new LenderCommitmentUser(address(tellerV2Mock), address(lenderCommitmentForwarder));
 
       
        tellerV2Mock.__setMarketOwner(marketOwner);
        mockMarketRegistry.setMarketOwner(address(marketOwner));

 

        //tokenAddress = address(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
        marketId = 2;
        maxPrincipal = 100000000000000000000;
        maxDuration = 2480000;
        minInterestRate = 3000;
        expiration = uint32(block.timestamp) + uint32(64000);

        marketOwner.setTrustedMarketForwarder(marketId, address(lenderCommitmentForwarder));
        lender.approveMarketForwarder(marketId, address(lenderCommitmentForwarder));

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
 
        
    }

    function test_createCommitment() public {


        LenderCommitmentForwarder.Commitment memory c = LenderCommitmentForwarder.Commitment({
            maxPrincipal: maxPrincipal,
            expiration: expiration,
            maxDuration: maxDuration,
            minInterestRate: minInterestRate,
            collateralTokenAddress: address(collateralToken),
            collateralTokenId: collateralTokenId,
            maxPrincipalPerCollateralAmount:maxPrincipalPerCollateralAmount,
            collateralTokenType: collateralTokenType,
            lender: address(lender),
            marketId: marketId,
            principalTokenAddress: address(principalToken)  
        });

        uint256 c_id = lender._createCommitment(c, emptyArray); 

         
        assertEq(lenderCommitmentForwarder.getCommitmentLender(c_id), address(lender), "unexpected lender for created commitment");

    }
 
     function test_createCommitment_invalid_lender() public {


        LenderCommitmentForwarder.Commitment memory c = LenderCommitmentForwarder.Commitment({
            maxPrincipal: maxPrincipal,
            expiration: expiration,
            maxDuration: maxDuration,
            minInterestRate: minInterestRate,
            collateralTokenAddress: address(collateralToken),
            collateralTokenId: collateralTokenId,
            maxPrincipalPerCollateralAmount:maxPrincipalPerCollateralAmount,
            collateralTokenType: collateralTokenType,
            lender: address(borrower),
            marketId: marketId,
            principalTokenAddress: address(principalToken)  
        });

        vm.expectRevert( "unauthorized commitment creator" );

        lender._createCommitment(c, emptyArray); 

    }

      function test_createCommitment_invalid_principal() public {


        LenderCommitmentForwarder.Commitment memory c = LenderCommitmentForwarder.Commitment({
            maxPrincipal: 0,
            expiration: expiration,
            maxDuration: maxDuration,
            minInterestRate: minInterestRate,
            collateralTokenAddress: address(collateralToken),
            collateralTokenId: collateralTokenId,
            maxPrincipalPerCollateralAmount:maxPrincipalPerCollateralAmount,
            collateralTokenType: collateralTokenType,
            lender: address(lender),
            marketId: marketId,
            principalTokenAddress: address(principalToken)  
        });

        vm.expectRevert(  "commitment principal allocation 0" );

        lender._createCommitment(c, emptyArray); 

    }


     function test_createCommitment_expired() public { 

        LenderCommitmentForwarder.Commitment memory c = LenderCommitmentForwarder.Commitment({
            maxPrincipal: maxPrincipal,
            expiration: 0,
            maxDuration: maxDuration,
            minInterestRate: minInterestRate,
            collateralTokenAddress: address(collateralToken),
            collateralTokenId: collateralTokenId,
            maxPrincipalPerCollateralAmount:maxPrincipalPerCollateralAmount,
            collateralTokenType: collateralTokenType,
            lender: address(lender),
            marketId: marketId,
            principalTokenAddress: address(principalToken)  
        });

        vm.expectRevert( "expired commitment" );

        lender._createCommitment(c, emptyArray);



    }


    function test_createCommitment_collateralType() public {

    }

    function test_updateCommitment() public {

        LenderCommitmentForwarder.Commitment memory c = LenderCommitmentForwarder.Commitment({
            maxPrincipal: maxPrincipal,
            expiration: expiration,
            maxDuration: maxDuration,
            minInterestRate: minInterestRate,
            collateralTokenAddress: address(collateralToken),
            collateralTokenId: collateralTokenId,
            maxPrincipalPerCollateralAmount:maxPrincipalPerCollateralAmount,
            collateralTokenType: collateralTokenType,
            lender: address(lender),
            marketId: 99,
            principalTokenAddress: address(principalToken)  
        });


        lenderCommitmentForwarder.setCommitment(
            0,
            c   
        );

        lender._updateCommitment(0, c);

           
        assertEq(lenderCommitmentForwarder.getCommitmentMarketId(0), c.marketId, "unexpected marketId after update");


    }
    function test_updateCommitment_invalid_lender() public {

        LenderCommitmentForwarder.Commitment memory c = LenderCommitmentForwarder.Commitment({
            maxPrincipal: maxPrincipal,
            expiration: 0,
            maxDuration: maxDuration,
            minInterestRate: minInterestRate,
            collateralTokenAddress: address(collateralToken),
            collateralTokenId: collateralTokenId,
            maxPrincipalPerCollateralAmount:maxPrincipalPerCollateralAmount,
            collateralTokenType: collateralTokenType,
            lender: address(lender),
            marketId: marketId,
            principalTokenAddress: address(principalToken)  
        });

        vm.expectRevert( "unauthorized commitment lender" );


        lender._updateCommitment(99, c);

    }

    function test_deleteCommitment() public {

         LenderCommitmentForwarder.Commitment memory c = LenderCommitmentForwarder.Commitment({
            maxPrincipal: maxPrincipal,
            expiration: expiration,
            maxDuration: maxDuration,
            minInterestRate: minInterestRate,
            collateralTokenAddress: address(collateralToken),
            collateralTokenId: collateralTokenId,
            maxPrincipalPerCollateralAmount:maxPrincipalPerCollateralAmount,
            collateralTokenType: collateralTokenType,
            lender: address(lender),
            marketId: marketId,
            principalTokenAddress: address(principalToken)  
        });


        lenderCommitmentForwarder.setCommitment(
            0,
            c   
        );

        lender._deleteCommitment(0);

        assertEq(lenderCommitmentForwarder.getCommitmentLender(0),address(0),"commitment data was not deleted");

    }

    function test_acceptCommitment() public {

        LenderCommitmentForwarder.Commitment memory c = LenderCommitmentForwarder.Commitment({
            maxPrincipal: maxPrincipal,
            expiration: expiration,
            maxDuration: maxDuration,
            minInterestRate: minInterestRate,
            collateralTokenAddress: address(collateralToken),
            collateralTokenId: collateralTokenId,
            maxPrincipalPerCollateralAmount:maxPrincipalPerCollateralAmount,
            collateralTokenType: collateralTokenType,
            lender: address(lender),
            marketId: marketId,
            principalTokenAddress: address(principalToken)  
        });

        uint256 commitmentId = 0;

        lenderCommitmentForwarder.setCommitment(
            commitmentId,
            c   
        );

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

    constructor(
        address _tellerV2,
        address _commitmentForwarder
    ) User(_tellerV2) {
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

    function _updateCommitment(
        uint256 commitmentId,
        LenderCommitmentForwarder.Commitment calldata _commitment
    ) public {
        commitmentForwarder.updateCommitment(commitmentId, _commitment);
    }

    function _updateCommitmentBorrowers(
        uint256 commitmentId,
        address[] calldata borrowerAddressList
    ) public {
        commitmentForwarder.updateCommitmentBorrowers(
            commitmentId,
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

    function __setMarketOwner(User _marketOwner) external {
        marketRegistry = IMarketRegistry(
            address(new MarketRegistryMock(address(_marketOwner)))
        );
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
