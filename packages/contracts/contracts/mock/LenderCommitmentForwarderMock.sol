pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT

import "../interfaces/ILenderCommitmentForwarder.sol"; 

contract LenderCommitmentForwarderMock is ILenderCommitmentForwarder {
 
    address lender;

    function setLender(address _lender) public {
        lender = _lender;
    }

    function getCommitmentLender(uint256 _commitmentId) external returns (address){

       return lender;

    }




}
