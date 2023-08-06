import { Testable } from "../Testable.sol";

import { CommitmentRolloverLoan } from "../../contracts/LenderCommitmentForwarder/extensions/CommitmentRolloverLoan.sol";


import "../../contracts/interfaces/ICommitmentRolloverLoan.sol";


import {WethMock} from "../../contracts/mock/WethMock.sol";

import {TellerV2SolMock} from "../../contracts/mock/TellerV2SolMock.sol";
import {LenderCommitmentForwarderMock} from "../../contracts/mock/LenderCommitmentForwarderMock.sol";
 
contract CommitmentRolloverLoanMock is CommitmentRolloverLoan {
    
     constructor(address _tellerV2, address _lenderCommitmentForwarder) 
     CommitmentRolloverLoan(_tellerV2, _lenderCommitmentForwarder) {
        
    }

    function acceptCommitment(AcceptCommitmentArgs calldata _commitmentArgs) public returns (uint256 bidId_){
        bidId_ = super._acceptCommitment(_commitmentArgs);
    }


}

contract CommitmentRolloverLoan_Test is Testable {
    constructor() {}

    User private borrower;
    User private lender;

    CommitmentRolloverLoanMock commitmentRolloverLoan;
    TellerV2SolMock tellerV2;
    WethMock wethMock;
    LenderCommitmentForwarderMock lenderCommitmentForwarder ;
    //MarketRegistryMock marketRegistryMock;

    function setUp() public {

        borrower = new User();
        lender = new User();

        tellerV2 = new TellerV2SolMock();
        wethMock = new WethMock();

        wethMock.deposit{value:1e18}();
        wethMock.transfer(address(lender),1e10);
        wethMock.transfer(address(borrower),1e10);

        //marketRegistryMock = new MarketRegistryMock();

        lenderCommitmentForwarder = new LenderCommitmentForwarderMock();

        commitmentRolloverLoan = new CommitmentRolloverLoanMock(
            address(tellerV2), address(lenderCommitmentForwarder)
        );


    }
 

    function test_rolloverLoan() public {
 
         address lendingToken = address(wethMock);
         uint256 marketId = 0;
         uint256 principalAmount = 500;
         uint32 duration = 10 days;
         uint16 interestRate = 100;

         ICommitmentRolloverLoan.AcceptCommitmentArgs memory commitmentArgs = ICommitmentRolloverLoan.AcceptCommitmentArgs({
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


        //fix me here -- tellerv2 needs to accept bid to put it in correct state
        vm.prank(address(borrower));
        
        commitmentRolloverLoan.rolloverLoan(
            loanId,
            commitmentArgs
        );
 

        bool acceptCommitmentWithRecipientWasCalled = lenderCommitmentForwarder.acceptCommitmentWithRecipientWasCalled();
        assertTrue(acceptCommitmentWithRecipientWasCalled,"acceptCommitmentWithRecipient not called");
    }


     /*function test_rolloverLoan_should_revert_if_loan_not_accepted() public {
 

         address lendingToken = address(wethMock);
         uint256 marketId = 0;
         uint256 principalAmount = 500;
         uint32 duration = 10 days;
         uint16 interestRate = 100;

         ICommitmentRolloverLoan.AcceptCommitmentArgs memory commitmentArgs = ICommitmentRolloverLoan.AcceptCommitmentArgs({
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


        
        vm.prank(address(borrower));
        vm.expectRevert();
        commitmentRolloverLoan.rolloverLoan(
            loanId,
            commitmentArgs
        );
        
    }*/
  

  function test_rolloverLoan_financial_scenario_A() public {

    address lendingToken = address(wethMock);
         uint256 marketId = 0;
         uint256 principalAmount = 500;
         uint32 duration = 10 days;
         uint16 interestRate = 100;

         ICommitmentRolloverLoan.AcceptCommitmentArgs memory commitmentArgs = ICommitmentRolloverLoan.AcceptCommitmentArgs({
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
        wethMock.approve(address(tellerV2),1e18);

        vm.prank(address(lender));
        (uint256 loanId) = tellerV2.lenderAcceptBid( 
            loanId  
         );


        


  }
  
}

contract User {}
