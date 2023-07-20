// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Contracts
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

// Interfaces
import "../../interfaces/ITellerV2.sol";

interface ILenderCommitmentForwarder {
    function acceptCommitmentWithRecipient(
        uint256 _commitmentId,
        uint256 _principalAmount,
        uint256 _collateralAmount,
        uint256 _collateralTokenId,
        address _collateralTokenAddress,
        address _recipient,
        uint16 _interestRate,
        uint32 _loanDuration
    ) external returns (uint256 bidId_);

    function acceptCommitmentWithRecipientAndProof(
        uint256 _commitmentId,
        uint256 _principalAmount,
        uint256 _collateralAmount,
        uint256 _collateralTokenId,
        address _collateralTokenAddress,
        address _recipient,
        uint16 _interestRate,
        uint32 _loanDuration,
        bytes32[] calldata _merkleProof
    ) external returns (uint256 bidId_);
}

contract CommitmentRolloverLoan {
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

    struct AcceptCommitmentArgs {
        uint256 commitmentId;
        uint256 principalAmount;
        uint256 collateralAmount;
        uint256 collateralTokenId;
        address collateralTokenAddress;
        uint16 interestRate;
        uint32 loanDuration;
    }

    function rolloverLoan(
        uint256 _loanId,
        AcceptCommitmentArgs calldata _commitmentArgs
    ) external returns (uint256 newLoanId_) {
        address borrower = TELLER_V2.getLoanBorrower(_loanId);
        require(borrower == msg.sender, "CommitmentRolloverLoan: not borrower");

        // Get lending token and balance before
        IERC20Upgradeable lendingToken = IERC20Upgradeable(
            TELLER_V2.getLoanLendingToken(_loanId)
        );
        uint256 balanceBefore = lendingToken.balanceOf(address(this));

        // Accept commitment and receive funds to this contract
        newLoanId_ = _acceptCommitment(_commitmentArgs);

        // Calculate funds received
        uint256 fundsReceived = lendingToken.balanceOf(address(this)) -
            balanceBefore;

        // Approve TellerV2 to spend funds and repay loan
        lendingToken.approve(address(TELLER_V2), fundsReceived);
        TELLER_V2.repayLoanFull(_loanId);
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
                            .acceptCommitmentWithReceiver
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
