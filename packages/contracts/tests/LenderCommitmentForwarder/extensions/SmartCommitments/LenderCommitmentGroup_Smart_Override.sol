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

    constructor(address _smartCommitmentForwarder, address _uniswapV3Pool)
        LenderCommitmentGroup_Smart(_smartCommitmentForwarder, _uniswapV3Pool)
    {}

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

    /*
    function _getMaxPrincipalPerCollateralAmount(  ) internal override view  returns (uint256) {

       return mockMaxPrincipalPerCollateralAmount ;

    }

    function _super_getMaxPrincipalPerCollateralAmount(  ) public view  returns (uint256) {

       return super._getMaxPrincipalPerCollateralAmount() ;

    }*/
}
