import { Testable } from "../../../Testable.sol";

import { LenderCommitmentGroup_Smart_Override } from "./LenderCommitmentGroup_Smart_Override.sol";

import {TestERC20Token} from "../../../tokens/TestERC20Token.sol";

import {TellerV2SolMock} from "../../../../contracts/mock/TellerV2SolMock.sol";
import {UniswapV3PoolMock} from "../../../../contracts/mock/uniswap/UniswapV3PoolMock.sol";
import {UniswapV3FactoryMock} from "../../../../contracts/mock/uniswap/UniswapV3FactoryMock.sol";
import { PaymentType, PaymentCycleType } from "../../../../contracts/libraries/V2Calculations.sol";
import { LoanDetails, Payment, BidState , Bid, Terms } from "../../../../contracts/TellerV2Storage.sol";


import "lib/forge-std/src/console.sol";

//contract LenderCommitmentGroup_Smart_Mock is ExtensionsContextUpgradeable {}

/*
  

Write tests for a borrower . borrowing money from the group 



- write tests for the LTV ratio and make sure that is working as expected (mock) 
- write tests for the global liquidityThresholdPercent and built functionality for a user-specific liquidityThresholdPercent based on signalling shares.



-write a test that ensures that adding principal then removing it will mean that totalPrincipalCommitted is the net amount 
 

*/

