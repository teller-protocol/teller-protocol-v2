// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { StdStorage, stdStorage } from "forge-std/StdStorage.sol";
import { Testable } from "../Testable.sol";
import { TellerV2_Override } from "./TellerV2_Override.sol";
 
import { Bid, BidState, Collateral, Payment, LoanDetails, Terms } from "../../contracts/TellerV2.sol";
 import { PaymentType, PaymentCycleType } from "../../contracts/libraries/V2Calculations.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";



contract TellerV2_bids_test is Testable {
    using stdStorage for StdStorage;

    TellerV2_Override tellerV2;



    User borrower;
    User lender;
    User receiver; 
    
    ERC20 lendingToken;


    function setUp() public {
        tellerV2 = new TellerV2_Override();

        stdstore.target(address(tellerV2)).sig("marketRegistry()").checked_write(address(0x1234));
    }

     function setMockBid(uint256 bidId) public {

         tellerV2.mock_setBid(bidId, Bid({

            borrower: address(borrower),
            lender: address(lender),
            receiver: address(receiver),
            marketplaceId: 100,
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
    FNDA:0,TellerV2.marketOwnerCancelBid
    FNDA:0,TellerV2._cancelBid
    FNDA:0,TellerV2.claimLoanNFT
    FNDA:0,TellerV2.repayLoanMinimum
    FNDA:0,TellerV2.repayLoan
   
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


    function test_cancelBid() public {

        uint256 bidId = 1;
        setMockBid(bidId);

        tellerV2.mock_setBidState(bidId, BidState.PENDING);

        tellerV2.cancelBid(bidId);

        assertTrue(tellerV2.cancelBidWasCalled(),"Cancel bid internal was not called");

    }

    function test_cancel_bid_internal_not_pending() public {

        uint256 bidId = 1;
        setMockBid(bidId);


        tellerV2.mock_setBidState(bidId, BidState.ACCEPTED);

        vm.expectRevert("incorrect state");
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
    
    
}


contract User {} 

 