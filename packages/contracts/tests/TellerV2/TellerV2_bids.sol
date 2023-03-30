// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { StdStorage, stdStorage } from "forge-std/StdStorage.sol";
import { Testable } from "../Testable.sol";
import { TellerV2_Override } from "./TellerV2_Override.sol";
 
import { Bid, BidState, Collateral, Payment, LoanDetails, Terms, ActionNotAllowed } from "../../contracts/TellerV2.sol";
 import { PaymentType, PaymentCycleType } from "../../contracts/libraries/V2Calculations.sol";


import {ReputationManagerMock} from "../../contracts/mock/ReputationManagerMock.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../tokens/TestERC20Token.sol"; 

import "lib/forge-std/src/console.sol";

contract TellerV2_bids_test is Testable {
    using stdStorage for StdStorage;

    TellerV2_Override tellerV2;


    TestERC20Token lendingToken;

    TestERC20Token lendingTokenZeroDecimals;

    User borrower;
    User lender;
    User receiver; 

    User marketOwner;

    MarketRegistryMock marketRegistryMock;

    ReputationManagerMock reputationManagerMock;
     

    uint256 marketplaceId = 100;

    function setUp() public {
        tellerV2 = new TellerV2_Override();

        marketRegistryMock = new MarketRegistryMock();
        reputationManagerMock = new ReputationManagerMock();

        borrower = new User();
        lender = new User();
        receiver = new User();

        marketOwner = new User();

        lendingToken = new TestERC20Token("Wrapped Ether","WETH",1e30,18);
        lendingTokenZeroDecimals = new TestERC20Token("Wrapped Ether","WETH",1e16,0);


        //stdstore.target(address(tellerV2)).sig("marketRegistry()").checked_write(address(0x1234));
    }

     function setMockBid(uint256 bidId) public {

         tellerV2.mock_setBid(bidId, Bid({

            borrower: address(borrower),
            lender: address(lender),
            receiver: address(receiver),
            marketplaceId: marketplaceId,
            _metadataURI: "0x1234",

            loanDetails: LoanDetails({
                lendingToken: lendingToken,
                principal: 100,
                timestamp: 100,
                acceptedTimestamp: 100,
                lastRepaidTimestamp: 100,
                loanDuration: 5000,
                totalRepaid: Payment({
                    principal: 100,
                    interest: 5 
                })

            }),
            terms: Terms({
                paymentCycleAmount: 10,
                paymentCycle: 2000,
                APR: 10
            }),
            state: BidState.PENDING,
            paymentType: PaymentType.EMI 
         })

    
        );

    }

    

    /*

    todo 

    FNDA:0,TellerV2.cancelBid
    FNDA:0,TellerV2._cancelBid

    FNDA:0,TellerV2.marketOwnerCancelBid
  
   
    FNDA:0,TellerV2.repayLoanMinimum
    FNDA:0,TellerV2.repayLoan
     FNDA:0,TellerV2.claimLoanNFT
   
    FNDA:0,TellerV2.liquidateLoanFull


    */

    function test_Reverts_when_protocol_IS_paused() public {
        tellerV2.mock_pause(true);

        vm.expectRevert("Pausable: paused");
        tellerV2.submitBid(
            address(1),    // lending token
            1,             // market ID
            100,           // principal
            365 days,      // duration
            20_00,         // interest rate
            "",            // metadata URI
            address(this)  // receiver
        );
    }

    function test_Reverts_when_protocol_IS_paused__with_collateral() public {
        tellerV2.mock_pause(true);

        Collateral[] memory collateral = new Collateral[](1);

        vm.expectRevert("Pausable: paused");
        tellerV2.submitBid(
            address(1),    // lending token
            1,             // market ID
            100,           // principal
            365 days,      // duration
            20_00,         // interest rate
            "",            // metadata URI
            address(this), // receiver
            collateral     // collateral
        );
    }


    function test_cancel_bid() public {

        uint256 bidId = 1;
        setMockBid(bidId);

        tellerV2.mock_setBidState(bidId, BidState.PENDING);

        //need to mock as owner 
        tellerV2.setMockMsgSenderForMarket(address(borrower));
        vm.prank(address(borrower));

        tellerV2.cancelBid(bidId);

        assertTrue(tellerV2.cancelBidWasCalled(),"Cancel bid internal was not called");

    }

     function test_cancel_bid_invalid_owner() public {

        uint256 bidId = 1;
        setMockBid(bidId);

        tellerV2.setMockMsgSenderForMarket(address(lender));
        tellerV2.mock_setBidState(bidId, BidState.PENDING);

        //how to specify action not allowed ? 
        vm.expectRevert( /* ActionNotAllowed(bidId,"cancelBid","Only the bid owner can cancel!") */ );
        tellerV2.cancelBid(bidId);  

         

    }

    function test_cancel_bid_internal_not_pending() public {

        uint256 bidId = 1;
        setMockBid(bidId);


        tellerV2.mock_setBidState(bidId, BidState.ACCEPTED);

        //how can i specify the expected revert message??
        vm.expectRevert( );
        tellerV2._cancelBidSuper(bidId);

         
    }

     function test_cancel_bid_internal() public {

        uint256 bidId = 1;
        setMockBid(bidId);


        tellerV2.mock_setBidState(bidId, BidState.PENDING);
 
        tellerV2._cancelBidSuper(bidId);

        BidState state = tellerV2.getBidState(bidId);

        require(state == BidState.CANCELLED,"bid was not cancelled");

    }


    function test_market_owner_cancel_bid() public {

         uint256 bidId = 1;
        setMockBid(bidId);

        //need to mock set market owner 

        tellerV2.setMarketRegistrySuper(address( marketRegistryMock ));
        marketRegistryMock.setGlobalMarketOwner(address(marketOwner));

        //why doesnt this work ?
        vm.prank(address(marketOwner));

        tellerV2.marketOwnerCancelBid(bidId);

        assertTrue(tellerV2.cancelBidWasCalled(),"Cancel bid internal was not called");

    }

    function test_market_owner_cancel_bid_invalid_owner() public {

        uint256 bidId = 1;
        setMockBid(bidId);
    
        vm.expectRevert();

        tellerV2.marketOwnerCancelBid(bidId);
 
    }

 


     function test_repay_loan_internal() public {

        uint256 bidId = 1;
        setMockBid(bidId);

         tellerV2.setMockMsgSenderForMarket(address(this));
        tellerV2.setReputationManagerSuper(address(reputationManagerMock));

        tellerV2.mock_setBidState(bidId, BidState.ACCEPTED);
        vm.warp(2000);  

        Payment memory payment = Payment({
            principal:90,
            interest:10
        });


        lendingToken.approve(address(tellerV2), 1e20);

        tellerV2._repayLoanSuper(bidId,payment,100,false);


     }


    function test_repay_loan_minimum() public {


        uint256 bidId = 1;
        setMockBid(bidId);

        tellerV2.mock_setBidState(bidId, BidState.ACCEPTED);
        vm.warp(2000);  


        //set the account that will be paying the loan off
        tellerV2.setMockMsgSenderForMarket(address(this));


        //need to get some weth 

        lendingToken.approve(address(tellerV2), 1e20);

        tellerV2.repayLoanMinimum(bidId);

        assertTrue(tellerV2.repayLoanWasCalled(),"repay loan was not called");


    } 


    function test_repay_loan_minimum_invalid_balance() public {


        uint256 bidId = 1;
        setMockBid(bidId);

        tellerV2.mock_setBidState(bidId, BidState.ACCEPTED);

    
        //need to get some weth 
        vm.prank(address(borrower));    
        //expect arithmetic overflow
        vm.expectRevert();

        tellerV2.repayLoanMinimum(bidId);

    } 

      function test_repay_loan_minimum_invalid_state() public {


        uint256 bidId = 1;
        setMockBid(bidId);

        tellerV2.mock_setBidState(bidId, BidState.PENDING);

        //how can i fill in a specific revert message ?
        vm.expectRevert();
        tellerV2.repayLoanMinimum(bidId);


    } 


    function test_repay_loan() public {

        uint256 bidId = 1;
        setMockBid(bidId);

        tellerV2.mock_setBidState(bidId, BidState.ACCEPTED);
        vm.warp(2000);  


        //set the account that will be paying the loan off
        tellerV2.setMockMsgSenderForMarket(address(this));


        //need to get some weth 

        lendingToken.approve(address(tellerV2), 1e20);

        tellerV2.repayLoan(bidId, 100);

        assertTrue(tellerV2.repayLoanWasCalled(),"repay loan was not called");


    } 


/*
    function test_liquidate_loan_full() public {

         uint256 bidId = 1;
        setMockBid(bidId);


        tellerV2.setReputationManagerSuper(address(reputationManagerMock));


        tellerV2.mock_setBidState(bidId, BidState.ACCEPTED);
        vm.warp(2000 * 1e20);  

        tellerV2.mock_setBidDefaultDuration(bidId,1000);


        //set the account that will be paying the loan off
        tellerV2.setMockMsgSenderForMarket(address(this));


        //need to get some weth 
        lendingToken.approve(address(tellerV2), 1e20);

        //why does this fail !? 
        tellerV2.liquidateLoanFull(bidId);

        assertTrue(tellerV2.repayLoanWasCalled(),"repay loan was not called");

    } */



    function test_claim_loan_nft() public {

        
    } 
 


    
    
}


contract User {} 

 

 contract MarketRegistryMock {


    address public globalMarketOwner;

    function setGlobalMarketOwner(address _globalMarketOwner) public {
        globalMarketOwner = _globalMarketOwner;
    }

    function getMarketOwner(uint256 marketId) public returns (address){
        return globalMarketOwner;
    }


 }