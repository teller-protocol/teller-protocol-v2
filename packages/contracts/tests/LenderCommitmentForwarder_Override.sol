// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../contracts/TellerV2MarketForwarder.sol";

import "../contracts/TellerV2Context.sol";

import { Testable } from "./Testable.sol";
import { LenderCommitmentForwarder } from "../contracts/LenderCommitmentForwarder.sol";

import { Collateral, CollateralType } from "../contracts/interfaces/escrow/ICollateralEscrowV1.sol";

import { User } from "./Test_Helpers.sol";

import "../contracts/mock/MarketRegistryMock.sol";

contract LenderCommitmentForwarder_Override is LenderCommitmentForwarder {
    bool public submitBidWasCalled;
    bool public submitBidWithCollateralWasCalled;
    bool public acceptBidWasCalled;

    constructor(address tellerV2, address marketRegistry)
        LenderCommitmentForwarder(tellerV2, marketRegistry)
    {}

    function setCommitment(uint256 _commitmentId, Commitment memory _commitment)
        public
    {
        commitments[_commitmentId] = _commitment;
    }

    function getCommitmentLender(uint256 _commitmentId)
        public
        returns (address)
    {
        return commitments[_commitmentId].lender;
    }

    function getCommitmentMarketId(uint256 _commitmentId)
        public
        returns (uint256)
    {
        return commitments[_commitmentId].marketId;
    }

    function _decrementCommitmentSuper(
        uint256 _commitmentId,
        uint256 _tokenAmountDelta
    ) public {
        super._decrementCommitment(_commitmentId, _tokenAmountDelta);
    }

    function _getEscrowCollateralTypeSuper(CommitmentCollateralType _type)
        public
        returns (CollateralType)
    {
        return super._getEscrowCollateralType(_type);
    }

    function validateCommitmentSuper(uint256 _commitmentId) public {
        super.validateCommitment(commitments[_commitmentId]);
    }

    function getCommitmentMaxPrincipal(uint256 _commitmentId)
        public
        returns (uint256)
    {
        return commitments[_commitmentId].maxPrincipal;
    }

    function _submitBidFromCommitmentSuper(
        address _borrower,
        uint256 _marketId,
        address _principalTokenAddress,
        uint256 _principalAmount,
        address _collateralTokenAddress,
        uint256 _collateralAmount,
        uint256 _collateralTokenId,
        CommitmentCollateralType _collateralTokenType,
        uint32 _loanDuration,
        uint16 _interestRate
    ) public returns (uint256 bidId) {
        return
            super._submitBidFromCommitment(
                _borrower,
                _marketId,
                _principalTokenAddress,
                _principalAmount,
                _collateralTokenAddress,
                _collateralAmount,
                _collateralTokenId,
                _collateralTokenType,
                _loanDuration,
                _interestRate
            );
    }

    /*
        Overrider methods 
    */

    function _submitBid(CreateLoanArgs memory, address)
        internal
        override
        returns (uint256 bidId)
    {
        submitBidWasCalled = true;
        return 1;
    }

    function _submitBidWithCollateral(
        CreateLoanArgs memory,
        Collateral[] memory,
        address
    ) internal override returns (uint256 bidId) {
        submitBidWithCollateralWasCalled = true;
        return 1;
    }

    function _acceptBid(uint256, address) internal override returns (bool) {
        acceptBidWasCalled = true;

        return true;
    }
}

contract LenderCommitmentForwarderTest_TellerV2Mock is TellerV2Context {
    constructor() TellerV2Context(address(0)) {}

    function getSenderForMarket(uint256 _marketId)
        external
        view
        returns (address)
    {
        return _msgSenderForMarket(_marketId);
    }

    function getDataForMarket(uint256 _marketId)
        external
        view
        returns (bytes calldata)
    {
        return _msgDataForMarket(_marketId);
    }
}
