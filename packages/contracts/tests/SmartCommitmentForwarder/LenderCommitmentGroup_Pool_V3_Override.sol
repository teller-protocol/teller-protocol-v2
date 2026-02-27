// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { LenderCommitmentGroup_Pool_V3 } from "../../contracts/LenderCommitmentForwarder/extensions/LenderCommitmentGroup/LenderCommitmentGroup_Pool_V3.sol";

contract LenderCommitmentGroup_Pool_V3_Override is LenderCommitmentGroup_Pool_V3 {
    uint256 mockRequiredCollateralAmount;
    uint256 mockSharesExchangeRate;
    int256 mockMinimumAmountDifferenceToCloseDefaultedLoan;

    uint256 mockLoanTotalPrincipalAmount;

    uint256 mockAmountOwedPrincipal;
    uint256 mockAmountOwedInterest;

    bool mockFirstDepositMade;

    constructor(address _tellerV2, address _smartCommitmentForwarder)
        LenderCommitmentGroup_Pool_V3(_tellerV2, _smartCommitmentForwarder)
    {}

    function set_mockSharesExchangeRate(uint256 _mockRate) public {
        mockSharesExchangeRate = _mockRate;
    }

    function set_mockBidAsActiveForGroup(uint256 _bidId, bool _active) public {
        activeBids[_bidId] = _active;
    }

    function mock_setMinimumAmountDifferenceToCloseDefaultedLoan(
        int256 _amt
    ) external {
        mockMinimumAmountDifferenceToCloseDefaultedLoan = _amt;
    }

    function getMinimumAmountDifferenceToCloseDefaultedLoan(
        uint256 _amountOwed,
        uint256 _loanDefaultedTimestamp
    ) public view override returns (int256 amountDifference_) {
        return mockMinimumAmountDifferenceToCloseDefaultedLoan;
    }

    function super_getMinimumAmountDifferenceToCloseDefaultedLoan(
        uint256 _amountOwed,
        uint256 _loanDefaultedTimestamp
    ) public view returns (int256) {
        return super.getMinimumAmountDifferenceToCloseDefaultedLoan(_amountOwed, _loanDefaultedTimestamp);
    }

    function _getAmountOwedForBid(uint256 _bidId)
        internal view override returns (uint256, uint256) {
        return (mockAmountOwedPrincipal, mockAmountOwedInterest);
    }

    function set_mockAmountOwedForBid(uint256 _principal, uint256 _interest) public {
        mockAmountOwedPrincipal = _principal;
        mockAmountOwedInterest = _interest;
    }

    function _getLoanTotalPrincipalAmount(uint256 _bidId)
        internal view override returns (uint256) {
        return mockLoanTotalPrincipalAmount;
    }

    function set_mockLoanTotalPrincipalAmount(uint256 _principal) public {
        mockLoanTotalPrincipalAmount = _principal;
    }

    function set_mockActiveBidsAmountDueRemaining(uint256 _bidId, uint256 _amount) public {
        activeBidsAmountDueRemaining[_bidId] = _amount;
    }

    function set_totalPrincipalTokensLended(uint256 _mockAmt) public {
        totalPrincipalTokensLended = _mockAmt;
    }

    function set_totalPrincipalTokensRepaid(uint256 _mockAmt) public {
        totalPrincipalTokensRepaid = _mockAmt;
    }

    function set_totalPrincipalTokensCommitted(uint256 _mockAmt) public {
        totalPrincipalTokensCommitted = _mockAmt;
    }

    function set_totalPrincipalTokensWithdrawn(uint256 _mockAmt) public {
        totalPrincipalTokensWithdrawn = _mockAmt;
    }

    function set_totalInterestCollected(uint256 _mockAmt) public {
        totalInterestCollected = _mockAmt;
    }

    function set_tokenDifferenceFromLiquidations(int256 _mockAmt) public {
        tokenDifferenceFromLiquidations = _mockAmt;
    }

    function set_mock_requiredCollateralAmount(uint256 amt) public {
        mockRequiredCollateralAmount = amt;
    }

    function force_mint_shares(address guy, uint256 wad) public {
        return super.mintShares(guy, wad);
    }

    function force_set_withdraw_delay(uint256 _delay) public {
        withdrawDelayTimeSeconds = _delay;
    }

    function force_set_firstDepositMade(bool _made) public {
        firstDepositMade = _made;
    }

    function sharesExchangeRate() public view override returns (uint256 rate_) {
        if (mockSharesExchangeRate > 0) {
            return mockSharesExchangeRate;
        }
        return super.sharesExchangeRate();
    }

    function super_sharesExchangeRate() public view returns (uint256) {
        return super.sharesExchangeRate();
    }

    function super_sharesExchangeRateInverse() public view returns (uint256) {
        return super.sharesExchangeRateInverse();
    }

    function mock_setBidActive(uint256 _bidId) public {
        activeBids[_bidId] = true;
    }

    function getRequiredCollateral(
        uint256 _principalAmount,
        uint256 maxPrincipalPerCollateralAmount
    ) internal view override returns (uint256) {
        return mockRequiredCollateralAmount;
    }

    function public_getPoolTotalEstimatedValue() public view returns (uint256) {
        return getPoolTotalEstimatedValue();
    }
}
