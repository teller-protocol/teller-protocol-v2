import { Testable } from "../Testable.sol";

import { CommitmentRolloverLoan } from "../../contracts/LenderCommitmentForwarder/extensions/CommitmentRolloverLoan.sol";

import "../../contracts/interfaces/ICommitmentRolloverLoan.sol";
import "../../contracts/interfaces/ILenderCommitmentForwarder.sol";

import "../integration/IntegrationTestHelpers.sol";

import { WethMock } from "../../contracts/mock/WethMock.sol";

import { TellerV2SolMock } from "../../contracts/mock/TellerV2SolMock.sol";
import { LenderCommitmentForwarderMock } from "../../contracts/mock/LenderCommitmentForwarderMock.sol";
import { MarketRegistryMock } from "../../contracts/mock/MarketRegistryMock.sol";

contract CommitmentRolloverLoanMock is CommitmentRolloverLoan {
    constructor(address _tellerV2, address _lenderCommitmentForwarder)
        CommitmentRolloverLoan(_tellerV2, _lenderCommitmentForwarder)
    {}

    function acceptCommitment(AcceptCommitmentArgs calldata _commitmentArgs)
        public
        returns (uint256 bidId_)
    {
        bidId_ = super._acceptCommitment(_commitmentArgs);
    }
}

