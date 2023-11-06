// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
 
import {LenderCommitmentGroup_Smart} from "../../../../contracts/LenderCommitmentForwarder/extensions/LenderCommitmentGroup/LenderCommitmentGroup_Smart.sol";


contract LenderCommitmentGroup_Smart_Override is LenderCommitmentGroup_Smart {
  //  bool public submitBidWasCalled;
   // bool public submitBidWithCollateralWasCalled;
  //  bool public acceptBidWasCalled;

    constructor(
        address _smartCommitmentForwarder, 
        address _uniswapV3Pool
    )
        LenderCommitmentGroup_Smart(
            _smartCommitmentForwarder, 
            _uniswapV3Pool
        )
    {

        
    }


    function set_totalPrincipalTokensCommitted(uint256 _mockAmt) public {
        totalPrincipalTokensCommitted = _mockAmt;

    }

    function set_totalInterestCollected(uint256 _mockAmt) public {
        totalInterestCollected = _mockAmt;
        
    }
   
}
 