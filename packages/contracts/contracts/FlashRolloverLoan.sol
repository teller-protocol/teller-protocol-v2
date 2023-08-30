// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Contracts
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Interfaces
import "./interfaces/ITellerV2.sol";
import "./interfaces/IProtocolFee.sol";
import "./interfaces/ITellerV2Storage.sol";
import "./interfaces/IMarketRegistry.sol";
import "./interfaces/ILenderCommitmentForwarder.sol";
import "./interfaces/ICommitmentRolloverLoan.sol";
import "./libraries/NumbersLib.sol";

import { IPool } from "./interfaces/aave/IPool.sol";
import { IFlashLoanSimpleReceiver } from "./interfaces/aave/IFlashLoanSimpleReceiver.sol";
import { IPoolAddressesProvider } from "./interfaces/aave/IPoolAddressesProvider.sol";

//https://docs.aave.com/developers/v/1.0/tutorials/performing-a-flash-loan/...-in-your-project

contract FlashRolloverLoan is
    ICommitmentRolloverLoan,
    IFlashLoanSimpleReceiver
{
    using AddressUpgradeable for address;
    using NumbersLib for uint256;

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ITellerV2 public immutable TELLER_V2;
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ILenderCommitmentForwarder public immutable LENDER_COMMITMENT_FORWARDER;

    address public immutable POOL_ADDRESSES_PROVIDER;

    event RolloverLoanComplete(
        address borrower,
        uint256 originalLoanId,
        uint256 newLoanId,
        uint256 fundsRemaining
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address _tellerV2,
        address _lenderCommitmentForwarder,
        address _poolAddressesProvider
    ) {
        TELLER_V2 = ITellerV2(_tellerV2);
        LENDER_COMMITMENT_FORWARDER = ILenderCommitmentForwarder(
            _lenderCommitmentForwarder
        );
        POOL_ADDRESSES_PROVIDER = _poolAddressesProvider;
    }

    modifier onlyFlashLoanPool() {
        require(
            msg.sender == address(POOL()),
            "FlashRolloverLoan: Must be called by FlashLoanPool"
        );

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

    /*
 
The flash loan amount can naively be the exact amount needed to repay the old loan 

If the new loan pays out (after fees) MORE than the  aave loan amount+ fee) then borrower amount can be zero 

 1) I could solve for what the new loans payout (before fees and after fees) would NEED to be to make borrower amount 0...

*/

    function rolloverLoanWithFlash(
        uint256 _loanId,
        uint256 _flashLoanAmount,
        uint256 _borrowerAmount, //an additional amount borrower may have to add
        AcceptCommitmentArgs calldata _acceptCommitmentArgs
    ) external returns (uint256 newLoanId_) {
        address borrower = TELLER_V2.getLoanBorrower(_loanId);
        require(borrower == msg.sender, "CommitmentRolloverLoan: not borrower");

        // Get lending token and balance before
        address lendingToken = TELLER_V2.getLoanLendingToken(_loanId);

        if (_borrowerAmount > 0) {
            IERC20(lendingToken).transferFrom(
                borrower,
                address(this),
                _borrowerAmount
            );
        }

        // Call 'Flash' on the vault to borrow funds and call tellerV2FlashCallback
        // This ultimately calls executeOperation
        IPool(POOL()).flashLoanSimple(
            address(this),
            lendingToken,
            _flashLoanAmount,
            abi.encode(
                RolloverCallbackArgs({
                    loanId: _loanId,
                    borrower: borrower,
                    borrowerAmount: _borrowerAmount,
                    acceptCommitmentArgs: abi.encode(_acceptCommitmentArgs)
                })
            ),
            0 //referral code
        );
    }

    function executeOperation(
        address _flashToken,
        uint256 _flashAmount,
        uint256 _flashFees, //need to incorporate this !
        address initiator,
        bytes calldata _data
    ) external onlyFlashLoanPool returns (bool) {
        require(
            initiator == address(this),
            "This contract must be the initiator"
        );

        RolloverCallbackArgs memory _rolloverArgs = abi.decode(
            _data,
            (RolloverCallbackArgs)
        );

        uint256 repaymentAmount = _repayLoanFull(
            _rolloverArgs.loanId,
            _flashToken,
            _flashAmount
        );

        AcceptCommitmentArgs memory acceptCommitmentArgs = abi.decode(
            _rolloverArgs.acceptCommitmentArgs,
            (AcceptCommitmentArgs)
        );

        // Accept commitment and receive funds to this contract

        (uint256 newLoanId, uint256 acceptCommitmentAmount) = _acceptCommitment(
            _rolloverArgs.borrower,
            _flashToken,
            acceptCommitmentArgs
        );

        //approve the repayment for the flash loan
        IERC20Upgradeable(_flashToken).approve(
            address(POOL()),
            _flashAmount + _flashFees
        );

        uint256 fundsRemaining = acceptCommitmentAmount +
            _rolloverArgs.borrowerAmount -
            repaymentAmount -
            _flashFees;

        if (fundsRemaining > 0) {
            IERC20Upgradeable(_flashToken).transfer(
                _rolloverArgs.borrower,
                fundsRemaining
            );
        }

        emit RolloverLoanComplete(
            _rolloverArgs.borrower,
            _rolloverArgs.loanId,
            newLoanId,
            fundsRemaining
        );

        return true;
    }

    //add a function for calculating borrower amount

    function _repayLoanFull(
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
    }

    /**
     * @notice Internally accepts a commitment via the `LENDER_COMMITMENT_FORWARDER`.
     * @param _commitmentArgs Arguments required to accept a commitment.
     * @return bidId_ The ID of the bid associated with the accepted commitment.
     */
    function _acceptCommitment(
        address borrower,
        address principalToken,
        AcceptCommitmentArgs memory _commitmentArgs
    ) internal returns (uint256 bidId_, uint256 acceptCommitmentAmount_) {
        uint256 fundsBeforeAcceptCommitment = IERC20Upgradeable(principalToken)
            .balanceOf(address(this));

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

        uint256 fundsAfterAcceptCommitment = IERC20Upgradeable(principalToken)
            .balanceOf(address(this));
        acceptCommitmentAmount_ =
            fundsAfterAcceptCommitment -
            fundsBeforeAcceptCommitment;
    }

    function ADDRESSES_PROVIDER() public view returns (IPoolAddressesProvider) {
        return IPoolAddressesProvider(POOL_ADDRESSES_PROVIDER);
    }

    function POOL() public view returns (IPool) {
        return IPool(ADDRESSES_PROVIDER().getPool());
    }

    /*

        This assumes that the flash amount will be the repayLoanFull amount !!

    */
    /**
     * @notice Calculates the amount for loan rollover, determining if the borrower owes or receives funds.
     * @param _loanId The ID of the loan to calculate the rollover amount for.
     * @param _commitmentArgs Arguments for the commitment.
     * @param _timestamp The timestamp for when the calculation is executed.
    
     */
    function calculateRolloverAmount(
        uint256 _loanId,
        AcceptCommitmentArgs calldata _commitmentArgs,
        uint16 _flashloanPremiumPct,
        uint256 _timestamp
    ) external view returns (uint256 _flashAmount, int256 _borrowerAmount) {
        Payment memory repayAmountOwed = TELLER_V2.calculateAmountOwed(
            _loanId,
            _timestamp
        );

        uint256 _marketId = _getMarketIdForCommitment(
            _commitmentArgs.commitmentId
        );
        uint16 marketFeePct = _getMarketFeePct(_marketId);
        uint16 protocolFeePct = _getProtocolFeePct();

        uint256 commitmentPrincipalRequested = _commitmentArgs.principalAmount;
        uint256 amountToMarketplace = commitmentPrincipalRequested.percent(
            marketFeePct
        );
        uint256 amountToProtocol = commitmentPrincipalRequested.percent(
            protocolFeePct
        );

        uint256 commitmentPrincipalReceived = commitmentPrincipalRequested -
            amountToMarketplace -
            amountToProtocol;

        // by default, we will flash exactly what we need to do relayLoanFull
        uint256 repayFullAmount = repayAmountOwed.principal +
            repayAmountOwed.interest;

        _flashAmount = repayFullAmount;
        uint256 _flashLoanFee = _flashAmount.percent(_flashloanPremiumPct);

        uint256 flashLoanFee = 0;

        //fix me ...
        _borrowerAmount =
            int256(commitmentPrincipalReceived) -
            int256(repayFullAmount) -
            int256(_flashLoanFee);
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
