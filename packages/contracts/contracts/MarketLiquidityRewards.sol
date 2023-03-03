// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./interfaces/IMarketLiquidityRewards.sol";

import "./interfaces/IMarketRegistry.sol";
import "./interfaces/ITellerV2.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
/*
- Claim reward for a loan based on loanId (use a brand new contract)
- This contract holds the reward tokens in escrow.
- There will be an allocateReward() function, only called by marketOwner, deposits tokens in escrow
- There will be a claimReward() function -> reads state of loans , only called by borrower -> withdraws tokens from escrow and makes those loans as having claimed rewards
- unallocateReward()

This contract could give out 1 OHM when someone takes out a loan (for every 1000 USDC)


    ryan ideas : 


    thinking through conditionals we’d add to liquidity mining
1. the claimer could be the lender or borrower  - not yet implemented
ie we might be incentivizing one or the other, or both  (or some other address? idk a use case yet tho)
principalTokenAddress
2.ie the loan had to be made in USDC or x token
collateralTokenAddress
ie Olympus wants to incentivize holders to lock up gOHM as collateral
maxPrincipalPerCollateral
3. ie we might incentivize a collateral ratio greater than or less than some number. or this might be blank (would not use an oracle but raw units ? )

4. make sure loans are REPAID before any reward  ? 

*/
 

 
contract MarketLiquidityRewards is 
IMarketLiquidityRewards,
Initializable
{
    address immutable tellerV2;
    address immutable marketRegistry;

    uint256 allocationCount;
 

    //allocationId => rewardAllocation
    mapping(uint256 => RewardAllocation) public allocatedRewards;

    //bidId => allocationId => rewardWasClaimed 
    mapping(uint256 => mapping(uint256 =>bool) ) public rewardClaimedForBid;

    struct RewardAllocation {
        address allocator;
        uint256 marketId;
        address rewardTokenAddress;
        uint256 rewardTokenAmount;


        //parametersfor loan which affect claimability 
        address requiredPrincipalTokenAddress; //0 for any 
        address requiredCollateralTokenAddress; //0 for any  -- could be an enumerable set?

        uint256 rewardPerLoanPrincipalAmount; 
       
    } 

    modifier onlyMarketOwner(uint256 _marketId){
        require(msg.sender == IMarketRegistry(marketRegistry).getMarketOwner(_marketId), "Only market owner can call this function.");
        _;
    }

    event CreatedAllocation(uint256 allocationId, address allocator, uint256 marketId);

    constructor(address _tellerV2, address _marketRegistry) {
        tellerV2 = _tellerV2;
        marketRegistry = _marketRegistry;
    }

    function initialize() external initializer {
 
    }


/**

 */

    function allocateRewards(
        RewardAllocation calldata _allocation        
    ) public returns (uint256 allocationId_ ) { 

        allocationId_ = allocationCount++;

         require(
            _allocation.allocator == msg.sender,
            "Invalid allocator address"
        );

        IERC20Upgradeable(_allocation.rewardTokenAddress).transferFrom( msg.sender , address(this), _allocation.rewardTokenAmount );

        allocatedRewards[allocationId_] = _allocation ;

          
        emit CreatedAllocation( 
            allocationId_,
            _allocation.allocator,
            _allocation.marketId
        );
    }

    function increaseAllocationAmount(
        uint256 _allocationId,
        uint256 _tokenAmount 
    ) public {
        

        IERC20Upgradeable(allocatedRewards[_allocationId].rewardTokenAddress).transferFrom(msg.sender,address(this),_tokenAmount);
        allocatedRewards[_allocationId].rewardTokenAmount += _tokenAmount;

        //emit event 
    }

    function deallocateRewards(
        uint256 _allocationId,
        uint256 _amount
    ) public {

        require(msg.sender == allocatedRewards[_allocationId].allocator,"Only the allocator can deallocate rewards.");

        //subtract amount reward before transfer 
        allocatedRewards[_allocationId].rewardTokenAmount -= _amount;

        IERC20Upgradeable(allocatedRewards[_allocationId].rewardTokenAddress).transfer(msg.sender , _amount );

         if( allocatedRewards[_allocationId].rewardTokenAmount == 0 ) {
                delete allocatedRewards[_allocationId];
                //emit event 
        }
    

        //emit event 
    }


    function claimRewards(
        uint256 _allocationId,
        uint256 _bidId       
    ) external {

        require(!rewardClaimedForBid[_bidId][_allocationId],"reward already claimed");
        rewardClaimedForBid[_bidId][_allocationId] = true; // leave this here to defend against re-entrancy 

        
 
        //optimize gas by turning these into one single call 

      //  uint256 marketId = ITellerV2(tellerV2).getMarketIdForLoan(_bidId);
       // address borrower = ITellerV2(tellerV2).getBorrowerForLoan(_bidId);
        
        ( address borrower,
            address lender,
            uint256 marketId,
            address principalTokenAddress,
            uint256 principalAmount,
            address collateralTokenAddress,
            uint256 collateralAmount    
        ) = ITellerV2(tellerV2).getLoanSummary(_bidId);
        
        uint256 amountToReward = _calculateRewardAmount(principalAmount);
        
        //require that loan status is PAID (optionally)


        //require that msgsender is the loan borrower 
        require(msg.sender == borrower, "Only the borrower can claim reward.");

        require(marketId == allocatedRewards[_allocationId].marketId, "MarketId mismatch for allocation");

        //transfer tokens reward to the msgsender 
        IERC20Upgradeable(allocatedRewards[_allocationId].rewardTokenAddress).transfer(msg.sender, amountToReward);

        _decrementAllocatedAmount(_allocationId,amountToReward);

        //emit event 

    }   

    function _decrementAllocatedAmount(uint256 _allocationId, uint256 _amount) internal {
        allocatedRewards[_allocationId].rewardTokenAmount -= _amount;
    }

 
    function _calculateRewardAmount(uint256 _loanPrincipal) internal view returns (uint256) {
        
        //change calc -- maybe based on something set by the market owner in teh struct 
       
        return _loanPrincipal / 1000;
    }





}
