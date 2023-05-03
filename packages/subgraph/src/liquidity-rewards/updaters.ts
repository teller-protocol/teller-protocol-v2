import { Address, BigInt, ethereum } from "@graphprotocol/graph-ts";

import { MarketLiquidityRewards } from "../../generated/MarketLiquidityRewards/MarketLiquidityRewards";
import { Bid, RewardAllocation, Token, TokenVolume, User, BidCollateral, BidReward, Commitment } from "../../generated/schema";
import { loadBidById, loadLoanStatusCount, loadMarketTokenVolume, loadProtocol, loadToken } from "../helpers/loaders";
import { addToArray, removeFromArray } from "../helpers/utils";
import {bidStatusToString,BidStatus} from "../helpers/bid";

import { loadRewardAllocation, loadBidReward, getBidRewardId, loadCommitmentReward, getCommitmentRewardId } from "./loaders";
import { AllocationStatus, allocationStatusToEnum, allocationStatusToString } from "./utils";
//import { CommitmentStatus, commitmentStatusToString } from "./utils";

import { store } from '@graphprotocol/graph-ts'


enum CollateralTokenType {
  NONE,
  ERC20,
  ERC721,
  ERC1155,
  ERC721_ANY_ID,
  ERC1155_ANY_ID
}


export function updateAllocationStatus(
  allocation: RewardAllocation,
  status: AllocationStatus
): void {
  allocation.status = allocationStatusToString(status);

  switch (status) {
    case AllocationStatus.Active:
   //   addCommitmentToProtocol(commitment);
      break;
    case AllocationStatus.Deleted:
    case AllocationStatus.Drained:
    case AllocationStatus.Expired:
   /*   updateAvailableTokensFromCommitment(
        commitment,
        commitment.committedAmount.neg()
      );
      removeCommitmentToProtocol(commitment);*/

      break;
  }

  allocation.save();
}


 

/**
 * @param {string} allocationId - ID of the commitment
 * @param {Address} allocatorAddress - Address of the allocator
 * @param {string} marketplaceId - ID of the marketplace
 * @param {Address} eventAddress - Address of the emitted event
 * @param {ethereum.Block} eventBlock - Block of the emitted event
 */

export function createRewardAllocation(
  allocationId: string,
  allocatorAddress: Address,
  marketplaceId: string,  
  eventAddress: Address,
  eventBlock: ethereum.Block  
): RewardAllocation {

  const allocation = loadRewardAllocation(allocationId);

  const marketLiquidityRewardsInstance = MarketLiquidityRewards.bind(
    eventAddress
  );
  const allocatedReward = marketLiquidityRewardsInstance.allocatedRewards(
    BigInt.fromString(allocationId)
  );

  let rewardToken = loadToken(allocatedReward.value1).id;
  let requiredPrincipalTokenAddress = allocatedReward.value4;
  let requiredCollateralTokenAddress = allocatedReward.value5;
   

  allocation.allocatorAddress = allocatedReward.value0;
  allocation.rewardTokenAddress = allocatedReward.value1;
  allocation.rewardToken = rewardToken;
  allocation.rewardTokenAmountInitial = allocatedReward.value2;
  allocation.rewardTokenAmountRemaining = allocatedReward.value2;
  allocation.marketplaceId = BigInt.fromString(marketplaceId);
  allocation.requiredPrincipalTokenAddress = requiredPrincipalTokenAddress;
  allocation.requiredCollateralTokenAddress = requiredCollateralTokenAddress;
  allocation.minimumCollateralPerPrincipalAmount = allocatedReward.value6;
  allocation.rewardPerLoanPrincipalAmount = allocatedReward.value7;
  allocation.bidStartTimeMin = allocatedReward.value8;
  allocation.bidStartTimeMax = allocatedReward.value9;
  allocation.allocationStrategy = allocatedReward.value10 == 0 ? "BORROWER" : "LENDER";
  

  allocation.bidRewards = [];
  
  if(requiredPrincipalTokenAddress!= Address.zero()){
    allocation.tokenVolume = loadMarketTokenVolume(requiredPrincipalTokenAddress.toHexString(), marketplaceId.toString()).id;
  }
  
  allocation.save()

 
  updateAllocationStatus(allocation, AllocationStatus.Active);

  return allocation;
}



