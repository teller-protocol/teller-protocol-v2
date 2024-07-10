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

import { IPool } from "../interfaces/aave/IPool.sol";
import { IFlashLoanSimpleReceiver } from "../interfaces/aave/IFlashLoanSimpleReceiver.sol";
import { IPoolAddressesProvider } from "../interfaces/aave/IPoolAddressesProvider.sol";

 

/*


GENERAL IDEA: 


This will be on a similar level as FlashRolloverLoan


This will call acceptCommitmentWithRecipient and this contract will be the recipient
When the funds are received, it will distribute some of them to the referrer 



*/








contract LoanReferralForwarder   {
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

     
    /**
     *
     * @notice Allows the borrower to rollover their existing loan using a flash loan mechanism.
     *         The borrower might also provide an additional amount during the rollover.
     *
     * @dev The function first verifies that the caller is the borrower of the loan.
     *      It then optionally transfers the additional amount specified by the borrower.
     *      A flash loan is then taken from the pool to facilitate the rollover and
     *      a callback is executed for further operations.
     *
     * @param _loanId Identifier of the existing loan to be rolled over.
       * @param _acceptCommitmentArgs Commitment arguments that might be necessary for internal operations.
     * 
     */

     


    function acceptCommitmentReferral(
        address _lenderCommitmentForwarder,
        uint256 _loanId,
      //  uint256 _flashLoanAmount,
      //  uint256 _borrowerAmount, //an additional amount borrower may have to add
        AcceptCommitmentArgs calldata _acceptCommitmentArgs
    ) external   {
        address borrower = TELLER_V2.getLoanBorrower(_loanId);
        require(borrower == msg.sender, "CommitmentRolloverLoan: not borrower");
        // why is this needed ? 


        // Get lending token and balance before
        address lendingToken = TELLER_V2.getLoanLendingToken(_loanId);

      /*  if (_borrowerAmount > 0) {
            IERC20(lendingToken).transferFrom(
                borrower,
                address(this),
                _borrowerAmount
            );
        } */


        /*
          AcceptCommitmentArgs memory acceptCommitmentArgs = abi.decode(
            _rolloverArgs.acceptCommitmentArgs,
            (AcceptCommitmentArgs)
        );*/

        // Accept commitment and receive funds to this contract

        (uint256 newLoanId, uint256 acceptCommitmentAmount) = _acceptCommitment(
            _lenderCommitmentForwarder,
            borrower,
            lendingToken,
            _acceptCommitmentArgs
        );


        //at this point, this contract has received acceptCommitmentAmount tokens.  So the majority of them should be sent to the msg.sender (borrower) 



       
    }



    /**
     *
     *
     * @notice Internal function that repays a loan in full on behalf of this contract.
     *
     * @dev The function first calculates the funds held by the contract before repayment, then approves
     *      the repayment amount to the TellerV2 contract and finally repays the loan in full.
     *
     * @param _bidId Identifier of the loan to be repaid.
     * @param _principalToken The token in which the loan was originated.
     * @param _repayAmount The amount to be repaid.
     *
     * @return repayAmount_ The actual amount that was used for repayment.
     */
  /*  function _repayLoanFull(
        uint256 _bidId,
        address _principalToken,
        uint256 _repayAmount
    ) internal returns (uint256 repayAmount_) {
        uint256 fundsBeforeRepayment = IERC20Upgradeable(_principalToken)
            .balanceOf(address(this));

        IERC20Upgradeable(_principalToken).approve(
            address(TELLER_V2),
            _repayAmount
        );
        TELLER_V2.repayLoanFull(_bidId);

        uint256 fundsAfterRepayment = IERC20Upgradeable(_principalToken)
            .balanceOf(address(this));

        repayAmount_ = fundsBeforeRepayment - fundsAfterRepayment;
    }*/

    /**
     *
     *
     * @notice Accepts a loan commitment using either a Merkle proof or standard method.
     *
     * @dev The function first checks if a Merkle proof is provided, based on which it calls the relevant
     *      `acceptCommitment` function in the LenderCommitmentForwarder contract.
     *
     * @param borrower The address of the borrower for whom the commitment is being accepted.
     * @param principalToken The token in which the loan is being accepted.
     * @param _commitmentArgs The arguments necessary for accepting the commitment.
     *
     * @return bidId_ Identifier of the accepted loan.
     * @return acceptCommitmentAmount_ The amount received from accepting the commitment.
     */
    function _acceptCommitment(
        address lenderCommitmentForwarder,
        address borrower,
        address principalToken,
        AcceptCommitmentArgs memory _commitmentArgs
    )
        internal
        virtual
        returns (uint256 bidId_, uint256 acceptCommitmentAmount_)
    {
        uint256 fundsBeforeAcceptCommitment = IERC20Upgradeable(principalToken)
            .balanceOf(address(this));



        if (_commitmentArgs.smartCommitmentAddress != address(0)) {

             bytes memory responseData = address(lenderCommitmentForwarder)
                    .functionCall(
                        abi.encodePacked(
                            abi.encodeWithSelector(
                                ISmartCommitmentForwarder
                                    .acceptSmartCommitmentWithRecipient
                                    .selector,
                                _commitmentArgs.smartCommitmentAddress,
                                _commitmentArgs.principalAmount,
                                _commitmentArgs.collateralAmount,
                                _commitmentArgs.collateralTokenId,
                                _commitmentArgs.collateralTokenAddress,
                                address(this),
                                _commitmentArgs.interestRate,
                                _commitmentArgs.loanDuration
                            ),
                            borrower //cant be msg.sender because of the flash flow
                        )
                    );

                (bidId_) = abi.decode(responseData, (uint256));


        }else { 

            bool usingMerkleProof = _commitmentArgs.merkleProof.length > 0;

            if (usingMerkleProof) {
                bytes memory responseData = address(lenderCommitmentForwarder)
                    .functionCall(
                        abi.encodePacked(
                            abi.encodeWithSelector(
                                ILenderCommitmentForwarder
                                    .acceptCommitmentWithRecipientAndProof
                                    .selector,
                                _commitmentArgs.commitmentId,
                                _commitmentArgs.principalAmount,
                                _commitmentArgs.collateralAmount,
                                _commitmentArgs.collateralTokenId,
                                _commitmentArgs.collateralTokenAddress,
                                address(this),
                                _commitmentArgs.interestRate,
                                _commitmentArgs.loanDuration,
                                _commitmentArgs.merkleProof
                            ),
                            borrower //cant be msg.sender because of the flash flow
                        )
                    );

                (bidId_) = abi.decode(responseData, (uint256));
            } else {
                bytes memory responseData = address(lenderCommitmentForwarder)
                    .functionCall(
                        abi.encodePacked(
                            abi.encodeWithSelector(
                                ILenderCommitmentForwarder
                                    .acceptCommitmentWithRecipient
                                    .selector,
                                _commitmentArgs.commitmentId,
                                _commitmentArgs.principalAmount,
                                _commitmentArgs.collateralAmount,
                                _commitmentArgs.collateralTokenId,
                                _commitmentArgs.collateralTokenAddress,
                                address(this),
                                _commitmentArgs.interestRate,
                                _commitmentArgs.loanDuration
                            ),
                            borrower //cant be msg.sender because of the flash flow
                        )
                    );

                (bidId_) = abi.decode(responseData, (uint256));
            }

        }

        uint256 fundsAfterAcceptCommitment = IERC20Upgradeable(principalToken)
            .balanceOf(address(this));

        acceptCommitmentAmount_ =
            fundsAfterAcceptCommitment -
            fundsBeforeAcceptCommitment;
    }
 

     

    /**
     * @notice Calculates the amount for loan rollover, determining if the borrower owes or receives funds.
     * @param _loanId The ID of the loan to calculate the rollover amount for.
     * @param _commitmentArgs Arguments for the commitment.
     * @param _timestamp The timestamp for when the calculation is executed.
    
     */
    
    /**
     * @notice Retrieves the market ID associated with a given commitment.
     * @param _commitmentId The ID of the commitment for which to fetch the market ID.
     * @return The ID of the market associated with the provided commitment.
     */
    function _getMarketIdForCommitment(address _lenderCommitmentForwarder, uint256 _commitmentId)
        internal
        view
        returns (uint256)
    {
        return ILenderCommitmentForwarder(_lenderCommitmentForwarder).getCommitmentMarketId(_commitmentId);
    }

    /**
     * @notice Fetches the marketplace fee percentage for a given market ID.
     * @param _marketId The ID of the market for which to fetch the fee percentage.
     * @return The marketplace fee percentage for the provided market ID.
     */
    function _getMarketFeePct(uint256 _marketId)
        internal
        view
        returns (uint16)
    {
        address _marketRegistryAddress = ITellerV2Storage(address(TELLER_V2))
            .marketRegistry();

        return
            IMarketRegistry(_marketRegistryAddress).getMarketplaceFee(
                _marketId
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