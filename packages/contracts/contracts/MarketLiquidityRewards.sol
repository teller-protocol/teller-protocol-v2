// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


/*
- Claim reward for a loan based on loanId (use a brand new contract)
- This contract holds the reward tokens in escrow.
- There will be an allocateReward() function, only called by marketOwner, deposits tokens in escrow
- There will be a claimReward() function -> reads state of loans , only called by borrower -> withdraws tokens from escrow and makes those loans as having claimed rewards
- unallocateReward()

This contract could give out 1 OHM when someone takes out a loan (for every 1000 USDC)


*/
 
contract MarketLiquidityRewards is 
InitializableUpgradeable
{
    address constant tellerV2;
    address constant marketRegistry;


    //marketId => rewardAllocation
    mapping(uint256 => RewardAllocation) public allocatedRewards;

    //bidId => rewardWasClaimed 
    mapping(uint256 => bool) public rewardClaimedForBid;

    struct RewardAllocation {
        address tokenAddress;
        uint256 tokenAmount;
    } 

    modifier onlyMarketOwner(uint256 _marketId){

    }

    constructor(address _tellerV2, address _marketRegistry) {
        tellerV2 = _tellerV2;
        marketRegistry = _marketRegistry;
    }

    function initialize() external initializer {
 
    }


    function allocateRewardsForMarket(
        uint256 _marketId,
        address _tokenAddress,
        uint256 _tokenAmount 
    ) onlyMarketOwner(_marketId) external { 

        require( allocatedRewards[_marketId].tokenAddress == address(0) || allocatedRewards[_marketId].tokenAddress == _tokenAddress, "Cannot change allocated token address.");

        IERC20(_tokenAddress).transferFrom( _msgSender() , _tokenAmount, address(this) );

         allocatedRewards[_marketId] = RewardAllocation({
            tokenAddress: address(_tokenAddress),
            tokenAmount: ( allocatedRewards[_marketId].tokenAmount ) + _tokenAmount  
        });

    }

    function deallocateRewardsForMarket(
        uint256 _marketId
    ) onlyMarketOwner(_marketId) external {

        IERC20(allocatedRewards[_marketId].tokenAddress).transfer( _msgSender() , allocatedRewards[_marketId].tokenAmount );

        allocatedRewards[_marketId] = RewardAllocation({
            tokenAddress: address(0),
            tokenAmount: 0
        });


    }


    function claimRewards(
        uint256 _bidId
    ) external {

         
        require(!rewardClaimedForBid[_bid],"reward already claimed");
        rewardClaimedForBid[_bid] = true;

        LoanData storage loanData = ITellerV2(tellerV2).bids[_bidId] ;  

        //require that msgsender is the loan borrower 


        //transfer token to the msgsender 
      //  IERC20(  ).transfer(   )


    }




}
