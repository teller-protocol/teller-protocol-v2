// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Contracts
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../libraries/NumbersLib.sol";

// Interfaces
import "./FlashRolloverLoan_G2.sol";

contract FlashRolloverLoan_G3 is FlashRolloverLoan_G2 {
    using AddressUpgradeable for address;
    using NumbersLib for uint256;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address _tellerV2,
        address _lenderCommitmentForwarder,
        address _poolAddressesProvider
    )
        FlashRolloverLoan_G2(
            _tellerV2,
            _lenderCommitmentForwarder,
            _poolAddressesProvider
        )
    {}


function rolloverLoanWithFlashAndMerkle(
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


    //add merkle proof here 
     function executeOperation(
        address _flashToken,
        uint256 _flashAmount,
        uint256 _flashFees,
        address initiator,
        bytes calldata _data
    ) external onlyFlashLoanPool virtual override returns (bool) {
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



    function _acceptCommitment(
        address borrower,
        address principalToken,
        AcceptCommitmentArgs memory _commitmentArgs
    ) internal virtual override returns (uint256 bidId_, uint256 acceptCommitmentAmount_) {
        uint256 fundsBeforeAcceptCommitment = IERC20Upgradeable(principalToken)
            .balanceOf(address(this));

        bool usingMerkleProof = _commitmentArgs.merkleProof.length > 0;
        
        if(usingMerkleProof){


        bytes memory responseData = address(LENDER_COMMITMENT_FORWARDER)
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


        }else{


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

       

        uint256 fundsAfterAcceptCommitment = IERC20Upgradeable(principalToken)
            .balanceOf(address(this));
        acceptCommitmentAmount_ =
            fundsAfterAcceptCommitment -
            fundsBeforeAcceptCommitment;
    }


    
}
