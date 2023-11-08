import { Testable } from "../../../Testable.sol";

 import { LenderCommitmentGroup_Smart_Override } from "./LenderCommitmentGroup_Smart_Override.sol";


import "../../../tokens/TestERC20Token.sol";

//contract LenderCommitmentGroup_Smart_Mock is ExtensionsContextUpgradeable {}

contract LenderCommitmentGroup_Smart_Test is Testable {
    constructor() {}

    User private extensionContract;

    User private borrower;
    User private lender;


    TestERC20Token principalToken;

    TestERC20Token collateralToken;
    

    LenderCommitmentGroup_Smart_Override lenderCommitmentGroupSmart;

    address _smartCommitmentForwarder = address(0);   
    address _uniswapV3Pool = address(0);

    function setUp() public {
        borrower = new User();
        lender = new User();



        principalToken = new TestERC20Token("wrappedETH", "WETH", 1e24, 18);

        collateralToken = new TestERC20Token("PEPE", "pepe", 1e24, 18);

        principalToken.transfer(address(lender),1e18);
        collateralToken.transfer(address(borrower),1e18);

      
        lenderCommitmentGroupSmart = new LenderCommitmentGroup_Smart_Override(
            _smartCommitmentForwarder,
            _uniswapV3Pool
        );

        principalToken.transfer(address(lenderCommitmentGroupSmart),1e20);
        collateralToken.transfer(address(lenderCommitmentGroupSmart),1e20);

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


     function test_burnShares_after_interest_payments() public {
    
        initialize_group_contract();

        lenderCommitmentGroupSmart.set_totalPrincipalTokensCommitted(1000000);
        lenderCommitmentGroupSmart.set_totalInterestCollected(2000000);
        
        lenderCommitmentGroupSmart.set_principalTokensCommittedByLender(address(lender),5000000);


        vm.prank(address(lender));
        principalToken.approve(address(lenderCommitmentGroupSmart),1000000);

        vm.prank(address(lender));
        uint256 sharesAmount_ = lenderCommitmentGroupSmart.addPrincipalToCommitmentGroup(
            1000000,
            address(lender)
        );

           
        uint256 expectedSharesAmount = 500000;


        //actually  mock this ...  like mock mint sharestokens 
        assertEq( 
            sharesAmount_,
            expectedSharesAmount,
            "Received an unexpected amount of shares"

        );

        
        vm.prank(address(lender));
        (uint256 receivedPrincipalTokens, 
        uint256 receivedCollateralTokens) 
        = lenderCommitmentGroupSmart
        .burnSharesToWithdrawEarnings( 
            sharesAmount_, 
            address(lender) );


        uint256 expectedReceivedPrincipalTokens = 1000000; // the orig amt ! 
       assertEq( 
            receivedPrincipalTokens,
            expectedReceivedPrincipalTokens,
            "Received an unexpected amount of principaltokens"

        );

    
    }
}

contract User {}