contract CommitmentRolloverLoan_Unit_Test is Testable {
    constructor() {}

    User private borrower;
    User private lender;

    CommitmentRolloverLoanMock commitmentRolloverLoan;
    TellerV2SolMock tellerV2;
    WethMock wethMock;
    LenderCommitmentForwarderMock lenderCommitmentForwarder;
    MarketRegistryMock marketRegistryMock;

    function setUp() public {
        borrower = new User();
        lender = new User();

        tellerV2 = new TellerV2SolMock();
        wethMock = new WethMock();

        marketRegistryMock = new MarketRegistryMock();

        tellerV2.setMarketRegistry(address(marketRegistryMock));

        lenderCommitmentForwarder = new LenderCommitmentForwarderMock();

        wethMock.deposit{ value: 100e18 }();
        wethMock.transfer(address(lender), 5e18);
        wethMock.transfer(address(borrower), 5e18);
        wethMock.transfer(address(lenderCommitmentForwarder), 5e18);

        //marketRegistryMock = new MarketRegistryMock();

        commitmentRolloverLoan = new CommitmentRolloverLoanMock(
            address(tellerV2),
            address(lenderCommitmentForwarder)
        );

        IntegrationTestHelpers.deployIntegrationSuite();
    }

    function test_rolloverLoan() public {
        address lendingToken = address(wethMock);
        uint256 marketId = 0;
        uint256 principalAmount = 500;
        uint32 duration = 10 days;
        uint16 interestRate = 100;

        ILenderCommitmentForwarder.Commitment
            memory commitment = ILenderCommitmentForwarder.Commitment({
                maxPrincipal: principalAmount,
                expiration: uint32(block.timestamp + 1 days),
                maxDuration: duration,
                minInterestRate: interestRate,
                collateralTokenAddress: address(0),
                collateralTokenId: 0,
                maxPrincipalPerCollateralAmount: 0,
                collateralTokenType: ILenderCommitmentForwarder
                    .CommitmentCollateralType
                    .NONE,
                lender: address(lender),
                marketId: marketId,
                principalTokenAddress: lendingToken
            });

        lenderCommitmentForwarder.setCommitment(0, commitment);

        ICommitmentRolloverLoan.AcceptCommitmentArgs
            memory commitmentArgs = ICommitmentRolloverLoan
                .AcceptCommitmentArgs({
                    commitmentId: 0,
                    principalAmount: principalAmount,
                    collateralAmount: 100,
                    collateralTokenId: 0,
                    collateralTokenAddress: address(0),
                    interestRate: interestRate,
                    loanDuration: duration
                });

        vm.prank(address(borrower));
        uint256 loanId = tellerV2.submitBid(
            lendingToken,
            marketId,
            principalAmount,
            duration,
            interestRate,
            "",
            address(borrower)
        );

        uint256 rolloverAmount = 0;
 
        vm.prank(address(borrower));

        commitmentRolloverLoan.rolloverLoan(
            loanId,
            rolloverAmount,
            commitmentArgs
        );

        bool acceptCommitmentWithRecipientWasCalled = lenderCommitmentForwarder
            .acceptCommitmentWithRecipientWasCalled();
        assertTrue(
            acceptCommitmentWithRecipientWasCalled,
            "acceptCommitmentWithRecipient not called"
        );
    }



     function test_rolloverLoan_invalid_caller() public {
        address lendingToken = address(wethMock);
        uint256 marketId = 0;
        uint256 principalAmount = 500;
        uint32 duration = 10 days;
        uint16 interestRate = 100;

        ILenderCommitmentForwarder.Commitment
            memory commitment = ILenderCommitmentForwarder.Commitment({
                maxPrincipal: principalAmount,
                expiration: uint32(block.timestamp + 1 days),
                maxDuration: duration,
                minInterestRate: interestRate,
                collateralTokenAddress: address(0),
                collateralTokenId: 0,
                maxPrincipalPerCollateralAmount: 0,
                collateralTokenType: ILenderCommitmentForwarder
                    .CommitmentCollateralType
                    .NONE,
                lender: address(lender),
                marketId: marketId,
                principalTokenAddress: lendingToken
            });

        lenderCommitmentForwarder.setCommitment(0, commitment);

        ICommitmentRolloverLoan.AcceptCommitmentArgs
            memory commitmentArgs = ICommitmentRolloverLoan
                .AcceptCommitmentArgs({
                    commitmentId: 0,
                    principalAmount: principalAmount,
                    collateralAmount: 100,
                    collateralTokenId: 0,
                    collateralTokenAddress: address(0),
                    interestRate: interestRate,
                    loanDuration: duration
                });

        vm.prank(address(borrower));
        uint256 loanId = tellerV2.submitBid(
            lendingToken,
            marketId,
            principalAmount,
            duration,
            interestRate,
            "",
            address(borrower)
        );

        uint256 rolloverAmount = 0;
 
        vm.prank(address(lender));

        vm.expectRevert("CommitmentRolloverLoan: not borrower");

        commitmentRolloverLoan.rolloverLoan(
            loanId,
            rolloverAmount,
            commitmentArgs
        );
     }
 
  function test_calculate_rollover_amount() public {


        address lendingToken = address(wethMock);
        uint256 marketId = 0;
        uint256 principalAmount = 500;
        uint32 duration = 10 days;
        uint16 interestRate = 100;

        ILenderCommitmentForwarder.Commitment
            memory commitment = ILenderCommitmentForwarder.Commitment({
                maxPrincipal: principalAmount,
                expiration: uint32(block.timestamp + 1 days),
                maxDuration: duration,
                minInterestRate: interestRate,
                collateralTokenAddress: address(0),
                collateralTokenId: 0,
                maxPrincipalPerCollateralAmount: 0,
                collateralTokenType: ILenderCommitmentForwarder
                    .CommitmentCollateralType
                    .NONE,
                lender: address(lender),
                marketId: marketId,
                principalTokenAddress: lendingToken
            });

        lenderCommitmentForwarder.setCommitment(0, commitment);

        ICommitmentRolloverLoan.AcceptCommitmentArgs
            memory commitmentArgs = ICommitmentRolloverLoan
                .AcceptCommitmentArgs({
                    commitmentId: 0,
                    principalAmount: principalAmount,
                    collateralAmount: 100,
                    collateralTokenId: 0,
                    collateralTokenAddress: address(0),
                    interestRate: interestRate,
                    loanDuration: duration
                });

        vm.prank(address(borrower));
        uint256 loanId = tellerV2.submitBid(
            lendingToken,
            marketId,
            principalAmount,
            duration,
            interestRate,
            "",
            address(borrower)
        );

        
        vm.prank(address(lender)); 
        int256 rolloverAmount=  commitmentRolloverLoan.calculateRolloverAmount(
            loanId, 
            commitmentArgs,
            block.timestamp
        );

        assertEq(rolloverAmount, -445 , "invalid rolloveramount");

  }
}

contract User {}