/**
 * @param {string} allocationId - ID of the commitment
 * @param {Address} eventAddress - Address of the emitted event
 * @param {ethereum.Block} eventBlock - Block of the emitted event
 */
export function updateRewardAllocation(
  allocationId: string,
  eventAddress: Address,
  eventBlock: ethereum.Block
): RewardAllocation {
  const allocation = loadRewardAllocation(allocationId);
 

  const marketLiquidityRewardsInstance = MarketLiquidityRewards.bind(
    eventAddress
  );
  const allocatedReward = marketLiquidityRewardsInstance.allocatedRewards(
    BigInt.fromString(allocationId)
  ); 

  allocation.rewardTokenAmountRemaining = allocatedReward.value2;
   
  allocation.minimumCollateralPerPrincipalAmount = allocatedReward.value6;
  allocation.rewardPerLoanPrincipalAmount = allocatedReward.value7;
  allocation.bidStartTimeMin = allocatedReward.value8;
  allocation.bidStartTimeMax = allocatedReward.value9;

  
  allocation.save();
    

 
  updateAllocationStatus(allocation, AllocationStatus.Active);
 

/*
  const lender = loadLenderByMarketId(lenderAddress, marketId);

  commitment.lender = lender.id;
  commitment.lenderAddress = lender.lenderAddress;
  commitment.marketplace = marketId;
  commitment.marketplaceId = BigInt.fromString(marketId);

  const lenderCommitmentForwarderInstance = LenderCommitmentForwarder.bind(
    eventAddress
  );
  const lenderCommitment = lenderCommitmentForwarderInstance.commitments(
    BigInt.fromString(commitmentId)
  );

  commitment.expirationTimestamp = lenderCommitment.value1;
  commitment.maxDuration = lenderCommitment.value2;
  commitment.minAPY = BigInt.fromI32(lenderCommitment.value3);

  const lendingToken = loadToken(lendingTokenAddress);
  commitment.principalToken = lendingToken.id;
  commitment.principalTokenAddress = lendingTokenAddress;

  if (lenderCommitment.value7 != CollateralTokenType.NONE) {
    let tokenType = TokenType.UNKNOWN;
    let nftId: BigInt | null = null;
    switch (lenderCommitment.value7) {
      case CollateralTokenType.ERC20:
        tokenType = TokenType.ERC20;
        break;
      case CollateralTokenType.ERC721_ANY_ID:
        nftId = lenderCommitment.value5;
      case CollateralTokenType.ERC721:
        tokenType = TokenType.ERC721;
        break;
      case CollateralTokenType.ERC1155_ANY_ID:
        nftId = lenderCommitment.value5;
      case CollateralTokenType.ERC1155:
        tokenType = TokenType.ERC1155;
        break;
    }
    const collateralToken = loadToken(
      lenderCommitment.value4,
      tokenType,
      nftId
    );
    commitment.collateralToken = collateralToken.id;
    commitment.maxPrincipalPerCollateralAmount = lenderCommitment.value6;
  }

  const volume = loadCommitmentTokenVolume(lendingToken.id, commitment);
  commitment.tokenVolume = volume.id;

  commitment.save();

  updateCommitmentStatus(commitment, CommitmentStatus.Active);
  const committedAmountDiff = committedAmount.minus(commitment.committedAmount);
  updateAvailableTokensFromCommitment(commitment, committedAmountDiff);
  */
  return allocation;
}






export function linkRewardToCommitments(rewardAllocation:RewardAllocation) : void {
  /*
    match up based on: 

    market Id 
    principal token address 

  */

    //loop thru all commitments for market 
    
  let protocol = loadProtocol();

  let activeCommitmentIds = protocol.activeCommitments; 


  for(let i = 0; i < activeCommitmentIds.length; i++){

    let commitmentId = activeCommitmentIds[i];
 
    let commitment = Commitment.load(commitmentId)!;

    if(commitment.marketplaceId == rewardAllocation.marketplaceId 
      && commitment.principalTokenAddress == rewardAllocation.requiredPrincipalTokenAddress){

      appendCommitmentReward(commitment, rewardAllocation);
       

    }

  }



}


