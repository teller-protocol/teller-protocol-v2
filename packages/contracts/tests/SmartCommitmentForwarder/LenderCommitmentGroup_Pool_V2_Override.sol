// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { LenderCommitmentGroup_Pool_V2 } from "../../contracts/LenderCommitmentForwarder/extensions/LenderCommitmentGroup/LenderCommitmentGroup_Pool_V2.sol";

contract LenderCommitmentGroup_Pool_V2_Override is LenderCommitmentGroup_Pool_V2 {
    uint256 mockMaxPrincipalPerCollateralAmount;
    uint256 mockRequiredCollateralAmount;
    uint256 mockSharesExchangeRate;
    int256 mockMinimumAmountDifferenceToCloseDefaultedLoan;

    uint256 mockLoanTotalPrincipalAmount;

    uint256 mockAmountOwedPrincipal;
    uint256 mockAmountOwedInterest;

    address mockToken0;
    address mockToken1;

    constructor(address _tellerV2, address _smartCommitmentForwarder, address _uniswapV3Factory)
        LenderCommitmentGroup_Pool_V2(_tellerV2, _smartCommitmentForwarder, _uniswapV3Factory)
    {}

    function set_mockSharesExchangeRate(uint256 _mockRate) public {
        mockSharesExchangeRate = _mockRate;
    }

    function set_mockBidAsActiveForGroup(uint256 _bidId, bool _active) public {
        activeBids[_bidId] = _active;
    }

    function mock_setMinimumAmountDifferenceToCloseDefaultedLoan(
        int256 _amt
    ) external returns (uint256) {
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

    //function mock_mintShares(address _sharesRecipient, uint256 _mockAmt) public {
    //    poolSharesToken.mint(_sharesRecipient, _mockAmt);
    //}

    function set_mock_getMaxPrincipalPerCollateralAmount(uint256 amt) public {
        mockMaxPrincipalPerCollateralAmount = amt;
    }

    function set_mock_requiredCollateralAmount(uint256 amt) public {
        mockRequiredCollateralAmount = amt;
    }

    function mock_setFirstDepositMade(bool made) public {
        firstDepositMade = made;
    }

    
    // allow tests to drill in and call this internal fn for convenience 
    function force_mint_shares( address guy, uint256 wad ) public  {
        return super.mintShares( guy, wad );
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

    function mock_setPoolTokens(address token0, address token1) public {
        mockToken0 = token0;
        mockToken1 = token1;
    }

    function mock_setBidActive(uint256 _bidId) public {
        activeBids[_bidId] = true;
    }

    function getRequiredCollateral(
        uint256 _principalAmount,
        uint256 maxPrincipalPerCollateralAmount
    ) internal view override returns (uint256 collateralTokensAmountToMatchValue) {
        return mockRequiredCollateralAmount;
    }
    
    // Add public accessor with a different name that calls the internal method
    function public_getPoolTotalEstimatedValue() public view returns (uint256) {
        return getPoolTotalEstimatedValue();
    }
}