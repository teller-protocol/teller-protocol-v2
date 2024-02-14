// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { LenderCommitmentGroup_Smart } from "../../../../contracts/LenderCommitmentForwarder/extensions/LenderCommitmentGroup/LenderCommitmentGroup_Smart.sol";

contract LenderCommitmentGroup_Smart_Override is LenderCommitmentGroup_Smart {
    //  bool public submitBidWasCalled;
    // bool public submitBidWithCollateralWasCalled;
    //  bool public acceptBidWasCalled;

    uint256 mockMaxPrincipalPerCollateralAmount;
    uint256 mockSharesExchangeRate;
    int256 mockMinimumAmountDifferenceToCloseDefaultedLoan;

    constructor(address _tellerV2, address _smartCommitmentForwarder, address _uniswapV3Pool)
        LenderCommitmentGroup_Smart(_tellerV2,_smartCommitmentForwarder, _uniswapV3Pool)
    {}

    function set_mockSharesExchangeRate(uint256 _mockRate) public {
        mockSharesExchangeRate = _mockRate;
    }

       function set_mockBidAsActiveForGroup(uint256 _bidId,bool _active) public {
        activeBids[_bidId] = _active;
    }
 


     function mock_setMinimumAmountDifferenceToCloseDefaultedLoan(
        int256 _amt
    ) external   returns (uint256){
       mockMinimumAmountDifferenceToCloseDefaultedLoan = _amt;
    } 


    function getMinimumAmountDifferenceToCloseDefaultedLoan(
        uint256 _bidId,
        uint256 _amountOwed,
        uint256 _loanDefaultedTimestamp
    ) public view override returns (int256 amountDifference_ ) {

        return mockMinimumAmountDifferenceToCloseDefaultedLoan;
    }
    
    function super_getMinimumAmountDifferenceToCloseDefaultedLoan(
        uint256 _bidId,
        uint256 _amountOwed,
        uint256 _loanDefaultedTimestamp
    ) public view returns (int256  ) {

        return super.getMinimumAmountDifferenceToCloseDefaultedLoan(_bidId,_amountOwed,_loanDefaultedTimestamp);
    }



    function set_totalPrincipalTokensCommitted(uint256 _mockAmt) public {
        totalPrincipalTokensCommitted = _mockAmt;
    }

    function set_totalInterestCollected(uint256 _mockAmt) public {
        totalInterestCollected = _mockAmt;
    }

    function set_principalTokensCommittedByLender(
        address lender,
        uint256 _mockAmt
    ) public {
        principalTokensCommittedByLender[lender] = _mockAmt;
    }

    function mock_mintShares(address _sharesRecipient, uint256 _mockAmt)
        public
    {
        poolSharesToken.mint(_sharesRecipient, _mockAmt);
    }

    function set_mock_getMaxPrincipalPerCollateralAmount(uint256 amt) public {
        mockMaxPrincipalPerCollateralAmount = amt;
    }



    function sharesExchangeRate() public override view returns (uint256 rate_) {
        return mockSharesExchangeRate;
    }


    function super_sharesExchangeRate(  ) public view returns (uint256) {

        return super.sharesExchangeRate();
    }



    function super_sharesExchangeRateInverse(  ) public view returns (uint256) {

        return super.sharesExchangeRateInverse();
    }

    /*
    function _getMaxPrincipalPerCollateralAmount(  ) internal override view  returns (uint256) {

       return mockMaxPrincipalPerCollateralAmount ;

    }

    function _super_getMaxPrincipalPerCollateralAmount(  ) public view  returns (uint256) {

       return super._getMaxPrincipalPerCollateralAmount() ;

    }*/
}
