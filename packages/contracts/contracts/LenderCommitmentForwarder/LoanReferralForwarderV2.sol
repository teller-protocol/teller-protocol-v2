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
import "../interfaces/ISmartCommitment.sol";
import "../interfaces/ISmartCommitmentForwarder.sol";
import "../interfaces/IFlashRolloverLoan_G4.sol";
import "../libraries/NumbersLib.sol";

import { ILenderCommitmentForwarder } from "../interfaces/ILenderCommitmentForwarder.sol";
 
import { ILenderCommitmentForwarder_U1 } from "../interfaces/ILenderCommitmentForwarder_U1.sol";

import '../libraries/uniswap/periphery/libraries/TransferHelper.sol';


contract LoanReferralForwarderV2 
  {
    using AddressUpgradeable for address;
    using NumbersLib for uint256;

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ITellerV2 public immutable TELLER_V2;
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
  
    

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


    event CommitmentAcceptedWithReward(
        uint256 indexed bidId,
        address indexed recipient,
        address principalTokenAddress, 
        uint256 fundsRemaining,
        uint256 reward,
        address rewardRecipient,
        uint256 atmId 
    );

    
    constructor(
        address _tellerV2 
     
    ) {
        TELLER_V2 = ITellerV2(_tellerV2);
        
    }

     

     /*
 
     */
    function acceptCommitmentWithReferral(
        address _commitmentForwarder,  
        
        AcceptCommitmentArgs calldata _acceptCommitmentArgs ,
          
        uint256 _atmId, 
        address _recipient,
        uint256 _reward,
        address _rewardRecipient

    ) external  returns (uint256 bidId_) {

 
         address principalTokenAddress = address(0);
         uint256 balanceBefore;

    
        require(_reward <= _acceptCommitmentArgs.principalAmount / 10, "Reward can be no more than 10% of principal");

        if (_acceptCommitmentArgs.smartCommitmentAddress != address(0)) {

         
                principalTokenAddress = ISmartCommitment(_acceptCommitmentArgs.smartCommitmentAddress).getPrincipalTokenAddress ();
        
            // Accept commitment and receive funds to this contract
                balanceBefore = IERC20(principalTokenAddress).balanceOf(address(this));
 
            bidId_ = _acceptSmartCommitmentWithRecipient(
                _commitmentForwarder,
                _acceptCommitmentArgs

            );

           
        }else{  
              principalTokenAddress = ILenderCommitmentForwarder_U1(_commitmentForwarder)
                  .getCommitmentPrincipalTokenAddress (_acceptCommitmentArgs.commitmentId);
        
            // Accept commitment and receive funds to this contract
              balanceBefore = IERC20(principalTokenAddress).balanceOf(address(this));
  

            bidId_ = _acceptCommitmentWithRecipient(
                _commitmentForwarder,
                _acceptCommitmentArgs

            ); 



        }
        
         uint256 balanceAfter = IERC20(principalTokenAddress).balanceOf(address(this));

         uint256 fundsRemaining = balanceAfter - balanceBefore;
 

         if (_reward > 0) {
             TransferHelper.safeTransferFrom(principalTokenAddress,  address(this), _rewardRecipient, _reward);
           
         }

         //check for 0 here ? 
         TransferHelper.safeTransferFrom(principalTokenAddress,  address(this), _recipient,   fundsRemaining - _reward);       
 

        emit CommitmentAcceptedWithReward( bidId_, _recipient, principalTokenAddress, fundsRemaining, _reward, _rewardRecipient , _atmId);
  
       
    }


    function _acceptSmartCommitmentWithRecipient( 
        address _smartCommitmentForwarder,
        AcceptCommitmentArgs calldata _acceptCommitmentArgs  
         

     ) internal returns (uint256 bidId_) {

            bytes memory responseData = address(_smartCommitmentForwarder)
                    .functionCall(
                        abi.encodePacked(
                            abi.encodeWithSelector(
                                ISmartCommitmentForwarder
                                    .acceptSmartCommitmentWithRecipient
                                    .selector,
                                _acceptCommitmentArgs.smartCommitmentAddress,
                                _acceptCommitmentArgs.principalAmount,
                                _acceptCommitmentArgs.collateralAmount,
                                _acceptCommitmentArgs.collateralTokenId,
                                _acceptCommitmentArgs.collateralTokenAddress,
                                address(this),
                                _acceptCommitmentArgs.interestRate,
                                _acceptCommitmentArgs.loanDuration
                            ),
                            msg.sender // borrower 
                        )
                    );


              (bidId_) = abi.decode(responseData, (uint256));



    }



    function _acceptCommitmentWithRecipient(
        address _commitmentForwarder,
        AcceptCommitmentArgs calldata _acceptCommitmentArgs  
            

    ) internal returns (uint256 bidId_) {

        bytes memory responseData = address(_commitmentForwarder)
                        .functionCall(
                            abi.encodePacked(
                                abi.encodeWithSelector(
                                    ILenderCommitmentForwarder
                                        .acceptCommitmentWithRecipient
                                        .selector,
                                    _acceptCommitmentArgs.commitmentId,
                                    _acceptCommitmentArgs.principalAmount,
                                    _acceptCommitmentArgs.collateralAmount,
                                    _acceptCommitmentArgs.collateralTokenId,
                                    _acceptCommitmentArgs.collateralTokenAddress,
                                    address(this),
                                    _acceptCommitmentArgs.interestRate,
                                    _acceptCommitmentArgs.loanDuration
                                ),
                                msg.sender //borrower 
                            )
                        );

                    (bidId_) = abi.decode(responseData, (uint256));


    }

    
    /**
     * @notice Fetches the protocol fee percentage from the Teller V2 protocol.
     * @return The protocol fee percentage as defined in the Teller V2 protocol.
     */
    function _getProtocolFeePct() internal view returns (uint16) {
        return IProtocolFee(address(TELLER_V2)).protocolFee();
    }
}