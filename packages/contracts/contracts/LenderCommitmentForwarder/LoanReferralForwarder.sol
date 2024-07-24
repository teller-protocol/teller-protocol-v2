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
import "../interfaces/ISmartCommitmentForwarder.sol";
import "../interfaces/IFlashRolloverLoan_G4.sol";
import "../libraries/NumbersLib.sol";

import { ILenderCommitmentForwarder } from "../interfaces/ILenderCommitmentForwarder.sol";
 
 


contract LoanReferralForwarder  
  {
    using AddressUpgradeable for address;
    using NumbersLib for uint256;

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ITellerV2 public immutable TELLER_V2;
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
  
  

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
        address _tellerV2 
     
    ) {
        TELLER_V2 = ITellerV2(_tellerV2);
        
    }

     

     /*

            PROBLEM: how do i know the token ?

     */
    function acceptCommitmentWithReferral(
        address _commitmentForwarder,
        uint256 _commitmentId,

        address _smartCommitmentAddress,  //leave 0 if using a commitmentForwarder
        

//     address _principalToken,
        uint256 _principalAmount,
        uint256 _collateralAmount,
        uint256 _collateralTokenId,
        address _collateralTokenAddress,
        
        uint16 _interestRate,
        uint32 _loanDuration,

        address _recipient,
        uint256 _minAmountReceived,

        uint256 _reward,
        address _rewardRecipient

    ) external   {


        /*
            I need to somehow know the principal token address here ? 

        Not sufficient to let the caller decide . 
        */
       
       
        // Accept commitment and receive funds to this contract
        uint256 balanceBefore = IERC20(_principalToken).balanceOf(address(this));

        if (_smartCommitmentAddress != address(0)) {
        
                (uint256 bidId) = ISmartCommitmentForwarder(_smartCommitmentAddress).acceptSmartCommitmentWithRecipient(
                
                _principalAmount,
                _collateralAmount,
                _collateralTokenId,
                _collateralTokenAddress,
                address(this), //this contract is the recipient ,
                _interestRate,
                _loanDuration
            );
        
        }else{


            (uint256 bidId) = ILenderCommitmentForwarder(_commitmentForwarder).acceptCommitmentWithRecipient(
                _commitmentId,
                _principalAmount,
                _collateralAmount,
                _collateralTokenId,
                _collateralTokenAddress,
                address(this), //this contract is the recipient ,
                _interestRate,
                _loanDuration
            );

        }
        //at this point, this contract has received acceptCommitmentAmount tokens.  So the majority of them should be sent to the msg.sender (borrower) 


         uint256 balanceAfter = IERC20(_principalToken).balanceOf(address(this));

         uint256 fundsRemaining = balanceAfter - balanceBefore;

         require(  fundsRemaining >= _minAmountReceived, "Insufficient funds received" );

         
         IERC20Upgradeable(_principalToken).transfer(
                _rewardRecipient,
                _reward
          );

         IERC20Upgradeable(_principalToken).transfer(
                _recipient,
                fundsRemaining - reward
          );



       
    }


   

    /**
     * @notice Fetches the protocol fee percentage from the Teller V2 protocol.
     * @return The protocol fee percentage as defined in the Teller V2 protocol.
     */
    function _getProtocolFeePct() internal view returns (uint16) {
        return IProtocolFee(address(TELLER_V2)).protocolFee();
    }
}