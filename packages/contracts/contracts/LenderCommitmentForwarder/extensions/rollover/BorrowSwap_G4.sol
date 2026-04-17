// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../../interfaces/ITellerV2.sol";
import "../../../interfaces/ITellerV2Storage.sol";
import "../../../interfaces/IMarketRegistry.sol";
import "../../../interfaces/ILenderCommitmentForwarder.sol";
import "../../../interfaces/ISmartCommitmentForwarder.sol";
import "../../../interfaces/ISwapAdapter.sol";

import "../../../libraries/uniswap/periphery/libraries/TransferHelper.sol";

/// @title BorrowSwap_G4
/// @notice Borrow from a lending pool and immediately swap the proceeds via a DEX.
///         Uses the ISwapAdapter pattern to support multiple DEX backends
///         (Uniswap V3, Algebra/Camelot V3, etc.) without changing this contract.
///         Swap paths are passed as arbitrary `bytes`, consistent with how
///         IPriceAdapter handles oracle routes in PoolsV3.
contract BorrowSwap_G4 {
    using AddressUpgradeable for address;

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ITellerV2 public immutable TELLER_V2;
    ISwapAdapter public immutable SWAP_ADAPTER;

    event BorrowSwapComplete(
        address borrower,
        uint256 loanId,
        address token0,
        uint256 amountIn,
        uint256 amountOut
    );

    struct AcceptCommitmentArgs {
        uint256 commitmentId;
        address smartCommitmentAddress;
        uint256 principalAmount;
        uint256 collateralAmount;
        uint256 collateralTokenId;
        address collateralTokenAddress;
        uint16 interestRate;
        uint32 loanDuration;
        bytes32[] merkleProof;
    }

    struct SwapArgs {
        bytes path; // DEX-encoded swap path (e.g. tokenIn ++ fee ++ tokenOut for Uniswap V3)
        uint160 amountOutMinimum;
    }

    /// @param _tellerV2 The address of the TellerV2 contract.
    /// @param _swapAdapter The address of an ISwapAdapter (UniswapV3SwapAdapter, AlgebraSwapAdapter, etc.)
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _tellerV2, address _swapAdapter) {
        TELLER_V2 = ITellerV2(_tellerV2);
        SWAP_ADAPTER = ISwapAdapter(_swapAdapter);
    }

    /// @notice Borrow funds from a lender commitment and immediately swap them.
    /// @param _lenderCommitmentForwarder The commitment forwarder contract
    /// @param _principalToken The token being borrowed (input to the swap)
    /// @param _additionalInputAmount Extra principal tokens the borrower adds to the swap
    /// @param _swapArgs Swap parameters (DEX-encoded path, slippage)
    /// @param _acceptCommitmentArgs Loan commitment parameters
    function borrowSwap(
        address _lenderCommitmentForwarder,
        address _principalToken,
        uint256 _additionalInputAmount,
        SwapArgs calldata _swapArgs,
        AcceptCommitmentArgs calldata _acceptCommitmentArgs
    ) external {
        address borrower = msg.sender;

        if (_additionalInputAmount > 0) {
            TransferHelper.safeTransferFrom(
                _principalToken, borrower, address(this), _additionalInputAmount
            );
        }

        // Accept commitment — locks collateral, receives principal to this contract
        (uint256 newLoanId, uint256 acceptCommitmentAmount) = _acceptCommitment(
            _lenderCommitmentForwarder,
            borrower,
            _principalToken,
            _acceptCommitmentArgs
        );

        uint256 totalInputAmount = acceptCommitmentAmount + _additionalInputAmount;

        // Approve the adapter, let it pull tokens and execute the swap
        TransferHelper.safeApprove(_principalToken, address(SWAP_ADAPTER), totalInputAmount);

        uint256 swapAmountOut = SWAP_ADAPTER.swap(
            _swapArgs.path,
            totalInputAmount,
            _swapArgs.amountOutMinimum,
            borrower
        );

        emit BorrowSwapComplete(
            borrower,
            newLoanId,
            _principalToken,
            totalInputAmount,
            swapAmountOut
        );
    }

    /// @notice Quote the expected output for an exact-input swap.
    /// @dev Not view — DEX quoters use state-reverting simulation internally.
    /// @param path DEX-encoded swap path
    /// @param amountIn Amount of input token to quote
    function quoteExactInput(
        bytes calldata path,
        uint256 amountIn
    ) external returns (uint256 amountOut) {
        return SWAP_ADAPTER.quote(path, amountIn);
    }

    // =========================================================================
    //  Commitment acceptance (unchanged from G3)
    // =========================================================================

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
                        borrower
                    )
                );

            (bidId_) = abi.decode(responseData, (uint256));
        } else {
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
                            borrower
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
                            borrower
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

    // =========================================================================
    //  Market helpers (unchanged from G3)
    // =========================================================================

    function getMarketIdForCommitment(
        address _lenderCommitmentForwarder,
        uint256 _commitmentId
    ) external view returns (uint256) {
        return ILenderCommitmentForwarder(_lenderCommitmentForwarder)
            .getCommitmentMarketId(_commitmentId);
    }

    function getMarketFeePct(uint256 _marketId) external view returns (uint16) {
        address _marketRegistryAddress = ITellerV2Storage(address(TELLER_V2))
            .marketRegistry();
        return IMarketRegistry(_marketRegistryAddress).getMarketplaceFee(_marketId);
    }
}
