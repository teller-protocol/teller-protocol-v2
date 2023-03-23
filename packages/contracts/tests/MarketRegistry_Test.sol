// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Testable } from "./Testable.sol";

import { TellerV2 } from "../contracts/TellerV2.sol";
import { MarketRegistry } from "../contracts/MarketRegistry.sol";
 
 import "../contracts/TellerV2Context.sol";

import "../contracts/TellerV2Storage.sol";

import "../contracts/interfaces/IMarketRegistry.sol"; 

import "../contracts/EAS/TellerAS.sol";

import "../contracts/mock/WethMock.sol";
import "../contracts/interfaces/IWETH.sol";

import { User } from "./Test_Helpers.sol";
import { PaymentType, PaymentCycleType } from "../contracts/libraries/V2Calculations.sol";

import {MarketRegistry_Override} from "./MarketRegistry_Override.sol";


import {TellerASMock} from "../contracts/mock/TellerASMock.sol";

contract MarketRegistry_Test is Testable {
    MarketRegistryUser private marketOwner;
    MarketRegistryUser private borrower;
    MarketRegistryUser private lender;
    MarketRegistryUser private stakeholder;

    WethMock wethMock;

    TellerV2Mock tellerV2;
    MarketRegistry_Override marketRegistry;

    TellerASMock tellerASMock;
    
    uint32 expirationTime = 5000;
    uint256 marketId = 2;

    bytes32 uuid = bytes32("0x042");

    constructor()  {}

    function setUp() public {
      

        tellerV2 = new TellerV2Mock(   );
        marketRegistry = new MarketRegistry_Override(   );

        tellerASMock = new TellerASMock();

        marketRegistry.initialize( tellerASMock );

        marketOwner = new MarketRegistryUser(address(tellerV2),address(marketRegistry));
        borrower = new MarketRegistryUser(address(tellerV2),address(marketRegistry));
        lender = new MarketRegistryUser(address(tellerV2),address(marketRegistry));

        marketRegistry.setMarketOwner(address(marketOwner));
      

        tellerV2.setMarketRegistry(address(marketRegistry));
 
       // reputationManager = IReputationManager(new ReputationManager());
    }


    function test_marketIsClosed() public {
      
        assertEq(
            marketRegistry.isMarketClosed(0),
            false,
            "Null market should not be closed"
        );
 
 
      }

    function test_createMarket_simple() public {
        // Standard seconds payment cycle
        uint256 marketId = marketOwner.createMarketSimple(
            address(marketRegistry),
            uint32(8000),
            uint32(7000),
            uint32(5000),
            uint16(500),
            false,
            false,
            "uri://"
        );


        (address owner,,,,,,) = marketRegistry.getMarketData(marketId);

        assertEq(
            owner,
            address(marketOwner),
            "Market not created"
        );
      }

        function test_closeMarket() public {
       
        uint256 marketId = marketOwner.createMarketSimple(
            address(marketRegistry),
            uint32(8000),
            uint32(7000),
            uint32(5000),
            uint16(500),
            false,
            false,
            "uri://"
        );


        marketOwner.closeMarket(marketId);

        bool marketIsClosed = marketRegistry.isMarketClosed(marketId);

        assertEq(
            marketIsClosed,
            true,
            "Market not closed"
        );
      }

    function test_createMarket() public {
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

        assertEq(
            paymentCycleDuration, 8000,
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

        assertEq(
            paymentCycleDuration , 30 days,
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

    function test_attestStakeholder() public {


        assertEq(
            marketRegistry.getMarketOwner(marketId),
            address(marketOwner),
            "Not overriding market owner"
        );
        
        bool isLender = true; 

        marketOwner.attestStakeholder(
            marketId,
            address(lender),
            expirationTime,
            isLender
        );

        assertEq(
            marketRegistry.attestStakeholderVerificationWasCalled(),
            true,
            "Attest stakeholder verification was not called"
        );
    }

    function test_attestStakeholder_notMarketOwner() public {

        bool isLender = true; 

        vm.expectRevert();

        marketRegistry.attestStakeholder(
            marketId,
            address(lender),
            expirationTime,
            isLender
        );

    }


    function test_attestStakeholderVerification_lender() public {

        bool isLender = true; 

        marketRegistry.attestStakeholderVerification( 
            marketId,
            address(lender),
            uuid,
            isLender
         );

        //expect that the lender is attested  

        assertEq(
            marketRegistry.marketVerifiedLendersContains(marketId,address(lender)),
            true,
            "Did not add lender to verified set"
        );

        assertEq(
            marketRegistry.getLenderAttestationId(marketId,address(lender)),
            uuid,
            "Did not set market attestation Id"
        );
        
    }

        function test_attestStakeholderVerification_borrower() public {

        bool isLender = false; 

        marketRegistry.attestStakeholderVerification( 
            marketId,
            address(borrower),
            uuid,
            isLender
         );

        //expect that the borrower is attested  

        assertEq(
            marketRegistry.marketVerifiedBorrowersContains(marketId,address(borrower)),
            true,
            "Did not add lender to verified set"
        );

        assertEq(
            marketRegistry.getBorrowerAttestationId(marketId,address(borrower)),
            uuid,
            "Did not set market attestation Id"
        );
        
    }

    function test_attestLender() public {
 

        marketRegistry.attestLender(
            marketId,
            address(lender),
            expirationTime 
        );

        assertEq(
            marketRegistry.attestStakeholderWasCalled(),
            true,
            "Attest stakeholder was not called"
        );
    }

    function test_attestLenderDelegated() public {}


    function test_revokeLender() public {}

    function test_lenderExitMarket() public {}



    function test_attestBorrowerDelegated() public {}

    function test_revokeBorrower() public {}

    function test_borrowerExitMarket() public {}

    function test_resolve() public {}

    function test_transferMarketOwnership() public {}

    function test_updateMarketSettings() public {}

    function test_setMarketFeeRecipient() public {} 

    function test_setMarketURI() public {} 

    function test_setPaymentCycle() public {} 

    function test_setPaymentDefaultDuration() public {} 

    function test_setBidExpirationTime() public {} 

    function test_setMarketFeePercent() public {} 

    function test_setMarketPaymentType() public {} 

    function test_setLenderAttestationRequired() public {}

    function test_setBorrowerAttestationRequired() public {} 

    function test_getMarketOwner() public {} 

    function test_getMarketFeeRecipient() public {} 

    function test_getMarketURI() public {} 

    function test_getPaymentCycle() public {} 

    function test_getPaymentDefaultDuration() public {} 

    function test_getPaymentType() public {} 

    function test_getBidExpirationTime() public {} 

    function test_getMarketplaceFee() public {} 

    function test_isVerifiedLender() public {} 

    function test_isVerifiedBorrower() public {} 

    function test_isVerified() public {}



}



contract MarketRegistryUser is User {

    MarketRegistry_Override marketRegistry;

    constructor(address _tellerV2,address _marketRegistry) User(_tellerV2) {

        marketRegistry = MarketRegistry_Override(payable(_marketRegistry));

    }


    function closeMarket(uint256 marketId) public {

        marketRegistry.closeMarket(marketId);

    }

    function attestStakeholder(
        uint256 _marketId,
        address _stakeholderAddress,
        uint256 _expirationTime,
        bool _isLender
    ) public {

        marketRegistry.attestStakeholder(
            _marketId,
            _stakeholderAddress,
            _expirationTime,
            _isLender
        );
    }

     



}


contract TellerV2Mock is TellerV2Context {
    Bid mockBid;

    constructor() TellerV2Context(address(0)) {}

  

    function setMarketRegistry(address _marketRegistry) external {
        marketRegistry = IMarketRegistry(
           _marketRegistry
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

    function setMockBid(Bid calldata bid) public {
        mockBid = bid;
    }

    function getLoanSummary(uint256 _bidId)
        external
        view
        returns (
            address borrower,
            address lender,
            uint256 marketId,
            address principalTokenAddress,
            uint256 principalAmount,
            uint32 acceptedTimestamp,
            BidState bidState
        )
    {
        Bid storage bid = mockBid;

        borrower = bid.borrower;
        lender = bid.lender;
        marketId = bid.marketplaceId;
        principalTokenAddress = address(bid.loanDetails.lendingToken);
        principalAmount = bid.loanDetails.principal;
        acceptedTimestamp = bid.loanDetails.acceptedTimestamp;
        bidState = bid.state;
    }
}


