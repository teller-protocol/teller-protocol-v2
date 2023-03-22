// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../contracts/TellerV2MarketForwarder.sol";

import "./resolvers/TestERC20Token.sol";
import "../contracts/TellerV2Context.sol";

import { Testable } from "./Testable.sol";

import { Collateral, CollateralType } from "../contracts/interfaces/escrow/ICollateralEscrowV1.sol";

import { User } from "./Test_Helpers.sol";

import "../contracts/mock/MarketRegistryMock.sol";
import "../contracts/mock/CollateralManagerMock.sol";

import "../contracts/MarketLiquidityRewards.sol";

contract MarketLiquidityRewards_Override is MarketLiquidityRewards {
    

    uint256 immutable startTime = 1678122531;

    //  address tokenAddress;
    uint256 marketId;
    uint256 maxAmount;

    address[] emptyArray;
    address[] borrowersArray;

    uint32 maxLoanDuration;
    uint16 minInterestRate;
    uint32 expiration;

 
    bool verifyLoanStartTimeWasCalled;
    bool verifyExpectedTokenAddressWasCalled;

    bool verifyRewardRecipientWasCalled;
    bool verifyCollateralAmountWasCalled;

    constructor(address tellerV2, address marketRegistry, address collateralManager)
        MarketLiquidityRewards(
           tellerV2,marketRegistry,collateralManager
        )
    {}

     


    //overrides 

    function allocateRewards(
        MarketLiquidityRewards.RewardAllocation calldata _allocation
    ) public override returns (uint256 allocationId_) {
        super.allocateRewards(_allocation);
    }

    function increaseAllocationAmount(
        uint256 _allocationId,
        uint256 _tokenAmount
    ) public override {
        super.increaseAllocationAmount(_allocationId, _tokenAmount);
    }

    function deallocateRewards(uint256 _allocationId, uint256 _tokenAmount)
        public
        override
    {
        super.deallocateRewards(_allocationId, _tokenAmount);
    }

    function _verifyAndReturnRewardRecipient(
        AllocationStrategy strategy,
        BidState bidState,
        address borrower,
        address lender
    ) internal override returns (address rewardRecipient) {
        verifyRewardRecipientWasCalled = true;
        return address(borrower);
    }

    function _verifyCollateralAmount(
        address _collateralTokenAddress,
        uint256 _collateralAmount,
        address _principalTokenAddress,
        uint256 _principalAmount,
        uint256 _minimumCollateralPerPrincipalAmount
    ) internal override {
        verifyCollateralAmountWasCalled = true;
    }

    function _verifyLoanStartTime(
        uint32 loanStartTime,
        uint32 minStartTime,
        uint32 maxStartTime
    ) internal override {
        verifyLoanStartTimeWasCalled = true;
    }

    function _verifyExpectedTokenAddress(
        address loanTokenAddress,
        address expectedTokenAddress
    ) internal override {
        verifyExpectedTokenAddressWasCalled = true;
    }
}
 