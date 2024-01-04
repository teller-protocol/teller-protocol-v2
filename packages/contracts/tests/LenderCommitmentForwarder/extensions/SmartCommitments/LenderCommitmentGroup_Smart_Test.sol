import { Testable } from "../../../Testable.sol";

import { LenderCommitmentGroup_Smart_Override } from "./LenderCommitmentGroup_Smart_Override.sol";

import "../../../tokens/TestERC20Token.sol";

import "../../../../contracts/mock/TellerV2SolMock.sol";

//contract LenderCommitmentGroup_Smart_Mock is ExtensionsContextUpgradeable {}

/*
TODO 

Write tests for a borrower . borrowing money from the group 



- write tests for the LTV ratio and make sure that is working as expected (mock) 
- write tests for the global liquidityThresholdPercent and built functionality for a user-specific liquidityThresholdPercent based on signalling shares.

*/

contract LenderCommitmentGroup_Smart_Test is Testable {
    constructor() {}

    User private extensionContract;

    User private borrower;
    User private lender;

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

        _tellerV2 = new TellerV2SolMock();
        _smartCommitmentForwarder = new SmartCommitmentForwarder();
        _uniswapV3Pool = new UniswapV3PoolMock();

        _uniswapV3Factory = new UniswapV3FactoryMock();
        _uniswapV3Factory.setPoolMock(address(_uniswapV3Pool));
 

        principalToken = new TestERC20Token("wrappedETH", "WETH", 1e24, 18);

        collateralToken = new TestERC20Token("PEPE", "pepe", 1e24, 18);

        principalToken.transfer(address(lender), 1e18);
        collateralToken.transfer(address(borrower), 1e18);

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
        uint16 _liquidityThresholdPercent = 10000;
        uint16 _loanToValuePercent = 10000;
        uint24 _uniswapPoolFee = 3000;

        address _poolSharesToken = lenderCommitmentGroupSmart.initialize(
            _principalTokenAddress,
            _collateralTokenAddress,
            _marketId,
            _maxLoanDuration,
            _minInterestRate,
            _liquidityThresholdPercent,
            _loanToValuePercent,
            _uniswapPoolFee
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
        uint24 _uniswapPoolFee = 3000;

        address _poolSharesToken = lenderCommitmentGroupSmart.initialize(
            _principalTokenAddress,
            _collateralTokenAddress,
            _marketId,
            _maxLoanDuration,
            _minInterestRate,
            _liquidityThresholdPercent,
            _loanToValuePercent,
            _uniswapPoolFee
        );

        // assertFalse(isTrustedBefore, "Should not be trusted forwarder before");
        // assertTrue(isTrustedAfter, "Should be trusted forwarder after");
    }

    //  https://github.com/teller-protocol/teller-protocol-v1/blob/develop/contracts/lending/ttoken/TToken_V3.sol
    function test_addPrincipalToCommitmentGroup() public {
        principalToken.transfer(address(lenderCommitmentGroupSmart), 1e18);
        collateralToken.transfer(address(lenderCommitmentGroupSmart), 1e18);

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

        initialize_group_contract();

        lenderCommitmentGroupSmart.set_totalPrincipalTokensCommitted(1000000);
        lenderCommitmentGroupSmart.set_totalInterestCollected(2000000);

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

    function test_burnShares_simple() public {
        principalToken.transfer(address(lenderCommitmentGroupSmart), 1e18);
        // collateralToken.transfer(address(lenderCommitmentGroupSmart),1e18);

        initialize_group_contract();

        lenderCommitmentGroupSmart.set_totalPrincipalTokensCommitted(1000000);
        lenderCommitmentGroupSmart.set_totalInterestCollected(0);

        lenderCommitmentGroupSmart.set_principalTokensCommittedByLender(
            address(lender),
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
        (
            uint256 receivedPrincipalTokens,
            uint256 receivedCollateralTokens
        ) = lenderCommitmentGroupSmart.burnSharesToWithdrawEarnings(
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

        lenderCommitmentGroupSmart.set_totalPrincipalTokensCommitted(1000000);
        lenderCommitmentGroupSmart.set_totalInterestCollected(0);

        lenderCommitmentGroupSmart.set_principalTokensCommittedByLender(
            address(lender),
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
        (
            uint256 receivedPrincipalTokens,
            uint256 receivedCollateralTokens
        ) = lenderCommitmentGroupSmart.burnSharesToWithdrawEarnings(
                sharesAmount,
                address(lender)
            );

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
        principalToken.transfer(address(lenderCommitmentGroupSmart), 1e18);
        //  collateralToken.transfer(address(lenderCommitmentGroupSmart),1e18);

        initialize_group_contract();

        //   lenderCommitmentGroupSmart.set_totalPrincipalTokensCommitted(1000000);
        lenderCommitmentGroupSmart.set_totalInterestCollected(1000000);

        lenderCommitmentGroupSmart.set_principalTokensCommittedByLender(
            address(lender),
            5000000
        );

        vm.prank(address(lender));
        principalToken.approve(address(lenderCommitmentGroupSmart), 1000000);

        uint256 sharesAmount = 500000;

        lenderCommitmentGroupSmart.mock_mintShares(
            address(lender),
            sharesAmount
        );

        vm.prank(address(lender));
        (
            uint256 receivedPrincipalTokens,
            uint256 receivedCollateralTokens
        ) = lenderCommitmentGroupSmart.burnSharesToWithdrawEarnings(
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
       function test_getMaxPrincipalPerCollateralAmount() public {

          uint256 maxPrincipalPerCollateralAmount =  lenderCommitmentGroupSmart._super_getMaxPrincipalPerCollateralAmount( );

          uint256 expectedMaxPrincipalPerCollateralAmount = 999;
        
          assertEq( maxPrincipalPerCollateralAmount, expectedMaxPrincipalPerCollateralAmount , "Unexpected maxPrincipalPerCollateralAmount" );
     
     
       }
    */

    function test_getCollateralTokensPricePerPrincipalTokens() public {
         
        initialize_group_contract();
        
        
        uint256 amount = lenderCommitmentGroupSmart
            .getCollateralTokensPricePerPrincipalTokens(1e14);

        uint256 expectedAmount = 1e14;

        assertEq(
            amount,
            expectedAmount,
            "Unexpected getCollateralTokensPricePerPrincipalTokens"
        );
    }
}

contract User {}

contract SmartCommitmentForwarder {}

contract UniswapV3PoolMock {
    //this represents an equal price ratio
    uint160 mockSqrtPriceX96 = 2 ** 96;
    

    struct Slot0 {
        // the current price
        uint160 sqrtPriceX96;
        // the current tick
        int24 tick;
        // the most-recently updated index of the observations array
        uint16 observationIndex;
        // the current maximum number of observations that are being stored
        uint16 observationCardinality;
        // the next maximum number of observations to store, triggered in observations.write
        uint16 observationCardinalityNext;
        // the current protocol fee as a percentage of the swap fee taken on withdrawal
        // represented as an integer denominator (1/x)%
        uint8 feeProtocol;
        // whether the pool is locked
        bool unlocked;
    }

    function set_mockSqrtPriceX96(uint160 _price) public {
        mockSqrtPriceX96 = _price;
    }

    function slot0() public returns (Slot0 memory slot0) {
        return
            Slot0({
                sqrtPriceX96: mockSqrtPriceX96,
                tick: 0,
                observationIndex: 0,
                observationCardinality: 0,
                observationCardinalityNext: 0,
                feeProtocol: 0,
                unlocked: true
            });
    }
 
      

}



contract UniswapV3FactoryMock {
    
    address poolMock; 

 
    function getPool(address token0,
                        address token1,
                        uint24 fee 
    ) public returns(address){
        return poolMock;
    }

    function setPoolMock(address _pool) public {

        poolMock = _pool;

    }

      

}
