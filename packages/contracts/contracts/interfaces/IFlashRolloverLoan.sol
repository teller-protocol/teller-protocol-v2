// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFlashRolloverLoan {
    struct RolloverCallbackArgs {
        uint256 loanId;
        address borrower;
        uint256 borrowerAmount;
        bytes acceptCommitmentArgs;
    }

     struct AcceptCommitmentArgs {
        uint256 commitmentId;
        uint256 principalAmount;
        uint256 collateralAmount;
        uint256 collateralTokenId;
        address collateralTokenAddress;
        uint16 interestRate;
        uint32 loanDuration;
        bytes32[] merkleProof; //empty array if not used 
    }

}
