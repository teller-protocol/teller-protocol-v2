// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { StdStorage, stdStorage } from "forge-std/StdStorage.sol";
import { Testable } from "../Testable.sol";
import { TellerV2_Override } from "./TellerV2_Override.sol";
import { Bid, BidState, Collateral, Payment, LoanDetails, Terms } from "../../contracts/TellerV2.sol";
 
 import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { PaymentType, PaymentCycleType } from "../../contracts/libraries/V2Calculations.sol";




contract TellerV2_initialize is Testable {
  

    TellerV2_Override tellerV2;

    uint16 protocolFee = 5;
    
    ERC20 lendingToken;

    function setUp() public {
        tellerV2 = new TellerV2_Override();

        lendingToken = new ERC20("Wrapped Ether","WETH");

 
    }


    /*

    TODO 


    FNDA:0,TellerV2.calculateAmountOwed
    FNDA:0,TellerV2.calculateAmountDue
    FNDA:0,TellerV2.calculateAmountDue
    FNDA:0,TellerV2.calculateNextDueDate


    FNDA:0,TellerV2.isLoanLiquidateable
    FNDA:0,TellerV2.getBorrowerActiveLoanIds
    FNDA:0,TellerV2.getBorrowerLoanIds
    FNDA:0,TellerV2.isLoanExpired
    FNDA:0,TellerV2.lastRepaidTimestamp
    FNDA:0,TellerV2.getLoanLender
    FNDA:0,TellerV2.getLoanLendingToken
    FNDA:0,TellerV2.getLoanMarketId
    FNDA:0,TellerV2.getLoanSummary


    */

    function setMockBid(uint256 bidId) public {

         tellerV2.mock_setBid(bidId, Bid({

            borrower: address(0x1234),
            lender: address(0x1234),
            receiver: address(0x1234),
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

    

    function test_getMetadataURI_without_mapping() public {

        uint256 bidId = 1 ;
        setMockBid(1); 
      
        string memory uri = tellerV2.getMetadataURI(
          bidId          
        );


        //why is this true ?
        uint256 expectedUri = 0x3078313233340000000000000000000000000000000000000000000000000000;

        // expect deprecated bytes32 uri as a string
        assertEq(uri, StringsUpgradeable.toHexString(expectedUri, 32) ); 
        
    }

    function test_getMetadataURI_with_mapping() public {

           uint256 bidId = 1 ;
        setMockBid(1); 

        tellerV2.mock_addUriToMapping(bidId, "0x1234");
      
        string memory uri = tellerV2.getMetadataURI(
          bidId          
        );

        assertEq(uri, "0x1234"); 

    }

    function test_isLoanLiquidateable_false() public {

        uint256 bidId = 1 ;
        setMockBid(1); 

        bool liquidateable = tellerV2.isLoanLiquidateable(bidId);

        assertEq(liquidateable, false); 

    }

    function test_isLoanLiquidateable_true() public {

        uint256 bidId = 1 ;
        setMockBid(1); 

        //set to accepted 

        vm.warp(1000000);

        bool liquidateable = tellerV2.isLoanLiquidateable(bidId);

        assertEq(liquidateable, true); 

    }
 
    function test_isLoanExpired() public {} 

    function test_lastRepaidTimestamp() public {

    }

    function test_getLoanLender() public {}

    function test_getLoanLendingToken() public {}

    function test_getLoanMarketId() public {}

    function test_getLoanSummary() public {}

  
}


contract User {} 

 