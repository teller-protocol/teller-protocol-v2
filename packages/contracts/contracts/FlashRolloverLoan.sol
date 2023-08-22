// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Contracts
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

// Interfaces
import "./interfaces/ITellerV2.sol";
import "./interfaces/IProtocolFee.sol";
import "./interfaces/ITellerV2Storage.sol";
import "./interfaces/IMarketRegistry.sol";
import "./interfaces/ILenderCommitmentForwarder.sol";
import "./interfaces/ICommitmentRolloverLoan.sol";
import "./libraries/NumbersLib.sol";

import {IPool} from "./interfaces/aave/IPool.sol";
import {IFlashLoanSimpleReceiver} from "./interfaces/aave/IFlashLoanSimpleReceiver.sol";
//https://docs.aave.com/developers/v/1.0/tutorials/performing-a-flash-loan/...-in-your-project


contract FlashRolloverLoan is ICommitmentRolloverLoan,IFlashLoanSimpleReceiver {
    using AddressUpgradeable for address;
    using NumbersLib for uint256;

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ITellerV2 public immutable TELLER_V2;
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ILenderCommitmentForwarder public immutable LENDER_COMMITMENT_FORWARDER;

    address public immutable FLASH_LOAN_VAULT;
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _tellerV2, address _lenderCommitmentForwarder, address _flashLoanVault) {
        TELLER_V2 = ITellerV2(_tellerV2);
        LENDER_COMMITMENT_FORWARDER = ILenderCommitmentForwarder(
            _lenderCommitmentForwarder
        );
        FLASH_LOAN_VAULT = _flashLoanVault;
    }
 

    modifier onlyFlashLoanVault {

      require( msg.sender == FLASH_LOAN_VAULT );

      _;
    }


    /*
    need to pass loanId and borrower 
    */

    struct RolloverCallbackArgs {
        uint256 loanId;
        address borrower;
        uint256 borrowerAmount;
        bytes acceptCommitmentArgs;
    }
 

    /**
     * @notice Allows a borrower to rollover a loan to a new commitment.
     * @param _loanId The bid id for the loan to repay 
     * @param _flashLoanAmount The amount to flash borrow.
     * @param _acceptCommitmentArgs Arguments for the commitment to accept.
     * @return newLoanId_ The ID of the new loan created by accepting the commitment.
     */

     //make sure this cant be re-entered . 
    function rolloverLoanWithFlash(
        uint256 _loanId,
        uint256 _flashLoanAmount,
        uint256 _borrowerAmount , //an additional amount borrower may have to add 
        AcceptCommitmentArgs calldata _acceptCommitmentArgs
    ) external returns (uint256 newLoanId_) { 

        address borrower = TELLER_V2.getLoanBorrower(_loanId);
        require(borrower == msg.sender, "CommitmentRolloverLoan: not borrower");

        // Get lending token and balance before
        address lendingToken =  
            TELLER_V2.getLoanLendingToken(_loanId)
         ;
        uint256 balanceBefore = IERC20Upgradeable(lendingToken).balanceOf(address(this));
        
        //aave lending pool 
        IPool lendingPool = IPool(FLASH_LOAN_VAULT);

        uint16 _referralCode = 0;
        
        // Call 'Flash' on the vault to borrow funds and call tellerV2FlashCallback
        // This ultimately calls executeOperation 
        lendingPool.flashLoanSimple(
            address(this), 
           lendingToken, 
           _flashLoanAmount, 
           abi.encode(
                RolloverCallbackArgs({
                    loanId: _loanId,
                    borrower: borrower,
                    borrowerAmount: _borrowerAmount,
                    acceptCommitmentArgs: abi.encode(  _acceptCommitmentArgs )
                })
            ),
            _referralCode
            ); 
        
    }


    //this is to be called by the flash vault ONLY 
    function executeOperation(  
          address _flashToken,
        uint256 _flashAmount, 
      
        uint256 _flashFees, //need to incorporate this ! 
        address initiator,
        bytes calldata _data
    ) external onlyFlashLoanVault {

        require( initiator == address(this), "This contract must be the initiator" );

        // _flashToken should be the lendingToken 

         RolloverCallbackArgs memory _rolloverArgs = abi.decode(
                _data,
                (RolloverCallbackArgs)
            );


        uint256 fundsBeforeRepayment = IERC20Upgradeable(_flashToken).balanceOf(address(this));


        IERC20Upgradeable(_flashToken).approve(address(TELLER_V2), _flashAmount);
        TELLER_V2.repayLoanFull(_rolloverArgs.loanId);

        uint256 fundsAfterRepayment = IERC20Upgradeable(_flashToken).balanceOf(address(this));

        uint256 repaymentAmount = fundsBeforeRepayment - fundsAfterRepayment;
 
        AcceptCommitmentArgs memory acceptCommitmentArgs = abi.decode(
            _rolloverArgs.acceptCommitmentArgs , (AcceptCommitmentArgs)
        );

        // Accept commitment and receive funds to this contract
        uint256 newLoanId_ = _acceptCommitment( _rolloverArgs.borrower,  acceptCommitmentArgs  );

        uint256 fundsAfterAcceptCommitment = IERC20Upgradeable(_flashToken).balanceOf(address(this));

        uint256 acceptCommitmentAmount = fundsAfterAcceptCommitment - fundsAfterRepayment;

        //repay the flash loan !! 
        IERC20Upgradeable(_flashToken).transfer( FLASH_LOAN_VAULT, _flashAmount  );


        uint256 fundsRemaining = acceptCommitmentAmount - repaymentAmount;

        if (fundsRemaining > 0) {
            IERC20Upgradeable(_flashToken).transfer(_rolloverArgs.borrower, fundsRemaining);
        }
 

    }

 
    /**
     * @notice Internally accepts a commitment via the `LENDER_COMMITMENT_FORWARDER`.
     * @param _commitmentArgs Arguments required to accept a commitment.
     * @return bidId_ The ID of the bid associated with the accepted commitment.
     */
    function _acceptCommitment(address borrower, AcceptCommitmentArgs memory _commitmentArgs)
        internal
        returns (uint256 bidId_)
    {
        bytes memory responseData = address(LENDER_COMMITMENT_FORWARDER)
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

    /**
     * @notice Retrieves the market ID associated with a given commitment.
     * @param _commitmentId The ID of the commitment for which to fetch the market ID.
     * @return The ID of the market associated with the provided commitment.
     */
    function _getMarketIdForCommitment(uint256 _commitmentId)
        internal
        view
        returns (uint256)
    {
        return LENDER_COMMITMENT_FORWARDER.getCommitmentMarketId(_commitmentId);
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
