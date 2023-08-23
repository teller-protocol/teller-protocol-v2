pragma solidity ^0.8.0;

import { Testable } from "../Testable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { FlashRolloverLoan } from "../../contracts/FlashRolloverLoan.sol";

import "../../contracts/interfaces/ICommitmentRolloverLoan.sol";
import "../../contracts/interfaces/ILenderCommitmentForwarder.sol";

import "../integration/IntegrationTestHelpers.sol";

import { WethMock } from "../../contracts/mock/WethMock.sol";

import { TellerV2SolMock } from "../../contracts/mock/TellerV2SolMock.sol";
import { LenderCommitmentForwarderMock } from "../../contracts/mock/LenderCommitmentForwarderMock.sol";
import { MarketRegistryMock } from "../../contracts/mock/MarketRegistryMock.sol";

import {AavePoolAddressProviderMock} from "../../contracts/mock/aave/AavePoolAddressProviderMock.sol";
import {AavePoolMock} from "../../contracts/mock/aave/AavePoolMock.sol";


contract FlashRolloverLoanMock is FlashRolloverLoan {
    constructor(address _tellerV2, address _lenderCommitmentForwarder, address _aaveAddressProvider)
        FlashRolloverLoan(_tellerV2, _lenderCommitmentForwarder,_aaveAddressProvider)
    {}

    function acceptCommitment(address borrower,address principalToken, AcceptCommitmentArgs calldata _commitmentArgs)
        public
        returns (uint256 bidId_, uint256 acceptCommitmentAmount_)
    {
        return super._acceptCommitment(borrower,principalToken,_commitmentArgs);
    }
}

contract FlashRolloverLoan_Unit_Test is Testable {
    constructor() {}

    User private borrower;
    User private lender;

    AavePoolMock aavePoolMock;
    AavePoolAddressProviderMock aavePoolAddressProvider;
    FlashRolloverLoanMock flashRolloverLoan;
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
 


        aavePoolAddressProvider = new AavePoolAddressProviderMock(
            "marketId", address(this)
        );

        aavePoolMock = new AavePoolMock();

        bytes32 POOL = 'POOL';
        aavePoolAddressProvider.setAddress( POOL, address(aavePoolMock) );



        wethMock.deposit{ value: 100e18 }();
        wethMock.transfer(address(lender), 5e18);
        wethMock.transfer(address(borrower), 5e18);
        wethMock.transfer(address(lenderCommitmentForwarder), 5e18);

        wethMock.transfer(address(aavePoolMock), 5e18);


        //marketRegistryMock = new MarketRegistryMock();

        flashRolloverLoan = new FlashRolloverLoanMock(
            address(tellerV2),
            address(lenderCommitmentForwarder),
            address(aavePoolAddressProvider)
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

        uint256 flashAmount = 500;
        uint256 borrowerAmount = 5;  //have to pay the aave fee.. 

        vm.prank(address(borrower));
        IERC20(lendingToken).approve(address(flashRolloverLoan), 1e18);
 
        vm.prank(address(borrower));

        flashRolloverLoan.rolloverLoanWithFlash(
            loanId,
            flashAmount,
            borrowerAmount,
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

        uint256 flashAmount = 0;
        uint256 borrowerAmount = 0;
 
        vm.prank(address(lender));

        vm.expectRevert("CommitmentRolloverLoan: not borrower");

        flashRolloverLoan.rolloverLoanWithFlash(
            loanId,
            flashAmount,
            borrowerAmount,
            commitmentArgs
        );
     }
 
  function test_calculate_rollover_amount_two() public {


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
        (uint256 flashAmount, int256 borrowerAmount) =  flashRolloverLoan.calculateRolloverAmount(
            loanId, 
            commitmentArgs,
            9,
            block.timestamp
        );

   //     assertEq(borrowerAmount, -445 , "invalid rolloveramount");

  }

  function test_calculate_rollover_amount_one() public {
          address lendingToken = address(wethMock);

        //initial loan - need to pay back 1 weth + 0.1 weth (interest) to the lender
        uint256 marketId = 1;
        uint256 principalAmount = 50000;
        uint32 duration = 365 days;
        uint16 interestRate = 1000;

        //wethMock.transfer(address(flashRolloverLoan), 100);

        //this is the old loan 
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


            //why approve so much ? 
        vm.prank(address(lender));
        wethMock.approve(address(tellerV2), 5e18);

        vm.prank(address(lender));
        (
            uint256 amountToProtocol,
            uint256 amountToMarketplace,
            uint256 amountToBorrower
        ) = tellerV2.lenderAcceptBid(loanId);

        vm.warp(365 days + 1);


        uint256 newLoanPrincipalAmount = 50000;

        //this is prepping the new loan 
        ILenderCommitmentForwarder.Commitment
            memory commitment = ILenderCommitmentForwarder.Commitment({
                maxPrincipal: newLoanPrincipalAmount,
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
                    principalAmount: newLoanPrincipalAmount,
                    collateralAmount: 0,
                    collateralTokenId: 0,
                    collateralTokenAddress: address(0),
                    interestRate: interestRate,
                    loanDuration: duration
                });

        
  

        vm.prank(address(borrower));
        IERC20(lendingToken).approve(address(flashRolloverLoan), 1e18);
 

        //making sure the flashloan premium logic works
        (uint256 flashAmount, int256 borrowerAmount) = flashRolloverLoan.calculateRolloverAmount(
            loanId, 
            commitmentArgs,
            9,
            block.timestamp
        );

        assertEq(flashAmount, 55000 , "invalid flashAmount");
        assertEq(borrowerAmount, -10549 , "invalid borrowerAmount");


        ( flashAmount,  borrowerAmount) = flashRolloverLoan.calculateRolloverAmount(
            loanId, 
            commitmentArgs,
            0,
            block.timestamp
        );

        assertEq(flashAmount, 55000 , "invalid flashAmount");
        assertEq(borrowerAmount, -10500 , "invalid borrowerAmount");
 
    }

    
}

contract User {}
