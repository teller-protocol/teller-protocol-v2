import { Testable } from "../../../Testable.sol";

 import { LenderCommitmentGroup_Smart_Override } from "./LenderCommitmentGroup_Smart_Override.sol";


import "../../../tokens/TestERC20Token.sol";

//contract LenderCommitmentGroup_Smart_Mock is ExtensionsContextUpgradeable {}



/*
TODO 

Write tests for a borrower . borrowing money from the group 

*/


contract LenderCommitmentGroup_Smart_Test is Testable {
    constructor() {}

    User private extensionContract;

    User private borrower;
    User private lender;


    TestERC20Token principalToken;

    TestERC20Token collateralToken;
    

    LenderCommitmentGroup_Smart_Override lenderCommitmentGroupSmart;

    SmartCommitmentForwarder _smartCommitmentForwarder ;   
    address _uniswapV3Pool = address(0);

    function setUp() public {
        borrower = new User();
        lender = new User();

        _smartCommitmentForwarder = new SmartCommitmentForwarder();

        principalToken = new TestERC20Token("wrappedETH", "WETH", 1e24, 18);

        collateralToken = new TestERC20Token("PEPE", "pepe", 1e24, 18);

        principalToken.transfer(address(lender),1e18);
        collateralToken.transfer(address(borrower),1e18);

      
        lenderCommitmentGroupSmart = new LenderCommitmentGroup_Smart_Override(
            address(_smartCommitmentForwarder),
            address(_uniswapV3Pool)
        );

    
    }


    function initialize_group_contract() public {


        address _principalTokenAddress = address(principalToken);
        address _collateralTokenAddress = address(collateralToken);
        uint256 _marketId = 1;
        uint32 _maxLoanDuration = 5000000;
        uint16 _minInterestRate = 0;
        uint16 _liquidityThresholdPercent = 10000;
        uint16 _loanToValuePercent = 10000;

        address _poolSharesToken = lenderCommitmentGroupSmart.initialize(
            _principalTokenAddress,
            _collateralTokenAddress,
            _marketId,
            _maxLoanDuration,
            _minInterestRate,
            _liquidityThresholdPercent,
            _loanToValuePercent
       );
    }


   function test_initialize() public {

        address _principalTokenAddress = address(principalToken);
        address _collateralTokenAddress = address(collateralToken);
        uint256 _marketId = 1;
        uint32 _maxLoanDuration = 5000000;
        uint16 _minInterestRate = 0;
        uint16 _liquidityThresholdPercent = 10000;
        uint16 _loanToValuePercent = 10000;

       address _poolSharesToken = lenderCommitmentGroupSmart.initialize(
            _principalTokenAddress,
            _collateralTokenAddress,
            _marketId,
            _maxLoanDuration,
            _minInterestRate,
            _liquidityThresholdPercent,
            _loanToValuePercent
       );

       // assertFalse(isTrustedBefore, "Should not be trusted forwarder before");
       // assertTrue(isTrustedAfter, "Should be trusted forwarder after");
    } 


    

//  https://github.com/teller-protocol/teller-protocol-v1/blob/develop/contracts/lending/ttoken/TToken_V3.sol
    function test_addPrincipalToCommitmentGroup() public {
        
        principalToken.transfer(address(lenderCommitmentGroupSmart),1e18);
        collateralToken.transfer(address(lenderCommitmentGroupSmart),1e18);


        initialize_group_contract();


        vm.prank(address(lender));
        principalToken.approve(address(lenderCommitmentGroupSmart),1000000);

        vm.prank(address(lender));
        uint256 sharesAmount_ = lenderCommitmentGroupSmart.addPrincipalToCommitmentGroup(
            1000000,
            address(borrower)
        );


        uint256 expectedSharesAmount = 1000000;


        //use ttoken logic to make this better 
        assertEq( 
            sharesAmount_,
            expectedSharesAmount,
            "Received an unexpected amount of shares"

        );

    
    }

    function test_addPrincipalToCommitmentGroup_after_interest_payments() public {
    

        principalToken.transfer(address(lenderCommitmentGroupSmart),1e18);
        collateralToken.transfer(address(lenderCommitmentGroupSmart),1e18);


        initialize_group_contract();

        lenderCommitmentGroupSmart.set_totalPrincipalTokensCommitted(1000000);
        lenderCommitmentGroupSmart.set_totalInterestCollected(2000000);


        vm.prank(address(lender));
        principalToken.approve(address(lenderCommitmentGroupSmart),1000000);

        vm.prank(address(lender));
        uint256 sharesAmount_ = lenderCommitmentGroupSmart.addPrincipalToCommitmentGroup(
            1000000,
            address(borrower)
        );

           
        uint256 expectedSharesAmount = 500000;


        //use ttoken logic to make this better 
        assertEq( 
            sharesAmount_,
            expectedSharesAmount,
            "Received an unexpected amount of shares"

        );

    
    }


     function test_burnShares_simple() public {
    

        principalToken.transfer(address(lenderCommitmentGroupSmart),1e18);
       // collateralToken.transfer(address(lenderCommitmentGroupSmart),1e18);
 

        initialize_group_contract();

        lenderCommitmentGroupSmart.set_totalPrincipalTokensCommitted(1000000);
        lenderCommitmentGroupSmart.set_totalInterestCollected(0);
        
        lenderCommitmentGroupSmart.set_principalTokensCommittedByLender(address(lender),1000000);


        vm.prank(address(lender));
        principalToken.approve(address(lenderCommitmentGroupSmart),1000000);

        vm.prank(address(lender));

        uint256 sharesAmount = 500000;
            //should have all of the shares at this point 
        lenderCommitmentGroupSmart.mock_mintShares( address(lender),sharesAmount );
         
        
        vm.prank(address(lender));
        (uint256 receivedPrincipalTokens, 
        uint256 receivedCollateralTokens) 
        = lenderCommitmentGroupSmart
        .burnSharesToWithdrawEarnings( 
            sharesAmount, 
            address(lender) );


        uint256 expectedReceivedPrincipalTokens = 1000000; // the orig amt ! 
       assertEq( 
            receivedPrincipalTokens,
            expectedReceivedPrincipalTokens,
            "Received an unexpected amount of principaltokens"

        );

    
    }

     function test_burnShares_also_get_collateral() public {
    

        principalToken.transfer(address(lenderCommitmentGroupSmart),1e18);
        collateralToken.transfer(address(lenderCommitmentGroupSmart),1e18);
 

        initialize_group_contract();

        lenderCommitmentGroupSmart.set_totalPrincipalTokensCommitted(1000000);
        lenderCommitmentGroupSmart.set_totalInterestCollected(0);
        
        lenderCommitmentGroupSmart.set_principalTokensCommittedByLender(address(lender),1000000);


        vm.prank(address(lender));
        principalToken.approve(address(lenderCommitmentGroupSmart),1000000);

        vm.prank(address(lender));

        uint256 sharesAmount = 500000;
            //should have all of the shares at this point 
        lenderCommitmentGroupSmart.mock_mintShares( address(lender),sharesAmount );
         
        
        vm.prank(address(lender));
        (uint256 receivedPrincipalTokens, 
        uint256 receivedCollateralTokens) 
        = lenderCommitmentGroupSmart
        .burnSharesToWithdrawEarnings( 
            sharesAmount, 
            address(lender) );


        uint256 expectedReceivedPrincipalTokens = 500000; // the orig amt ! 
       assertEq( 
            receivedPrincipalTokens,
            expectedReceivedPrincipalTokens,
            "Received an unexpected amount of principal tokens"

        );

          uint256 expectedReceivedCollateralTokens = 500000; // the orig amt ! 
       assertEq( 
            receivedCollateralTokens,
            expectedReceivedCollateralTokens,
            "Received an unexpected amount of collateral tokens"

        );

    
    }


      function test_burnShares_after_interest_payments() public {
    

        principalToken.transfer(address(lenderCommitmentGroupSmart),1e18);
      //  collateralToken.transfer(address(lenderCommitmentGroupSmart),1e18);
 

        initialize_group_contract();

     //   lenderCommitmentGroupSmart.set_totalPrincipalTokensCommitted(1000000);
        lenderCommitmentGroupSmart.set_totalInterestCollected(1000000);
        
        lenderCommitmentGroupSmart.set_principalTokensCommittedByLender(address(lender),5000000);


        vm.prank(address(lender));
        principalToken.approve(address(lenderCommitmentGroupSmart),1000000);


        uint256 sharesAmount = 500000;


        lenderCommitmentGroupSmart.mock_mintShares( address(lender),sharesAmount );
          
        
        vm.prank(address(lender));
        (uint256 receivedPrincipalTokens, 
        uint256 receivedCollateralTokens) 
        = lenderCommitmentGroupSmart
        .burnSharesToWithdrawEarnings( 
            sharesAmount, 
            address(lender) );


        uint256 expectedReceivedPrincipalTokens = 1000000; // the orig amt ! 
       assertEq( 
            receivedPrincipalTokens,
            expectedReceivedPrincipalTokens,
            "Received an unexpected amount of principaltokens"

        );

    
    }


    function test_acceptFundsForAcceptBid() public {


        principalToken.transfer(address(lenderCommitmentGroupSmart),1e18);
        collateralToken.transfer(address(lenderCommitmentGroupSmart),1e18);
 
 

        initialize_group_contract();

        lenderCommitmentGroupSmart.set_totalPrincipalTokensCommitted(1000000);
        


        uint256 principalAmount = 50;
        uint256 collateralAmount = 0;

        address collateralTokenAddress = address(lenderCommitmentGroupSmart.collateralToken()); 
        uint256 collateralTokenId = 0;

        uint32 loanDuration = 5000000;
        uint16 interestRate = 100;

        vm.prank(address(_smartCommitmentForwarder));
        lenderCommitmentGroupSmart.acceptFundsForAcceptBid( 
            address(borrower),
            principalAmount,
            collateralAmount,
            collateralTokenAddress,
            collateralTokenId,
            loanDuration,
            interestRate            
        );


          
    
    }
}

contract User {}
contract SmartCommitmentForwarder {}