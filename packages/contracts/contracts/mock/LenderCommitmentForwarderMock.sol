pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT

import "../interfaces/ILenderCommitmentForwarder.sol"; 

contract LenderCommitmentForwarderMock is ILenderCommitmentForwarder {
 
    address lender;

    function setLender(address _lender) public {
        _lender = lender;
    }

    function getCommitmentLender(uint256 _commitmentId) external returns (address lender_){

        return  lender;

    }




}
