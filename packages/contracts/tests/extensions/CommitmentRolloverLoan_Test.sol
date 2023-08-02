import { Testable } from "../Testable.sol";

import { CommitmentRolloverLoan } from "../../contracts/LenderCommitmentForwarder/extensions/CommitmentRolloverLoan.sol";

import {TellerV2SolMock} from "../../contracts/mock/TellerV2SolMock.sol";
import {LenderCommitmentForwarderMock} from "../../contracts/mock/LenderCommitmentForwarderMock.sol";
import { User } from "../Test_Helpers.sol";

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

        tellerV2 = new TellerV2SolMock();

        //marketRegistryMock = new MarketRegistryMock();

        lenderCommitmentForwarder = new LenderCommitmentForwarderMock();

        commitmentRolloverLoan = new CommitmentRolloverLoanMock(
            address(tellerV2), address(lenderCommitmentForwarder)
        );


    }

  
  
}
