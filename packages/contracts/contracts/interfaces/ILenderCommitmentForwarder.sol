// SPDX-Licence-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

 
interface ILenderCommitmentForwarder {

    function getCommitmentLender(uint256 _commitmentId) external returns (address lender_);

}
