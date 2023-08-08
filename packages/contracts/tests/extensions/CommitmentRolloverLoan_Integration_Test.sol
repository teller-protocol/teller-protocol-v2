import { Testable } from "../Testable.sol";

import { CommitmentRolloverLoan } from "../../contracts/LenderCommitmentForwarder/extensions/CommitmentRolloverLoan.sol";

import "../../contracts/interfaces/ICommitmentRolloverLoan.sol";
import "../../contracts/interfaces/ILenderCommitmentForwarder.sol";
import "../../contracts/interfaces/ITellerV2Context.sol";

import "../integration/IntegrationTestHelpers.sol";

import { WethMock } from "../../contracts/mock/WethMock.sol";

import { TellerV2SolMock } from "../../contracts/mock/TellerV2SolMock.sol";
import { LenderCommitmentForwarderMock } from "../../contracts/mock/LenderCommitmentForwarderMock.sol";
import { MarketRegistryMock } from "../../contracts/mock/MarketRegistryMock.sol";

import { PaymentType,PaymentCycleType } from "../../contracts/libraries/V2Calculations.sol";

import "lib/forge-std/src/console.sol";

/*
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
}*/

contract CommitmentRolloverLoan_Integration_Test is Testable {
    constructor() {}

    User private borrower;
    User private lender;
    User private marketOwner;

    CommitmentRolloverLoan commitmentRolloverLoan;
    TellerV2 tellerV2;
    WethMock wethMock;
    ILenderCommitmentForwarder lenderCommitmentForwarder;
    IMarketRegistry marketRegistry;

    function setUp() public {
        borrower = new User();
        lender = new User();
        marketOwner = new User();

        tellerV2 = IntegrationTestHelpers.deployIntegrationSuite();

        marketRegistry = IMarketRegistry(tellerV2.marketRegistry());

        lenderCommitmentForwarder = ILenderCommitmentForwarder(tellerV2.lenderCommitmentForwarder());
        wethMock = new WethMock();

        uint32 _paymentCycleDuration = uint32( 1 days );
        uint32 _paymentDefaultDuration = uint32( 5 days );
        uint32 _bidExpirationTime = uint32(7 days);
        uint16 _feePercent = 100;
        PaymentType _paymentType = PaymentType.EMI;
        PaymentCycleType _paymentCycleType = PaymentCycleType.Seconds;

        vm.prank(address(marketOwner));
        uint256 marketId = marketRegistry.createMarket(

            address(marketOwner),
            _paymentCycleDuration,
            _paymentDefaultDuration,
            _bidExpirationTime,
            _feePercent,
            false,
            false,
            _paymentType,
            _paymentCycleType,
            "uri"
        );

        console.logUint(marketId);
        //tellerV2.setMarketRegistry(address(marketRegistryMock));

        //lenderCommitmentForwarder = new LenderCommitmentForwarderMock();

        wethMock.deposit{ value: 100e18 }();
        wethMock.transfer(address(lender), 5e18);
        wethMock.transfer(address(borrower), 5e18);
        //wethMock.transfer(address(lenderCommitmentForwarder), 5e18);

        //marketRegistryMock = new MarketRegistryMock();

        commitmentRolloverLoan = new CommitmentRolloverLoan(
            address(tellerV2),
            address(lenderCommitmentForwarder)
        );
 
    } 


    /*
    scenario A - user needs to pay 0.1weth + 1 weth to the lender. they will get 0.5weth - 0.05 weth = 0.45 weth from the rollover to paybackthe user.  rest 0.65 needs to be paid back by the borrower.abi
    Scenario B - user needs to pay 0.1weth + 1 weth back to the lender. They will get 1.2weth - 0.12weth = 1.08 weth from the rollover to pay back the user so 0.02 needs to be paid back to the borrower.abi
    Scenario C - user needs to pay 0.1 weth + 1 weth back to the lender.  They will get 2 weth - 0.2 weth = 1.8weth so 0.6 weth is given to the borrower .  

    assume that 10 pct fee is taken by pool plus protocol for simplicity. 



  */

    function test_rolloverLoan_financial_scenario_A() public {
        address lendingToken = address(wethMock);

        //initial loan - need to pay back 1 weth + 0.1 weth (interest) to the lender
        uint256 marketId = 1;
        uint256 principalAmount = 1e18;
        uint32 duration = 365 days;
        uint16 interestRate = 100;

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
        wethMock.approve(address(tellerV2), 1e18);

        vm.prank(address(lender));
        (
            uint256 amountToProtocol,
            uint256 amountToMarketplace,
            uint256 amountToBorrower
        ) = tellerV2.lenderAcceptBid(loanId);

        vm.warp(365 days);

        uint256 commitmentPrincipalAmount = 2 * 1e18; //2 weth

        ILenderCommitmentForwarder.Commitment
            memory commitment = ILenderCommitmentForwarder.Commitment({
                maxPrincipal: commitmentPrincipalAmount,
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

     
         address[] memory _borrowerAddressList;

         vm.prank(address(lender));
        uint256 commitmentId = lenderCommitmentForwarder.createCommitment(commitment, _borrowerAddressList);


        //should get 0.5 weth (0.45 after fees) from accepting this commitment  during the rollover process
      
        ICommitmentRolloverLoan.AcceptCommitmentArgs
            memory commitmentArgs = ICommitmentRolloverLoan
                .AcceptCommitmentArgs({
                    commitmentId: commitmentId,
                    principalAmount: commitmentPrincipalAmount,
                    collateralAmount: 0,
                    collateralTokenId: 0,
                    collateralTokenAddress: address(0),
                    interestRate: interestRate,
                    loanDuration: duration
                });

        uint256 rolloverAmount = 65 * 1e16; //0.65 weth

        uint256 borrowerBalanceBeforeRollover = wethMock.balanceOf(
            address(borrower)
        );

        vm.prank(address(borrower));
        wethMock.approve(address(commitmentRolloverLoan), rolloverAmount);

        vm.prank(address(borrower));

        // need to pay 0.65 weth as the borrower !
        uint256 _newLoanId = commitmentRolloverLoan.rolloverLoan(
            loanId,
            rolloverAmount,
            commitmentArgs
        );

        uint256 borrowerBalanceAfterRollover = wethMock.balanceOf(
            address(borrower)
        );

        assertEq(
            borrowerBalanceAfterRollover - borrowerBalanceBeforeRollover,
            65 * 1e16,
            "incorrect balance after rollover"
        );
    }

    function test_rolloverLoan_financial_scenario_C() public {
        address lendingToken = address(wethMock);

        //initial loan - need to pay back 1 weth + 0.1 weth (interest) to the lender
        uint256 marketId = 1;
        uint256 principalAmount = 1e18;
        uint32 duration = 365 days;
        uint16 interestRate = 100;

        wethMock.transfer(address(commitmentRolloverLoan), 100);

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
        wethMock.approve(address(tellerV2), 1e18);

        vm.prank(address(lender));
        (
            uint256 amountToProtocol,
            uint256 amountToMarketplace,
            uint256 amountToBorrower
        ) = tellerV2.lenderAcceptBid(loanId);

        vm.warp(365 days);

         uint256 commitmentPrincipalAmount = 2 * 1e18; //2 weth

        ILenderCommitmentForwarder.Commitment
            memory commitment = ILenderCommitmentForwarder.Commitment({
                maxPrincipal: commitmentPrincipalAmount,
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
        
        address[] memory _borrowerAddressList;

         vm.prank(address(lender));
        uint256 commitmentId = lenderCommitmentForwarder.createCommitment(commitment, _borrowerAddressList);

        //should get 2.0 weth   from accepting this commitment  during the rollover process
       
        ICommitmentRolloverLoan.AcceptCommitmentArgs
            memory commitmentArgs = ICommitmentRolloverLoan
                .AcceptCommitmentArgs({
                    commitmentId: commitmentId,
                    principalAmount: commitmentPrincipalAmount,
                    collateralAmount: 0,
                    collateralTokenId: 0,
                    collateralTokenAddress: address(0),
                    interestRate: interestRate,
                    loanDuration: duration
                });

     

        {
      
        vm.prank(address(marketOwner));
         ITellerV2Context(address(tellerV2)).setTrustedMarketForwarder(marketId, address(commitmentRolloverLoan));
       // vm.prank(address(marketOwner));
        // ITellerV2Context(address(tellerV2)).setTrustedMarketForwarder(marketId, address(lenderCommitmentForwarder));


        //borrower approves the commitmentrolloverloan as a sender for market 1 
         vm.prank(address(borrower));
        ITellerV2Context(address(tellerV2)).approveMarketForwarder(marketId, address(commitmentRolloverLoan));
          vm.prank(address(borrower));
        ITellerV2Context(address(tellerV2)).approveMarketForwarder(marketId, address(lenderCommitmentForwarder));
        }

        uint256 rolloverAmount = 0;
        vm.prank(address(borrower));
        wethMock.approve(address(commitmentRolloverLoan), rolloverAmount);


        uint256 borrowerBalanceBeforeRollover = wethMock.balanceOf(
            address(borrower)
        );

        vm.prank(address(borrower));
        // need to pay 0.65 weth as the borrower !
        uint256 _newLoanId = commitmentRolloverLoan.rolloverLoan(
            loanId,
            rolloverAmount,
            commitmentArgs
        );

        //neeed the roolover to really move tokens around !
        uint256 borrowerBalanceAfterRollover = wethMock.balanceOf(
            address(borrower)
        );

        assertEq(
            borrowerBalanceAfterRollover - borrowerBalanceBeforeRollover,
            60 * 1e16,
            "incorrect balance after rollover"
        );
    }
}

contract User {}
