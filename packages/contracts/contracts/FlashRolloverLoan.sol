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

import {IFlashSingleToken, ITellerV2FlashCallback, FlashLoanVault} from "./FlashLoanVault.sol";

contract FlashRolloverLoan is ICommitmentRolloverLoan,ITellerV2FlashCallback {
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



    /**
     * @notice Allows a borrower to rollover a loan to a new commitment.
     * @param _loanId The ID of the existing loan.
     * @param _flashLoanAmount The amount to flash borrow.
     * @param _commitmentArgs Arguments for the commitment to accept.
     * @return newLoanId_ The ID of the new loan created by accepting the commitment.
     */

     //make sure this cant be re-entered . 
    function rolloverLoanWithFlash(
        uint256 _loanId,
        uint256 _flashLoanAmount,
        AcceptCommitmentArgs calldata _commitmentArgs
    ) external returns (uint256 newLoanId_) {
        address borrower = TELLER_V2.getLoanBorrower(_loanId);
        require(borrower == msg.sender, "CommitmentRolloverLoan: not borrower");


    


        // Get lending token and balance before
        address lendingToken =  
            TELLER_V2.getLoanLendingToken(_loanId)
         ;
        uint256 balanceBefore = IERC20Upgradeable(lendingToken).balanceOf(address(this));

        bytes calldata data = "";


        // Call 'Flash' on the vault 
        IFlashSingleToken(FLASH_LOAN_VAULT).flash( 
            _flashLoanAmount,
            lendingToken,
            data
         );
        
    }

    //this is called by the flash vault ONLY 
    function tellerV2FlashCallback(  
        uint256 amount, 
        address token,
        bytes calldata data
    ) external onlyFlashLoanVault {


/*

        uint256 fundsReceived = lendingToken.balanceOf(address(this)) -
            balanceBefore;


        // Approve TellerV2 to spend funds and repay loan
        // this puts the collateral in the borrowers wallet 
        lendingToken.approve(address(TELLER_V2), fundsReceived);
        TELLER_V2.repayLoanFull(_loanId);
 
         
        // Accept commitment and receive funds to this contract
        newLoanId_ = _acceptCommitment(_commitmentArgs);

*/
        //repay the flash loan !! 



        // Calculate funds received
      /*  uint256 fundsReceived = lendingToken.balanceOf(address(this)) -
            balanceBefore;



        uint256 fundsRemaining = lendingToken.balanceOf(address(this)) -
            balanceBefore;*/

        /*
        if (fundsRemaining > 0) {
            lendingToken.transfer(borrower, fundsRemaining);
        }*/



    }

 
    /**
     * @notice Internally accepts a commitment via the `LENDER_COMMITMENT_FORWARDER`.
     * @param _commitmentArgs Arguments required to accept a commitment.
     * @return bidId_ The ID of the bid associated with the accepted commitment.
     */
    function _acceptCommitment(AcceptCommitmentArgs calldata _commitmentArgs)
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
                    msg.sender
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
