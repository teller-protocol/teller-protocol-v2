// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LoanRepaymentInterestCollector is Ownable {
    address public immutable principalToken;

    constructor(address _principalToken) {
        principalToken = _principalToken;
    }

    function collectInterest() external onlyOwner returns (uint256 amount_) {
        amount_ = IERC20(principalToken).balanceOf(address(this));

        //send tokens to the owner (deployer)
        IERC20(principalToken).transfer(address(owner()), amount_);
    }
}
