import { Address, BigInt, ethereum } from "@graphprotocol/graph-ts";

import { MarketLiquidityRewards } from "../../generated/MarketLiquidityRewards/MarketLiquidityRewards";
import { Bid, RewardAllocation, Token, TokenVolume, User, BidCollateral } from "../../generated/schema";
import { loadBidById, loadLoanStatusCount, loadMarketTokenVolume, loadProtocol, loadToken } from "../helpers/loaders";
import { addToArray, removeFromArray } from "../helpers/utils";
import {bidStatusToString,BidStatus} from "../helpers/bid";

import { loadRewardAllocation, loadBidReward, getBidRewardId } from "./loaders";
import { AllocationStatus, allocationStatusToString } from "./utils";
//import { CommitmentStatus, commitmentStatusToString } from "./utils";

 

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

  allocation.allocatorAddress = allocatedReward.value0;
  allocation.rewardTokenAddress = allocatedReward.value1;
  allocation.rewardToken = loadToken(allocatedReward.value1).id;
  allocation.rewardTokenAmountInitial = allocatedReward.value2;
  allocation.rewardTokenAmountRemaining = allocatedReward.value2;
  allocation.marketplaceId = allocatedReward.value3;
  allocation.requiredPrincipalTokenAddress = allocatedReward.value4;
  allocation.requiredCollateralTokenAddress = allocatedReward.value5;
  allocation.minimumCollateralPerPrincipalAmount = allocatedReward.value6;
  allocation.rewardPerLoanPrincipalAmount = allocatedReward.value7;
  allocation.bidStartTimeMin = allocatedReward.value8;
  allocation.bidStartTimeMax = allocatedReward.value9;
  allocation.allocationStrategy = allocatedReward.value10 == 0 ? "BORROWER" : "LENDER";


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

    //check to see if the bid is eligible for the reward
    
    if( //make this a function later
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

        bidIsEligibleForReward(bid,rewardAllocation)
   
    ){
 
      appendAllocationRewardToBidParticipants(bid,rewardAllocation);

       
    }





  }

}


function appendAllocationRewardToBidParticipants(bid: Bid,  rewardAllocation: RewardAllocation):void{
   //create a bid reward entity 
   const bidRewardId = getBidRewardId(bid,rewardAllocation);
   let bidReward = loadBidReward(bid,rewardAllocation);
   
   /*
   if(  borrowerIsEligibleForRewardWithBidStatus( bid.status ) ) {  //  == BidStatus.Accepted){

   ///this only happens if bid is repaid 
   let borrower = User.load(bid.borrowerAddress.toHexString())!

   let borrowerRewardsArray = borrower.bidRewards;
   borrowerRewardsArray.push(bidReward.id.toString());
   borrower.bidRewards = borrowerRewardsArray;

     //add bid reward to array in here 
   borrower.save()
   }

   if(  lenderIsEligibleForRewardWithBidStatus( bid.status )) { 
   //this happens in more situations 
   let lender = User.load(bid.lenderAddress!.toHexString())!

   //add bid reward to array in here 
   let lenderRewardsArray = lender.bidRewards;
   lenderRewardsArray.push(bidReward.id.toString());
   lender.bidRewards = lenderRewardsArray;

   lender.save()
   }*/
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

       
          let principalToken = Token.load(bid.lendingToken)!;
          let principalTokenDecimals = principalToken.decimals;
          if(!principalTokenDecimals){principalTokenDecimals = BigInt.zero();}

          let collateralToken = Token.load(bidCollateral.token)!;
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