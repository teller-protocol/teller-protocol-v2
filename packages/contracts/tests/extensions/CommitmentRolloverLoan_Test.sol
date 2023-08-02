import { Testable } from "../Testable.sol";

import { CommitmentRolloverLoan } from "../../contracts/LenderCommitmentForwarder/extensions/CommitmentRolloverLoan.sol";


import "../../contracts/interfaces/ICommitmentRolloverLoan.sol";

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
    LenderCommitmentForwarderMock lenderCommitmentForwarder ;
    //MarketRegistryMock marketRegistryMock;

    function setUp() public {

        borrower = new User();
        lender = new User();

        tellerV2 = new TellerV2SolMock();

        //marketRegistryMock = new MarketRegistryMock();

        lenderCommitmentForwarder = new LenderCommitmentForwarderMock();

        commitmentRolloverLoan = new CommitmentRolloverLoanMock(
            address(tellerV2), address(lenderCommitmentForwarder)
        );


    }


    // add more tests here !! 


    function test_rolloverLoan() public {

        uint256 loanId = 0 ;

        ICommitmentRolloverLoan.AcceptCommitmentArgs memory commitmentArgs = ICommitmentRolloverLoan.AcceptCommitmentArgs({
            commitmentId: 0,
            principalAmount: 500,
            collateralAmount: 100,
            collateralTokenId: 0,
            collateralTokenAddress: address(0),
            interestRate: 100,
            loanDuration: 10 days


         });

        vm.prank(address(borrower));
        commitmentRolloverLoan.rolloverLoan(
            loanId,
            commitmentArgs
        );
        
    }
  
  
}

contract User {}
