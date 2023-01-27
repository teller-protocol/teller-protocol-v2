pragma solidity ^0.8.0;
// SPDX-License-Identifier: MIT

import "@mangrovedao/hardhat-test-solidity/test.sol";

import "./Testable.sol";
import "../TellerV2.sol";

contract NextDueDate_Test is Testable, TellerV2 {
    Bid __bid;

    constructor() TellerV2(address(0)) {
        __bid.loanDetails.principal = 10000e6; // 10k USDC
        __bid.loanDetails.loanDuration = 365 days * 2; // 2 years
        __bid.terms.paymentCycle = 30 days; // 1 month
        __bid.terms.APR = 450; // 4.5%
        __bid.state = BidState.ACCEPTED;
    }

    function _01_nextDueDate_test() public {
        __bid.loanDetails.acceptedTimestamp = uint32(
            BokkyPooBahsDateTimeLibrary.timestampFromDate(2020, 1, 31) // Leap year
        );
        bids[1] = __bid;
        bidPaymentCycleType[1] = PaymentCycleType.Monthly;
        // Expected date is Feb 29th
        uint32 expectedDate = uint32(
            BokkyPooBahsDateTimeLibrary.timestampFromDate(2020, 2, 29)
        );
        nextDueDate_runner(expectedDate);
    }

    function _02_nextDueDate_test() public {
        __bid.loanDetails.acceptedTimestamp = uint32(
            BokkyPooBahsDateTimeLibrary.timestampFromDate(2020, 2, 29)
        );
        bids[1] = __bid;
        bidPaymentCycleType[1] = PaymentCycleType.Monthly;
        // Expected date is March 29th
        uint32 expectedDate = uint32(
            BokkyPooBahsDateTimeLibrary.timestampFromDate(2020, 3, 29)
        );
        nextDueDate_runner(expectedDate);
    }

    function nextDueDate_runner(uint256 _expected) private {
        uint256 nextDueDate = calculateNextDueDate(1);
        Test.eq(nextDueDate, _expected, "Next due date incorrect");
    }
}
