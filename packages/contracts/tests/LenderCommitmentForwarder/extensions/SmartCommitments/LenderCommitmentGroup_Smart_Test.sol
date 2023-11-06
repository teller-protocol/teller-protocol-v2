import { Testable } from "../../../Testable.sol";

 import { LenderCommitmentGroup_Smart_Override } from "./LenderCommitmentGroup_Smart_Override.sol";

//contract LenderCommitmentGroup_Smart_Mock is ExtensionsContextUpgradeable {}

contract LenderCommitmentGroup_Smart_Test is Testable {
    constructor() {}

    User private extensionContract;

    User private borrower;
    User private lender;

    LenderCommitmentGroup_Smart_Override lenderCommitmentGroupSmart;

    address _smartCommitmentForwarder = address(0);   
    address _uniswapV3Pool = address(0);

    function setUp() public {
        borrower = new User();
        lender = new User();



        lenderCommitmentGroupSmart = new LenderCommitmentGroup_Smart_Override(
            _smartCommitmentForwarder,
            _uniswapV3Pool
        );
    }

   function test_initialize() public {

        address _principalTokenAddress = address(0);
        address _collateralTokenAddress = address(0);
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
}

contract User {}
