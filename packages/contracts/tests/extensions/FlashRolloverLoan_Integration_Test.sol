import { Testable } from "../Testable.sol";

import { FlashLoanVault } from "../../contracts/FlashLoanVault.sol";
import { FlashRolloverLoan } from "../../contracts/FlashRolloverLoan.sol";

import "../../contracts/interfaces/ICommitmentRolloverLoan.sol";
import "../../contracts/interfaces/ILenderCommitmentForwarder.sol";
import "../../contracts/interfaces/ITellerV2Context.sol";

import "../integration/IntegrationTestHelpers.sol";

import "../../contracts/extensions/ExtensionsContextUpgradeable.sol";

import { WethMock } from "../../contracts/mock/WethMock.sol";

import { TellerV2SolMock } from "../../contracts/mock/TellerV2SolMock.sol";
import { LenderCommitmentForwarderMock } from "../../contracts/mock/LenderCommitmentForwarderMock.sol";
import { MarketRegistryMock } from "../../contracts/mock/MarketRegistryMock.sol";

import { LenderCommitmentForwarder } from "../../contracts/LenderCommitmentForwarder.sol";

import { LenderCommitmentForwarder_V2 } from "../../contracts/LenderCommitmentForwarder_V2.sol";


import { PaymentType, PaymentCycleType } from "../../contracts/libraries/V2Calculations.sol";

import "lib/forge-std/src/console.sol";
 
contract FlashRolloverLoan_Integration_Test is Testable {
    constructor() {}

    User private borrower;
    User private lender;
    User private marketOwner;

    FlashLoanVault flashLoanVault;
    FlashRolloverLoan flashRolloverLoan;
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

        lenderCommitmentForwarder = ILenderCommitmentForwarder(
            tellerV2.lenderCommitmentForwarder()
        );

        wethMock = new WethMock();

        uint32 _paymentCycleDuration = uint32(1 days);
        uint32 _paymentDefaultDuration = uint32(5 days);
        uint32 _bidExpirationTime = uint32(7 days);
        uint16 _feePercent = 900;
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

        

        wethMock.deposit{ value: 100e18 }();
        wethMock.transfer(address(lender), 5e18);
        wethMock.transfer(address(borrower), 5e18);
        
        flashLoanVault = new FlashLoanVault();

        flashRolloverLoan = new FlashRolloverLoan(
            address(tellerV2),
            address(lenderCommitmentForwarder),
            address(flashLoanVault)
        );


        LenderCommitmentForwarder_V2(
            address(lenderCommitmentForwarder)
        ).initialize(address(this));

      
        LenderCommitmentForwarder_V2(
            address(lenderCommitmentForwarder)
        ).addExtension(address(flashRolloverLoan));
    }

    function test_flashRollover() public {
        address lendingToken = address(wethMock);

        //initial loan - need to pay back 1 weth + 0.1 weth (interest) to the lender
        uint256 marketId = 1;
        uint256 principalAmount = 1e18;
        uint32 duration = 365 days;
        uint16 interestRate = 1000;

        //wethMock.transfer(address(flashRolloverLoan), 100);

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

        vm.warp(365 days + 1);

        uint256 commitmentPrincipalAmount = 50 * 1e16; //0.50 weth

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
        uint256 commitmentId = lenderCommitmentForwarder.createCommitment(
            commitment,
            _borrowerAddressList
        );

        //should get 0.45  weth   from accepting this commitment  during the rollover process

        ICommitmentRolloverLoan.AcceptCommitmentArgs
            memory _acceptCommitmentArgs = ICommitmentRolloverLoan
                .AcceptCommitmentArgs({
                    commitmentId: commitmentId,
                    principalAmount: commitmentPrincipalAmount,
                    collateralAmount: 0,
                    collateralTokenId: 0,
                    collateralTokenAddress: address(0),
                    interestRate: interestRate,
                    loanDuration: duration
                });

        uint256 flashLoanAmount = 100;



        flashRolloverLoan.rolloverLoanWithFlash(
            loanId,
            flashLoanAmount,
            _acceptCommitmentArgs
        );

         
    }
 
}

contract User {}
