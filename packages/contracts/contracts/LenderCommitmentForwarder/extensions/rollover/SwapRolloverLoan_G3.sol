// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SwapRolloverLoan_G2.sol";

/**
 * @title SwapRolloverLoan_G3
 * @notice Adds PancakeSwap V3 flash callback compatibility.
 * @dev PancakeSwap V3 pools call `pancakeV3FlashCallback` instead of `uniswapV3FlashCallback`.
 *      This generation extracts the callback logic into `_flashCallback()` and routes both
 *      callback variants through it, enabling the contract to work on BSC and other
 *      PancakeSwap V3 chains.
 */
contract SwapRolloverLoan_G3 is SwapRolloverLoan_G2 {

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address _tellerV2,
        address _factory,
        address _WETH9
    ) SwapRolloverLoan_G2(_tellerV2, _factory, _WETH9) {}

    /*
        @dev  Overrides the Uniswap V3 callback to delegate to shared _flashCallback logic.
    */
    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external override {
        _flashCallback(fee0, fee1, data);
    }

    /*
        @dev  PancakeSwap V3 uses a different callback name than Uniswap V3.
              This allows the contract to work on chains using PancakeSwap V3 (e.g. BSC).
    */
    function pancakeV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external {
        _flashCallback(fee0, fee1, data);
    }

    /**
     * @dev Shared flash callback logic used by both uniswapV3FlashCallback and pancakeV3FlashCallback.
     */
    function _flashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) internal {
        RolloverCallbackArgs memory _rolloverArgs = abi.decode(data, (RolloverCallbackArgs));

        AcceptCommitmentArgs memory acceptCommitmentArgs = abi.decode(
            _rolloverArgs.acceptCommitmentArgs,
            (AcceptCommitmentArgs)
        );

        FlashSwapArgs memory flashSwapArgs = abi.decode(
            _rolloverArgs.flashSwapArgs,
            (FlashSwapArgs)
        );

        _verifyFlashCallback(
            flashSwapArgs.token0,
            flashSwapArgs.token1,
            flashSwapArgs.fee,
            msg.sender
        );

        address flashToken = flashSwapArgs.borrowToken1 ? flashSwapArgs.token1 : flashSwapArgs.token0;
        uint256 flashFee = flashSwapArgs.borrowToken1 ? fee1 : fee0;

        uint256 repaymentAmount = _repayLoanFull(
            _rolloverArgs.loanId,
            flashToken,
            flashSwapArgs.flashAmount
        );

        // Accept commitment and receive funds to this contract
        (uint256 newLoanId, uint256 acceptCommitmentAmount) = _acceptCommitment(
            _rolloverArgs.lenderCommitmentForwarder,
            _rolloverArgs.borrower,
            flashToken,
            acceptCommitmentArgs
        );

        uint256 amountOwedToPool = LowGasSafeMath.add(flashSwapArgs.flashAmount, flashFee);

        //  msg.sender is the uniswap pool
        if (amountOwedToPool > 0) pay(flashToken, address(this), msg.sender, amountOwedToPool);

        // send any dust to the borrower
        uint256 fundsRemaining = flashSwapArgs.flashAmount +
            acceptCommitmentAmount +
            _rolloverArgs.borrowerAmount -
            repaymentAmount -
            amountOwedToPool;

        if (fundsRemaining > 0) {

            if (_rolloverArgs.rewardAmount > 0) {

                fundsRemaining -= _rolloverArgs.rewardAmount;
                TransferHelper.safeTransfer(flashToken, _rolloverArgs.rewardRecipient, _rolloverArgs.rewardAmount);

                emit RolloverWithReferral(newLoanId, flashToken, _rolloverArgs.rewardRecipient, _rolloverArgs.rewardAmount, _rolloverArgs.atmId);

            }

            TransferHelper.safeTransfer(flashToken, _rolloverArgs.borrower, fundsRemaining);

        }

        emit RolloverLoanComplete(
            _rolloverArgs.borrower,
            _rolloverArgs.loanId,
            newLoanId,
            fundsRemaining
        );
    }
}
