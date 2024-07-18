// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Contracts
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Interfaces
import "../interfaces/ITellerV2.sol";
import "../interfaces/IProtocolFee.sol";
import "../interfaces/ITellerV2Storage.sol";
import "../interfaces/IMarketRegistry.sol";
import "../interfaces/ILenderCommitmentForwarder.sol";
import "../interfaces/ISmartCommitmentForwarder.sol";
import "../interfaces/IFlashRolloverLoan_G4.sol";
import "../libraries/NumbersLib.sol";

import { ILenderCommitmentForwarder_U1 } from "../interfaces/ILenderCommitmentForwarder_U1.sol";
 
/*


GENERAL IDEA: 


This will be on a similar level as FlashRolloverLoan


This will call acceptCommitmentWithRecipient and this contract will be the recipient
When the funds are received, it will distribute some of them to the referrer 



*/
 



contract LoanReferralForwarder  
  {
    using AddressUpgradeable for address;
    using NumbersLib for uint256;

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ITellerV2 public immutable TELLER_V2;
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    
    ILenderCommitmentForwarder_U1 public immutable COMMITMENT_FORWARDER;
 
 
/*
    struct AcceptCommitmentArgs {
        uint256 commitmentId;
        address smartCommitmentAddress;  //if this is not address(0), we will use this ! leave empty if not used. 
        uint256 principalAmount;
        uint256 collateralAmount;
        uint256 collateralTokenId;
        address collateralTokenAddress;
        uint16 interestRate;
        uint32 loanDuration;
        bytes32[] merkleProof; //empty array if not used
    }
*/

    /**
     *
     * @notice Initializes the FlashRolloverLoan with necessary contract addresses.
     *
     * @dev Using a custom OpenZeppelin upgrades tag. Ensure the constructor logic is safe for upgrades.
     *
     * @param _tellerV2 The address of the TellerV2 contract.
     
     */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address _tellerV2,
        address _commitmentForwarder
        
    ) {
        TELLER_V2 = ITellerV2(_tellerV2);
        COMMITMENT_FORWARDER = ILenderCommitmentForwarder_U1(_commitmentForwarder);
         
    }

     
    function acceptCommitmentWithReferral(
       
        uint256 _commitmentId,
        uint256 _principalAmount,
        uint256 _collateralAmount,
        uint256 _collateralTokenId,
        address _collateralTokenAddress,
        
        uint16 _interestRate,
        uint32 _loanDuration

    ) external   {
       
       
       /* address borrower = TELLER_V2.getLoanBorrower(_loanId);
        require(borrower == msg.sender, "CommitmentRolloverLoan: not borrower");
        // why is this needed ? 


        // Get lending token and balance before
        address lendingToken = TELLER_V2.getLoanLendingToken(_loanId);
    */

        // Accept commitment and receive funds to this contract

        (uint256 newLoanId, uint256 acceptCommitmentAmount) = COMMITMENT_FORWARDER.acceptCommitmentWithRecipient(
             _commitmentId,
             _principalAmount,
             _collateralAmount,
             _collateralTokenId,
             _collateralTokenAddress,
             address(this), //this contract is the recipient ,
             _interestRate,
             _loanDuration
        );


        //at this point, this contract has received acceptCommitmentAmount tokens.  So the majority of them should be sent to the msg.sender (borrower) 



       
    }


   

    /**
     * @notice Fetches the protocol fee percentage from the Teller V2 protocol.
     * @return The protocol fee percentage as defined in the Teller V2 protocol.
     */
    function _getProtocolFeePct() internal view returns (uint16) {
        return IProtocolFee(address(TELLER_V2)).protocolFee();
    }
}