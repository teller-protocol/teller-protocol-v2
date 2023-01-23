pragma solidity >=0.8.0 <0.9.0;

// SPDX-License-Identifier: MIT

// Libraries
import "./NumbersLib.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import { Bid } from "../TellerV2Storage.sol";

enum PaymentType {
    EMI,
    Bullet
}

library V2Calculations {
    using NumbersLib for uint256;

    /**
     * @notice Returns the timestamp of the last payment made for a loan.
     * @param _bid The loan bid struct to get the timestamp for.
     */
    function lastRepaidTimestamp(Bid storage _bid)
    internal
    view
    returns (uint32)
    {
        return
        _bid.loanDetails.lastRepaidTimestamp == 0
        ? _bid.loanDetails.acceptedTimestamp
        : _bid.loanDetails.lastRepaidTimestamp;
    }

    /**
     * @notice Calculates the amount owed for a loan.
     * @param _bid The loan bid struct to get the owed amount for.
     * @param _timestamp The timestamp at which to get the owed amount at.
     */
    function calculateAmountOwed(Bid storage _bid, uint256 _timestamp)
    internal
    view
    returns (
        uint256 owedPrincipal_,
        uint256 duePrincipal_,
        uint256 interest_
    )
    {
        // Total principal left to pay
        return
        calculateAmountOwed(
            _bid.loanDetails.principal,
            _bid.loanDetails.totalRepaid.principal,
            _bid.terms.APR,
            _bid.terms.paymentCycleAmount,
            _bid.terms.paymentCycle,
            lastRepaidTimestamp(_bid),
            _timestamp,
            _bid.loanDetails.acceptedTimestamp,
            _bid.loanDetails.loanDuration,
            _bid.paymentType
        );
    }

    function calculateAmountOwed(
        uint256 principal,
        uint256 totalRepaidPrincipal,
        uint16 _interestRate,
        uint256 _paymentCycleAmount,
        uint256 _paymentCycle,
        uint256 _lastRepaidTimestamp,
        uint256 _timestamp,
        uint256 _startTimestamp,
        uint256 _loanDuration,
        PaymentType _paymentType
    )
    internal
    pure
    returns (
        uint256 owedPrincipal_,
        uint256 duePrincipal_,
        uint256 interest_
    )
    {
        owedPrincipal_ = principal - totalRepaidPrincipal;

        uint256 interestOwedInAYear = owedPrincipal_.percent(_interestRate);
        uint256 owedTime = _timestamp - uint256(_lastRepaidTimestamp);
        interest_ = (interestOwedInAYear * owedTime) / 365 days;

        // Cast to int265 to avoid underflow errors (negative means loan duration has passed)
        int256 durationLeftOnLoan = int256(_loanDuration) -
        (int256(_timestamp) - int256(_startTimestamp));
        bool isLastPaymentCycle = durationLeftOnLoan < int256(_paymentCycle) || // Check if current payment cycle is within or beyond the last one
        owedPrincipal_ + interest_ <= _paymentCycleAmount; // Check if what is left to pay is less than the payment cycle amount

        if (_paymentType == PaymentType.Bullet) {
            if (isLastPaymentCycle) {
                duePrincipal_ = owedPrincipal_;
            }
        } else {
            // Default to PaymentType.EMI
            // Max payable amount in a cycle
            // NOTE: the last cycle could have less than the calculated payment amount
            uint256 maxCycleOwed = isLastPaymentCycle
            ? owedPrincipal_ + interest_
            : _paymentCycleAmount;

            // Calculate accrued amount due since last repayment
            uint256 owedAmount = (maxCycleOwed * owedTime) / _paymentCycle;
            duePrincipal_ = Math.min(owedAmount - interest_, owedPrincipal_);
        }
    }

    /**
     * @notice Calculates the amount owed for a loan for the next payment cycle.
     * @param _type The payment type of the loan.
     * @param _principal The starting amount that is owed on the loan.
     * @param _duration The length of the loan.
     * @param _paymentCycle The length of the loan's payment cycle.
     * @param _apr The annual percentage rate of the loan.
     */
    function calculatePaymentCycleAmount(
        PaymentType _type,
        uint256 _principal,
        uint32 _duration,
        uint32 _paymentCycle,
        uint16 _apr
    ) internal returns (uint256) {
        if (_type == PaymentType.Bullet) {
            return
            _principal.percent(_apr).percent(
                uint256(_paymentCycle).ratioOf(365 days, 10),
                10
            );
        }
        // Default to PaymentType.EMI
        return NumbersLib.pmt(_principal, _duration, _paymentCycle, _apr);
    }
}