contract LenderCommitmentGroup_Smart_Test is Testable {
    constructor() {}

    User private extensionContract;

    User private borrower;
    User private lender;
    User private liquidator;

    TestERC20Token principalToken;

    TestERC20Token collateralToken;

    LenderCommitmentGroup_Smart_Override lenderCommitmentGroupSmart;

    TellerV2SolMock _tellerV2;
    SmartCommitmentForwarder _smartCommitmentForwarder;
    UniswapV3PoolMock _uniswapV3Pool;
    UniswapV3FactoryMock _uniswapV3Factory;

    function setUp() public {
        borrower = new User();
        lender = new User();
        liquidator = new User();

        _tellerV2 = new TellerV2SolMock();
        _smartCommitmentForwarder = new SmartCommitmentForwarder();
        _uniswapV3Pool = new UniswapV3PoolMock();

        _uniswapV3Factory = new UniswapV3FactoryMock();
        _uniswapV3Factory.setPoolMock(address(_uniswapV3Pool));
 

        principalToken = new TestERC20Token("wrappedETH", "WETH", 1e24, 18);

        collateralToken = new TestERC20Token("PEPE", "pepe", 1e24, 18);

        principalToken.transfer(address(lender), 1e18);
        collateralToken.transfer(address(borrower), 1e18);


        _uniswapV3Pool.set_mockToken0(address(principalToken));
        _uniswapV3Pool.set_mockToken1(address(collateralToken));

        lenderCommitmentGroupSmart = new LenderCommitmentGroup_Smart_Override(
            address(_tellerV2),
            address(_smartCommitmentForwarder),
            address(_uniswapV3Factory)
        );
    }

    function initialize_group_contract() public {
        address _principalTokenAddress = address(principalToken);
        address _collateralTokenAddress = address(collateralToken);
        uint256 _marketId = 1;
        uint32 _maxLoanDuration = 5000000;
        uint16 _minInterestRate = 0;
        uint16 _maxInterestRate = 800;
        uint16 _liquidityThresholdPercent = 10000;
        uint16 _loanToValuePercent = 10000;
        uint24 _uniswapPoolFee = 3000;
        uint32 _twapInterval = 5;

        address _poolSharesToken = lenderCommitmentGroupSmart.initialize(
            _principalTokenAddress,
            _collateralTokenAddress,
            _marketId,
            _maxLoanDuration,
            _minInterestRate,
            _maxInterestRate,
            _liquidityThresholdPercent,
            _loanToValuePercent,
            _uniswapPoolFee,
            _twapInterval
        );
    }

    function test_initialize() public {
        address _principalTokenAddress = address(principalToken);
        address _collateralTokenAddress = address(collateralToken);
        uint256 _marketId = 1;
        uint32 _maxLoanDuration = 5000000;
        uint16 _minInterestRate = 100;
         uint16 _maxInterestRate = 800;
        uint16 _liquidityThresholdPercent = 10000;
        uint16 _loanToValuePercent = 10000;
        uint24 _uniswapPoolFee = 3000;
        uint32 _twapInterval = 5;

        address _poolSharesToken = lenderCommitmentGroupSmart.initialize(
            _principalTokenAddress,
            _collateralTokenAddress,
            _marketId,
            _maxLoanDuration,
            _minInterestRate,
            _maxInterestRate,
            _liquidityThresholdPercent,
            _loanToValuePercent,
            _uniswapPoolFee,
            _twapInterval
        );

        // assertFalse(isTrustedBefore, "Should not be trusted forwarder before");
        // assertTrue(isTrustedAfter, "Should be trusted forwarder after");
    }

    //  https://github.com/teller-protocol/teller-protocol-v1/blob/develop/contracts/lending/ttoken/TToken_V3.sol
    function test_addPrincipalToCommitmentGroup() public {
        //principalToken.transfer(address(lenderCommitmentGroupSmart), 1e18);
        //collateralToken.transfer(address(lenderCommitmentGroupSmart), 1e18);
        lenderCommitmentGroupSmart.set_mockSharesExchangeRate(1e36);

        initialize_group_contract();

        vm.prank(address(lender));
        principalToken.approve(address(lenderCommitmentGroupSmart), 1000000);

        vm.prank(address(lender));
        uint256 sharesAmount_ = lenderCommitmentGroupSmart
            .addPrincipalToCommitmentGroup(1000000, address(borrower));

        uint256 expectedSharesAmount = 1000000;

        //use ttoken logic to make this better
        assertEq(
            sharesAmount_,
            expectedSharesAmount,
            "Received an unexpected amount of shares"
        );
    }

    function test_addPrincipalToCommitmentGroup_after_interest_payments()
        public
    {
        principalToken.transfer(address(lenderCommitmentGroupSmart), 1e18);
        collateralToken.transfer(address(lenderCommitmentGroupSmart), 1e18);

        lenderCommitmentGroupSmart.set_mockSharesExchangeRate(1e36 * 2);

        initialize_group_contract();

        //lenderCommitmentGroupSmart.set_totalPrincipalTokensCommitted(1000000);
        //lenderCommitmentGroupSmart.set_totalInterestCollected(2000000);

        vm.prank(address(lender));
        principalToken.approve(address(lenderCommitmentGroupSmart), 1000000);

        vm.prank(address(lender));
        uint256 sharesAmount_ = lenderCommitmentGroupSmart
            .addPrincipalToCommitmentGroup(1000000, address(borrower));

        uint256 expectedSharesAmount = 500000;

        //use ttoken logic to make this better
        assertEq(
            sharesAmount_,
            expectedSharesAmount,
            "Received an unexpected amount of shares"
        );
    }

    function test_addPrincipalToCommitmentGroup_after_nonzero_shares()
        public
    {
        principalToken.transfer(address(lenderCommitmentGroupSmart), 1e18);
        collateralToken.transfer(address(lenderCommitmentGroupSmart), 1e18);
 
       
        initialize_group_contract();
        lenderCommitmentGroupSmart.set_totalInterestCollected(1e6 * 1);
        lenderCommitmentGroupSmart.set_totalPrincipalTokensCommitted(1e6 * 1);

        

        vm.prank(address(lender));
        principalToken.approve(address(lenderCommitmentGroupSmart), 1000000);

        vm.prank(address(lender));
        uint256 sharesAmount_ = lenderCommitmentGroupSmart
            .addPrincipalToCommitmentGroup(1000000, address(borrower));

        uint256 expectedSharesAmount = 1000000;

        //use ttoken logic to make this better
        assertEq(
            sharesAmount_,
            expectedSharesAmount,
            "Received an unexpected amount of shares"
        );
    }

    function test_burnShares_simple() public {
        principalToken.transfer(address(lenderCommitmentGroupSmart), 1e18);
        // collateralToken.transfer(address(lenderCommitmentGroupSmart),1e18);

        initialize_group_contract();

          lenderCommitmentGroupSmart.set_mockSharesExchangeRate( 1e36 );  //this means 1:1 since it is expanded

       // lenderCommitmentGroupSmart.set_totalPrincipalTokensCommitted(1000000);
       // lenderCommitmentGroupSmart.set_totalInterestCollected(0);

      
        lenderCommitmentGroupSmart.set_totalPrincipalTokensCommitted(
            
            1000000
        );

        vm.prank(address(lender));
        principalToken.approve(address(lenderCommitmentGroupSmart), 1000000);

        vm.prank(address(lender));

        uint256 sharesAmount = 1000000;
        //should have all of the shares at this point
        lenderCommitmentGroupSmart.mock_mintShares(
            address(lender),
            sharesAmount
        );

        vm.prank(address(lender));
        
         uint256 receivedPrincipalTokens 
          = lenderCommitmentGroupSmart.burnSharesToWithdrawEarnings(
                sharesAmount,
                address(lender)
            );

        uint256 expectedReceivedPrincipalTokens = 1000000; // the orig amt !
        assertEq(
            receivedPrincipalTokens,
            expectedReceivedPrincipalTokens,
            "Received an unexpected amount of principaltokens"
        );
    }


    function test_burnShares_simple_with_ratio_math() public {
        principalToken.transfer(address(lenderCommitmentGroupSmart), 1e18);
        // collateralToken.transfer(address(lenderCommitmentGroupSmart),1e18);

        initialize_group_contract();

          lenderCommitmentGroupSmart.set_mockSharesExchangeRate( 2e36 );  //this means 1:1 since it is expanded

       // lenderCommitmentGroupSmart.set_totalPrincipalTokensCommitted(1000000);
       // lenderCommitmentGroupSmart.set_totalInterestCollected(0);

        lenderCommitmentGroupSmart.set_totalPrincipalTokensCommitted(
            
            1000000
        );

        vm.prank(address(lender));
        principalToken.approve(address(lenderCommitmentGroupSmart), 1000000);

        vm.prank(address(lender));

        uint256 sharesAmount = 500000;
        //should have all of the shares at this point
        lenderCommitmentGroupSmart.mock_mintShares(
            address(lender),
            sharesAmount
        );

        vm.prank(address(lender));
        
         uint256 receivedPrincipalTokens 
          = lenderCommitmentGroupSmart.burnSharesToWithdrawEarnings(
                sharesAmount,
                address(lender)
            );

        uint256 expectedReceivedPrincipalTokens = 1000000; // the orig amt !
        assertEq(
            receivedPrincipalTokens,
            expectedReceivedPrincipalTokens,
            "Received an unexpected amount of principaltokens"
        );
    }

    function test_burnShares_also_get_collateral() public {
        principalToken.transfer(address(lenderCommitmentGroupSmart), 1e18);
        collateralToken.transfer(address(lenderCommitmentGroupSmart), 1e18);

        initialize_group_contract();

        lenderCommitmentGroupSmart.set_mockSharesExchangeRate( 1e36 );  //the default for now 
 

        lenderCommitmentGroupSmart.set_totalPrincipalTokensCommitted(
            
            1000000
        );

        vm.prank(address(lender));
        principalToken.approve(address(lenderCommitmentGroupSmart), 1000000);

        vm.prank(address(lender));

        uint256 sharesAmount = 500000;
        //should have all of the shares at this point
        lenderCommitmentGroupSmart.mock_mintShares(
            address(lender),
            sharesAmount
        );

        vm.prank(address(lender));
    
            uint256 receivedPrincipalTokens
         = lenderCommitmentGroupSmart.burnSharesToWithdrawEarnings(
                sharesAmount,
                address(lender)
            );

        uint256 expectedReceivedPrincipalTokens = 500000; // the orig amt !
        assertEq(
            receivedPrincipalTokens,
            expectedReceivedPrincipalTokens,
            "Received an unexpected amount of principal tokens"
        );
 
    }

     //test this thoroughly -- using spreadsheet data 
    function test_get_shares_exchange_rate_scenario_A() public {
          initialize_group_contract();

        lenderCommitmentGroupSmart.set_totalInterestCollected(0);

        lenderCommitmentGroupSmart.set_totalPrincipalTokensCommitted(
             
            5000000
        );

        uint256 rate = lenderCommitmentGroupSmart.super_sharesExchangeRate();

         assertEq(rate , 1e36, "unexpected sharesExchangeRate");

    }

    function test_get_shares_exchange_rate_scenario_B() public {
          initialize_group_contract();

        lenderCommitmentGroupSmart.set_totalInterestCollected(1000000);

        lenderCommitmentGroupSmart.set_totalPrincipalTokensCommitted(
 
            1000000
        );

         lenderCommitmentGroupSmart.set_totalPrincipalTokensWithdrawn(
            
            1000000
        );

        uint256 rate = lenderCommitmentGroupSmart.super_sharesExchangeRate();

         assertEq(rate , 1e36, "unexpected sharesExchangeRate");

    }

    function test_get_shares_exchange_rate_scenario_C() public {
        initialize_group_contract();


        lenderCommitmentGroupSmart.set_totalPrincipalTokensCommitted(
             
            1000000
        );

        lenderCommitmentGroupSmart.set_totalInterestCollected(1000000);

        uint256 sharesAmount = 500000;


        lenderCommitmentGroupSmart.mock_mintShares(
            address(lender),
            sharesAmount
        );

        uint256 poolTotalEstimatedValue = lenderCommitmentGroupSmart.getPoolTotalEstimatedValue();
        assertEq(poolTotalEstimatedValue ,  2 * 1000000, "unexpected poolTotalEstimatedValue");

        uint256 rate = lenderCommitmentGroupSmart.super_sharesExchangeRate();

        assertEq(rate , 4 * 1e36, "unexpected sharesExchangeRate");

        /*
            Rate should be 2 at this point so a depositor will only get half as many shares for their principal 
        */
    }


 
 
    function test_get_shares_exchange_rate_after_default_liquidation_A() public {
         initialize_group_contract();


        lenderCommitmentGroupSmart.set_totalPrincipalTokensCommitted(
            1000000
        );

        lenderCommitmentGroupSmart.set_totalInterestCollected(1000000);

        lenderCommitmentGroupSmart.set_tokenDifferenceFromLiquidations(-1000000);

        uint256 sharesAmount = 1000000;

        lenderCommitmentGroupSmart.mock_mintShares(
            address(lender),
            sharesAmount
        );

        uint256 poolTotalEstimatedValue = lenderCommitmentGroupSmart.getPoolTotalEstimatedValue();
        assertEq(poolTotalEstimatedValue ,  1 * 1000000, "unexpected poolTotalEstimatedValue");

        uint256 rate = lenderCommitmentGroupSmart.super_sharesExchangeRate();

        assertEq(rate , 1 * 1e36, "unexpected sharesExchangeRate");

    }


 
    function test_get_shares_exchange_rate_after_default_liquidation_B() public {
         initialize_group_contract();


        lenderCommitmentGroupSmart.set_totalPrincipalTokensCommitted(
            1000000
        );

    
        lenderCommitmentGroupSmart.set_tokenDifferenceFromLiquidations(-500000);

        uint256 sharesAmount = 1000000;

        lenderCommitmentGroupSmart.mock_mintShares(
            address(lender),
            sharesAmount
        );

        uint256 poolTotalEstimatedValue = lenderCommitmentGroupSmart.getPoolTotalEstimatedValue();
        assertEq(poolTotalEstimatedValue ,  1 * 500000, "unexpected poolTotalEstimatedValue");

        uint256 rate = lenderCommitmentGroupSmart.super_sharesExchangeRate();

        assertEq(rate ,  1e36 / 2, "unexpected sharesExchangeRate");

    }





    function test_get_shares_exchange_rate_inverse() public {
        lenderCommitmentGroupSmart.set_mockSharesExchangeRate(1000000);
 

        uint256 rate = lenderCommitmentGroupSmart.super_sharesExchangeRateInverse();
    }


   





/*
    make sure both pos and neg branches get run, and tellerV2 is called at the end 
*/
    function test_liquidateDefaultedLoanWithIncentive() public {
          initialize_group_contract();

        principalToken.transfer(address(liquidator), 1e18);
        uint256 originalBalance = principalToken.balanceOf(address(liquidator));

        uint256 amountOwed = 100;
   
        
        uint256 bidId = 0;
    

       lenderCommitmentGroupSmart.set_mockAmountOwedForBid(amountOwed); 

   

         vm.warp(1000);   //loanDefaultedTimeStamp ?

       lenderCommitmentGroupSmart.set_mockBidAsActiveForGroup(bidId,true); 
      
       vm.prank(address(liquidator));
       principalToken.approve(address(lenderCommitmentGroupSmart), 1e18);

       lenderCommitmentGroupSmart.mock_setMinimumAmountDifferenceToCloseDefaultedLoan(2000);

        int256 tokenAmountDifference = 4000;
        vm.prank(address(liquidator));
        lenderCommitmentGroupSmart.liquidateDefaultedLoanWithIncentive(
           bidId, 
           tokenAmountDifference           
        );

        uint256 updatedBalance = principalToken.balanceOf(address(liquidator));

        int256 expectedDifference = int256(amountOwed) + tokenAmountDifference;

        assertEq(originalBalance - updatedBalance , uint256(expectedDifference), "unexpected tokenDifferenceFromLiquidations");


      //make sure lenderCloseloan is called 
       assertEq( _tellerV2.lenderCloseLoanWasCalled(), true, "lender close loan not called");
    }


    //complete me 
     function test_liquidateDefaultedLoanWithIncentive_negative_direction() public {


        initialize_group_contract();

        principalToken.transfer(address(liquidator), 1e18);
        uint256 originalBalance = principalToken.balanceOf(address(liquidator));

        uint256 amountOwed = 1000;
   
        
        uint256 bidId = 0;
    

       lenderCommitmentGroupSmart.set_mockAmountOwedForBid(amountOwed); 

   
        //time has advanced enough to now have a 50 percent discount s
         vm.warp(1000);   //loanDefaultedTimeStamp ?

       lenderCommitmentGroupSmart.set_mockBidAsActiveForGroup(bidId,true); 
      
       vm.prank(address(liquidator));
       principalToken.approve(address(lenderCommitmentGroupSmart), 1e18);

       lenderCommitmentGroupSmart.mock_setMinimumAmountDifferenceToCloseDefaultedLoan(-500);

        int256 tokenAmountDifference = -500;
        vm.prank(address(liquidator));
        lenderCommitmentGroupSmart.liquidateDefaultedLoanWithIncentive(
           bidId, 
           tokenAmountDifference           
        );

        uint256 updatedBalance = principalToken.balanceOf(address(liquidator));

        require(tokenAmountDifference < 0); //ensure this test is set up properly 

        // we expect it to be amountOwned - abs(tokenAmountDifference ) but we can just test it like this 
        int256 expectedDifference = int256(amountOwed) + ( tokenAmountDifference);

        assertEq(originalBalance - updatedBalance , uint256(expectedDifference), "unexpected tokenDifferenceFromLiquidations");


      //make sure lenderCloseloan is called 
       assertEq( _tellerV2.lenderCloseLoanWasCalled(), true, "lender close loan not called");
     }

/*
  make sure we get expected data based on the vm warp 
*/
    function test_getMinimumAmountDifferenceToCloseDefaultedLoan() public {
       initialize_group_contract();

        uint256 bidId = 0;
        uint256 amountDue = 500;

       _tellerV2.mock_setLoanDefaultTimestamp(block.timestamp);
   
        vm.warp(10000);
        uint256 loanDefaultTimestamp = block.timestamp - 2000; //sim that loan defaulted 2000 seconds ago 

        int256 min_amount = lenderCommitmentGroupSmart.super_getMinimumAmountDifferenceToCloseDefaultedLoan(
             
            amountDue,
            loanDefaultTimestamp
        );

      int256 expectedMinAmount = 4220; //based on loanDefaultTimestamp gap 

       assertEq(min_amount,expectedMinAmount,"min_amount unexpected");

    }


      function test_getMinimumAmountDifferenceToCloseDefaultedLoan_zero_time() public {
       initialize_group_contract();

        uint256 bidId = 0;
        uint256 amountDue = 500;

       _tellerV2.mock_setLoanDefaultTimestamp(block.timestamp);
   
        vm.warp(10000);
        uint256 loanDefaultTimestamp = block.timestamp ; //sim that loan defaulted 2000 seconds ago 


        vm.expectRevert("Loan defaulted timestamp must be in the past");
        int256 min_amount = lenderCommitmentGroupSmart.super_getMinimumAmountDifferenceToCloseDefaultedLoan(
           
            amountDue,
            loanDefaultTimestamp
        );

      
      
    }


      function test_getMinimumAmountDifferenceToCloseDefaultedLoan_full_time() public {
       initialize_group_contract();

        uint256 bidId = 0;
        uint256 amountDue = 500;

       _tellerV2.mock_setLoanDefaultTimestamp(block.timestamp);
   
        vm.warp(100000);
        uint256 loanDefaultTimestamp = block.timestamp - 22000 ; //sim that loan defaulted 2000 seconds ago 

        int256 min_amount = lenderCommitmentGroupSmart.super_getMinimumAmountDifferenceToCloseDefaultedLoan(
           
            amountDue,
            loanDefaultTimestamp
        );

      int256 expectedMinAmount = 3220; //based on loanDefaultTimestamp gap 

       assertEq(min_amount,expectedMinAmount,"min_amount unexpected");

    }



    function test_getMinInterestRate() public {
        lenderCommitmentGroupSmart.set_mock_getMaxPrincipalPerCollateralAmount(
            100 * 1e18
        );

        principalToken.transfer(address(lenderCommitmentGroupSmart), 1e18);
        collateralToken.transfer(address(lenderCommitmentGroupSmart), 1e18);

        initialize_group_contract();

        lenderCommitmentGroupSmart.set_totalPrincipalTokensCommitted(1000000);

        uint256 principalAmount = 50;
        uint256 collateralAmount = 50 * 100;

        address collateralTokenAddress = address(
            lenderCommitmentGroupSmart.collateralToken()
        );
        uint256 collateralTokenId = 0;

        uint32 loanDuration = 5000000;
        uint16 interestRate = 800;

        uint256 bidId = 0;

 
      uint16 poolUtilizationRatio = lenderCommitmentGroupSmart.getPoolUtilizationRatio( 
           
         );


        assertEq(poolUtilizationRatio, 0);

        // submit bid 
        uint16 minInterestRate = lenderCommitmentGroupSmart.getMinInterestRate( 
           
         );



        assertEq(minInterestRate, 0);
    }




    function test_acceptFundsForAcceptBid() public {
        lenderCommitmentGroupSmart.set_mock_getMaxPrincipalPerCollateralAmount(
            100 * 1e18
        );

        principalToken.transfer(address(lenderCommitmentGroupSmart), 1e18);
        collateralToken.transfer(address(lenderCommitmentGroupSmart), 1e18);

        initialize_group_contract();

        lenderCommitmentGroupSmart.set_totalPrincipalTokensCommitted(1000000);

        uint256 principalAmount = 50;
        uint256 collateralAmount = 50 * 100;

        address collateralTokenAddress = address(
            lenderCommitmentGroupSmart.collateralToken()
        );
        uint256 collateralTokenId = 0;

        uint32 loanDuration = 5000000;
        uint16 interestRate = 100;

        uint256 bidId = 0;


       // TellerV2SolMock(_tellerV2).setMarketRegistry(address(marketRegistry));



        // submit bid 
        TellerV2SolMock(_tellerV2).submitBid( 
            address(principalToken),
            0,
            principalAmount,
            loanDuration,
            interestRate,
            "",
            address(this)
         );



        vm.prank(address(_smartCommitmentForwarder));
        lenderCommitmentGroupSmart.acceptFundsForAcceptBid(
            address(borrower),
            bidId,
            principalAmount,
            collateralAmount,
            collateralTokenAddress,
            collateralTokenId,
            loanDuration,
            interestRate
        );
    }

    function test_acceptFundsForAcceptBid_insufficientCollateral() public {
        lenderCommitmentGroupSmart.set_mock_getMaxPrincipalPerCollateralAmount(
            100 * 1e18
        );

        principalToken.transfer(address(lenderCommitmentGroupSmart), 1e18);
        collateralToken.transfer(address(lenderCommitmentGroupSmart), 1e18);




        initialize_group_contract();

        lenderCommitmentGroupSmart.set_totalPrincipalTokensCommitted(1000000);

        uint256 principalAmount = 100;
        uint256 collateralAmount = 0;

        address collateralTokenAddress = address(
            lenderCommitmentGroupSmart.collateralToken()
        );
        uint256 collateralTokenId = 0;

        uint32 loanDuration = 5000000;
        uint16 interestRate = 100;

        uint256 bidId = 0;




        vm.expectRevert("Insufficient Borrower Collateral");
        vm.prank(address(_smartCommitmentForwarder));
        lenderCommitmentGroupSmart.acceptFundsForAcceptBid(
            address(borrower),
            bidId,
            principalAmount,
            collateralAmount,
            collateralTokenAddress,
            collateralTokenId,
            loanDuration,
            interestRate
        );
    }

    /*
      improve tests for this 

      
    */

    function test_getCollateralTokensAmountEquivalentToPrincipalTokens_scenarioA() public {
         
        initialize_group_contract();

        uint256 principalTokenAmountValue = 9000;
        uint256 pairPriceWithTwap = 1 * 2**96;
        uint256 pairPriceImmediate = 2 * 2**96;
        bool principalTokenIsToken0 = false;
 
        
        uint256 amountCollateral = lenderCommitmentGroupSmart
            .super_getCollateralTokensAmountEquivalentToPrincipalTokens(
                principalTokenAmountValue,
                pairPriceWithTwap,
                pairPriceImmediate,
                principalTokenIsToken0                
                );

       
        uint256 expectedAmount = 4500;  

        assertEq(
            amountCollateral,
            expectedAmount,
            "Unexpected getCollateralTokensPricePerPrincipalTokens"
        );
    }

    function test_getCollateralTokensAmountEquivalentToPrincipalTokens_scenarioB() public {
         
        initialize_group_contract();

        uint256 principalTokenAmountValue = 9000;
        uint256 pairPriceWithTwap = 1 * 2**96;
        uint256 pairPriceImmediate = 2 * 2**96;
        bool principalTokenIsToken0 = true;
 
        
        uint256 amountCollateral = lenderCommitmentGroupSmart
            .super_getCollateralTokensAmountEquivalentToPrincipalTokens(
                principalTokenAmountValue,
                pairPriceWithTwap,
                pairPriceImmediate,
                principalTokenIsToken0                
                );

       
        uint256 expectedAmount = 9000;  

        assertEq(
            amountCollateral,
            expectedAmount,
            "Unexpected getCollateralTokensPricePerPrincipalTokens"
        );
    }

     function test_getCollateralTokensAmountEquivalentToPrincipalTokens_scenarioC() public {
         
        initialize_group_contract();

        uint256 principalTokenAmountValue = 9000;
        uint256 pairPriceWithTwap = 1 * 2**96;
        uint256 pairPriceImmediate = 60000 * 2**96;
        bool principalTokenIsToken0 = false;
 
        
        uint256 amountCollateral = lenderCommitmentGroupSmart
            .super_getCollateralTokensAmountEquivalentToPrincipalTokens(
                principalTokenAmountValue,
                pairPriceWithTwap,
                pairPriceImmediate,
                principalTokenIsToken0                
                );

       
        uint256 expectedAmount = 1;  

        assertEq(
            amountCollateral,
            expectedAmount,
            "Unexpected getCollateralTokensPricePerPrincipalTokens"
        );
    }


     /*
     

      test for _getUniswapV3TokenPairPrice
    */
 function test_getPriceFromSqrtX96_scenarioA() public {
         
        initialize_group_contract(); 
 
        uint160 sqrtPriceX96 = 771166083179357884152611;

        uint256 priceX96 = lenderCommitmentGroupSmart
            .super_getPriceFromSqrtX96(
                 sqrtPriceX96               
                );

        uint256 price = priceX96 * 1e18 / 2**96;

        uint256 expectedAmountX96 = 7506133033681329001;
        uint256 expectedAmount = 94740718; 

          assertEq(
            priceX96,
            expectedAmountX96,
            "Unexpected getPriceFromSqrtX96"
        );
        
        assertEq(
            price,
            expectedAmount,
            "Unexpected getPriceFromSqrtX96"
        );
    }
}

contract User {}

contract SmartCommitmentForwarder {}