export function linkCommitmentToRewards(commitment:Commitment) : void {

  let protocol = loadProtocol();

  let activeRewardIds = protocol.activeRewards;


  for(let i = 0; i < activeRewardIds.length; i++){

    let rewardId = activeRewardIds[i];
 
    let rewardAllocation = RewardAllocation.load(rewardId)!;

    if(commitment.marketplaceId == rewardAllocation.marketplaceId 
      && commitment.principalTokenAddress == rewardAllocation.requiredPrincipalTokenAddress){

      appendCommitmentReward(commitment, rewardAllocation);
       

    }

  } 

}


/*
    Creates a new CommitmentReward entity which is the association between a commitment and a reward allocation
*/

export function appendCommitmentReward(commitment:Commitment, rewardAllocation:RewardAllocation) : void {

  const commitmentRewardId = getCommitmentRewardId(commitment,rewardAllocation);

  
  let commitmentReward = loadCommitmentReward(commitment,rewardAllocation);

}
 

/*
RUN THIS FUNCTION : 
 
1. When an allocation is created or updated 


DESCRIPTION: 
This function will loop through all of the bids (matching market id and principal token) in order to update the protocol entity array 
 

verify that the reward is active and has funds remaining 

*/

export function linkRewardToBids(rewardAllocation:RewardAllocation) : void {

  const loansForMarket = loadLoanStatusCount('market',rewardAllocation.marketplaceId.toString());

  const rewardableLoans = loansForMarket.accepted
  .concat(loansForMarket.repaid)
  .concat(loansForMarket.late)
  .concat(loansForMarket.dueSoon)
  .concat(loansForMarket.defaulted)
  .concat(loansForMarket.liquidated)
  
  for(let i = 0; i < rewardableLoans.length; i++){

    let bidId = BigInt.fromString(rewardableLoans[i]);
    let bid = loadBidById(bidId);

    if(rewardAllocation.allocationStrategy == "BORROWER" && 
    !borrowerIsEligibleForRewardWithBidStatus(bid.status) ){
      return 
    }

    if(rewardAllocation.allocationStrategy == "LENDER" && 
    !lenderIsEligibleForRewardWithBidStatus(bid.status) ){
      return 
    }

    //check to see if the bid is eligible for the reward
    
    if( 
      allocationStatusToEnum(rewardAllocation.status) == AllocationStatus.Active &&
       bidIsEligibleForReward(bid,rewardAllocation) 
      ){
        appendAllocationRewardToBidParticipants(bid,rewardAllocation);      
    }

    bid.save()


  }

   
}


/*
  when a bid is accepted or repaid ...


  find all of the allocations that are active , see if the bid can be assigned to the allocation 
*/
export function linkBidToRewards(bid:Bid) : void {
 
  let protocol = loadProtocol();

  let activeRewardIds = protocol.activeRewards; 


 
  for(let i = 0; i < activeRewardIds.length; i++){

    let allocationRewardId = activeRewardIds[i];
 
    let rewardAllocation = RewardAllocation.load(allocationRewardId)!;

    if( 
        allocationStatusToEnum(rewardAllocation.status) == AllocationStatus.Active &&
        bidIsEligibleForReward(bid,rewardAllocation)   
    ){ 
      appendAllocationRewardToBidParticipants(bid,rewardAllocation);       
    }

  }

}


export function unlinkBidsFromReward(reward:RewardAllocation) : void {
  


  let bidRewards = reward.bidRewards ; 

  for(let i = 0; i < bidRewards.length; i++){
      
      let bidRewardId = bidRewards[i];
  
      let bidReward = BidReward.load(bidRewardId)!;

      /*
        Since we cannot access a derived array, we need to manually push and pop bid rewards from rewards 
        Since we cannot remove elements from an array, we have to repopulate the array from scratch each time 
      */
      let rewardAssociations = reward.bidRewards ;
      let updatedAssociationArray = [] as string[];
      for(let j=0; j < rewardAssociations.length ; j++){
        if(rewardAssociations[j] != bidRewardId){
          updatedAssociationArray.push(bidRewardId);
        }
      }

      reward.bidRewards = updatedAssociationArray;
      reward.save();
    
      store.remove('BidReward', bidReward.id);

  }


}

export function unlinkTokenVolumeFromReward(reward:RewardAllocation) : void {
  
  const allocation = loadRewardAllocation(reward.id);
  
  allocation.tokenVolume = null;

  allocation.save()

}

