// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


/*
- Claim reward for a loan based on loanId (use a brand new contract)
- This contract holds the reward tokens in escrow.
- There will be an allocateReward() function, only called by marketOwner, deposits tokens in escrow
- There will be a claimReward() function -> reads state of loans , only called by borrower -> withdraws tokens from escrow and makes those loans as having claimed rewards
- unallocateReward()

This contract could give out 1 OHM when someone takes out a loan (for every 1000 USDC)


    ryan ideas : 


    thinking through conditionals we’d add to liquidity mining
the claimer could be the lender or borrower
ie we might be incentivizing one or the other, or both  (or some other address? idk a use case yet tho)
principalTokenAddress
ie the loan had to be made in USDC or x token
collateralTokenAddress
ie Olympus wants to incentivize holders to lock up gOHM as collateral
maxPrincipalPerCollateral
ie we might incentivize a collateral ratio greater than or less than some number. or this might be blank



*/
 
contract MarketLiquidityRewards is 
InitializableUpgradeable
{
    address constant tellerV2;
    address constant marketRegistry;

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


        //parameters for loan which affect claimability 
        address requiredPrincipalTokenAddress; //0 for any 
        address requiredCollateralTokenAddress; //0 for any 

        uint256 rewardPerLoanPrincipalAmount; 
       
    } 

    modifier onlyMarketOwner(uint256 _marketId){
        require(msg.sender == IMarketRegistry(marketRegistry).getMarketOwner(_marketId), "Only market owner can call this function.");
        _;
    }

    constructor(address _tellerV2, address _marketRegistry) {
        tellerV2 = _tellerV2;
        marketRegistry = _marketRegistry;
    }

    function initialize() external initializer {
 
    }


    function allocateRewards(
        uint256 _marketId,
        address _tokenAddress,
        uint256 _tokenAmount 
    ) external { 

        IERC20(_tokenAddress).transferFrom( _msgSender() , _tokenAmount, address(this) );

         allocatedRewards[allocationCount++] = RewardAllocation({
            allocator: _msgSender(),
            marketId: _marketId,
            rewardTokenAddress: address(_tokenAddress),
            rewardTokenAmount:  _tokenAmount  
        });

             //emit event 
    }

    function increaseAllocationAmount(
        uint256 _allocationId,
        uint256 _tokenAmount 
    ) external {

        IERC20(allocatedRewards[_allocationId].rewardTokenAddress).transferFrom(_msgSender(),address(this),_tokenAmount);
        allocatedRewards[_allocationId].rewardTokenAmount += _tokenAmount;

        //emit event 
    }

    function deallocateRewards(
        uint256 _allocationId
    ) external {

        require(_msgSender() == allocatedRewards[_marketId].allocator);

        IERC20(allocatedRewards[_allocationId].rewardTokenAddress).transfer( _msgSender() , allocatedRewards[_marketId].rewardTokenAmount );

        allocatedRewards[_allocationId].rewardTokenAmount = 0;

        delete allocatedRewards[_allocationId];

        //emit event 
    }


    function claimRewards(
        uint256 _allocationId,
        uint256 _bidId       
    ) external {

         
        require(!rewardClaimedForBid[_bid],"reward already claimed");
        rewardClaimedForBid[_bid] = true; // leave this here to defend against re-entrancy 

        LoanData storage loanData = ITellerV2(tellerV2).bids[_bidId] ;  

        uint256 marketId = loanData.marketId;
        address borrower = loanData.borrower;
        uint256 amountToReward = _calculateRewardAmount(loanData.principal);

        //require that msgsender is the loan borrower 
        require(_msgSender() == borrower, "Only the borrower can claim reward.");

        require(marketId == allocatedRewards[_allocationId].marketId, "MarketId mismatch for allocation");

        //transfer tokens reward to the msgsender 
        IERC20(allocatedRewards[_allocationId].tokenAddress).transfer(_msgSender(), amountToReward);

        _decrementAllocatedAmount(_allocationId,amountToReward);

        //emit event 

    }   

    function _decrementAllocatedAmount(uint256 _allocationId, uint256 _amount) internal {
        allocatedRewards[_allocationId].tokenAmount -= _amount;
    }

 
    function _calculateRewardAmount(uint256 _loanPrincipal) internal view returns (uint256) {
        
        //change calc -- maybe based on something set by the market owner in teh struct 
       
        return _loanPrincipal / 1000;
    }





}
