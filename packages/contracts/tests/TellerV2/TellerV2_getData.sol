// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { StdStorage, stdStorage } from "forge-std/StdStorage.sol";
import { Testable } from "../Testable.sol";
import { TellerV2_Override } from "./TellerV2_Override.sol";
import { Bid, BidState, Collateral, Payment, LoanDetails, Terms } from "../../contracts/TellerV2.sol";
 

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

    function test_getMetadataURI() public {

        uint256 bidId = 1 ;

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

      
        string memory uri = tellerV2.getMetadataURI(
          bidId          
        );

        assertEq(uri, "0x1234"); 
        
    }
 
   
   
}


contract User {} 

 