function appendAllocationRewardToBidParticipants(bid: Bid,  rewardAllocation: RewardAllocation):void{
   //create a bid reward entity 
   const bidRewardId = getBidRewardId(bid,rewardAllocation);

   //this created a bidReward which is an attachment of the reward to a bid 
   let bidReward = loadBidReward(bid,rewardAllocation);

    //manually add the association
   rewardAllocation.bidRewards.push(bidReward.id);
   rewardAllocation.save()
   
    
}
 

function bidIsEligibleForReward( bid: Bid,  rewardAllocation: RewardAllocation) : boolean {


 if(bid.marketplaceId != rewardAllocation.marketplaceId){ return false;}
  
 //must use address.zero and not address.empty 
  if(rewardAllocation.requiredPrincipalTokenAddress != Address.zero() &&  bid.lendingTokenAddress != rewardAllocation.requiredPrincipalTokenAddress  ) {return false; }


  if(rewardAllocation.bidStartTimeMin > BigInt.zero() && bid.acceptedTimestamp < rewardAllocation.bidStartTimeMin){ return false }
  if(rewardAllocation.bidStartTimeMax > BigInt.zero() && bid.acceptedTimestamp > rewardAllocation.bidStartTimeMax){ return false }

  
  //filter by collateral requirements!
  if(rewardAllocation.requiredCollateralTokenAddress != Address.zero() && rewardAllocation.minimumCollateralPerPrincipalAmount > BigInt.zero()){

    //make sure the bid has the required collateral, and with enough ratio 

    let hasValidCollateral = false;   

    let bidCollaterals = bid.collateral;

    if(bidCollaterals){
      for(let i=0;i<bidCollaterals.length;i++){
        let bidCollateral = BidCollateral.load(bidCollaterals[i])!;

       
          let principalToken = loadToken(Address.fromString(bid.lendingToken) );
          let principalTokenDecimals = principalToken.decimals;
          if(!principalTokenDecimals){principalTokenDecimals = BigInt.zero();}

          let collateralToken = loadToken(Address.fromString(bidCollateral.token));
          let collateralTokenDecimals = collateralToken.decimals; 
          if(!collateralTokenDecimals){collateralTokenDecimals =  BigInt.zero();} 

          let requiredCollateralAmount = getRequiredCollateralAmount(
            bid.principal,
            rewardAllocation.minimumCollateralPerPrincipalAmount,
            principalTokenDecimals.toI32(),
            collateralTokenDecimals.toI32()            
            );
        
          if( 
          bidCollateral.collateralAddress == rewardAllocation.requiredCollateralTokenAddress 
          && bidCollateral.amount >= requiredCollateralAmount 
          ){
            hasValidCollateral = true; 
            break;
          } 
        
      }
    }

    if(!hasValidCollateral) return false;

  }

  
  
  return true;

}

/*
  Make sure this rounds like the solidity method 
*/
function getRequiredCollateralAmount( principal: BigInt, minimumCollateralPerPrincipalAmount: BigInt, principalTokenDecimals: i32, collateralTokenDecimals:i32 ) : BigInt {
 
  let expansion = BigInt.fromI32(10).pow(  (principalTokenDecimals + collateralTokenDecimals) as u8) ;

  let requiredCollateralAmount = (
    minimumCollateralPerPrincipalAmount * principal / expansion 
  ); 
  
  return requiredCollateralAmount;


}

function borrowerIsEligibleForRewardWithBidStatus( bidStatus: string ) : boolean {

  if(bidStatus == bidStatusToString(BidStatus.Repaid)) return true 

  return false
}

function lenderIsEligibleForRewardWithBidStatus( bidStatus: string ) : boolean  {


  if(bidStatus == bidStatusToString(BidStatus.Repaid)) return true 
  if(bidStatus == bidStatusToString(BidStatus.Defaulted)) return true 
  if(bidStatus == bidStatusToString(BidStatus.Accepted)) return true 
  if(bidStatus == bidStatusToString(BidStatus.DueSoon)) return true 
  if(bidStatus == bidStatusToString(BidStatus.Late)) return true 
  if(bidStatus == bidStatusToString(BidStatus.Liquidated)) return true 
 

  return false
} 