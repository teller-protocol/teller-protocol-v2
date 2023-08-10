// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Contracts
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

// Interfaces
import "../../interfaces/ITellerV2.sol";

import "../../interfaces/ILenderCommitmentForwarder.sol";
import "../../interfaces/ICommitmentRolloverLoan.sol";

contract CommitmentRolloverLoan is ICommitmentRolloverLoan {
    using AddressUpgradeable for address;

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ITellerV2 public immutable TELLER_V2;
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ILenderCommitmentForwarder public immutable LENDER_COMMITMENT_FORWARDER;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _tellerV2, address _lenderCommitmentForwarder) {
        TELLER_V2 = ITellerV2(_tellerV2);
        LENDER_COMMITMENT_FORWARDER = ILenderCommitmentForwarder(
            _lenderCommitmentForwarder
        );
    }

    function rolloverLoan(
        uint256 _loanId,
        uint256 rolloverAmount,
        AcceptCommitmentArgs calldata _commitmentArgs
    ) external returns (uint256 newLoanId_) {
        address borrower = TELLER_V2.getLoanBorrower(_loanId);
        require(borrower == msg.sender, "CommitmentRolloverLoan: not borrower");

        // Get lending token and balance before
        IERC20Upgradeable lendingToken = IERC20Upgradeable(
            TELLER_V2.getLoanLendingToken(_loanId)
        );
        uint256 balanceBefore = lendingToken.balanceOf(address(this));

        //accept funds from the borrower to this contract
        lendingToken.transferFrom(borrower, address(this), rolloverAmount);

        // Accept commitment and receive funds to this contract
        newLoanId_ = _acceptCommitment(_commitmentArgs);

        // Calculate funds received
        uint256 fundsReceived = lendingToken.balanceOf(address(this)) -
            balanceBefore;

        // Approve TellerV2 to spend funds and repay loan
        lendingToken.approve(address(TELLER_V2), fundsReceived);
        TELLER_V2.repayLoanFull(_loanId);

        uint256 fundsRemaining = lendingToken.balanceOf(address(this)) -
            balanceBefore;

        if (fundsRemaining > 0) {
            lendingToken.transfer(borrower, fundsRemaining);
        }
    }

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
}
