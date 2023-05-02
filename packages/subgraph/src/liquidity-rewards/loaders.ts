import { Address, BigInt } from "@graphprotocol/graph-ts";

import { Bid, BidReward, Commitment, CommitmentReward, RewardAllocation } from "../../generated/schema";
 

/**
 * @param {string} allocationId - ID of the allocation
 * @returns {RewardAllocation} The RewardAllocation entity 
 */
export function loadRewardAllocation(allocationId: string): RewardAllocation {
  const idString = allocationId;
  let allocation = RewardAllocation.load(idString);

  if (!allocation) {
    allocation = new RewardAllocation(idString);
    allocation.createdAt = BigInt.zero();
    allocation.updatedAt = BigInt.zero();
    allocation.status = "";

    allocation.rewardToken = "";
    allocation.rewardTokenAddress = Address.zero();
    allocation.rewardTokenAmountInitial = BigInt.zero();
    allocation.rewardTokenAmountRemaining = BigInt.zero();

    allocation.allocator="";
    allocation.allocatorAddress = Address.zero();

   // allocation.tokenVolume = "";

    allocation.marketplace = "";
    allocation.marketplaceId = BigInt.zero();

    allocation.requiredPrincipalTokenAddress = Address.zero();
    allocation.requiredCollateralTokenAddress = Address.zero();

    allocation.minimumCollateralPerPrincipalAmount = BigInt.zero();
    allocation.rewardPerLoanPrincipalAmount = BigInt.zero();

    allocation.bidStartTimeMin = BigInt.zero();
    allocation.bidStartTimeMax = BigInt.zero(); 
    allocation.allocationStrategy = "";
   
    allocation.save();
  }
  return allocation;
}

export function getCommitmentRewardId(commitment:Commitment, rewardAllocation:RewardAllocation):string{
  return `${commitment.id.toString()}-${rewardAllocation.id.toString()}`
}

export function loadCommitmentReward(commitment:Commitment, rewardAllocation:RewardAllocation) : CommitmentReward {

  const idString = getCommitmentRewardId(commitment,rewardAllocation);
  let commitmentReward = CommitmentReward.load(idString);

  if(!commitmentReward){
    commitmentReward = new CommitmentReward(idString);

    commitmentReward.createdAt = BigInt.zero();
    commitmentReward.updatedAt = BigInt.zero();

    commitmentReward.reward = rewardAllocation.id.toString();
    commitmentReward.commitment = commitment.id.toString();

    //calculate apr ?? 

    commitmentReward.apy = calculateCommitmentRewardApy(commitment, rewardAllocation);
    //commitmentReward.roi = BigInt.zero();

    commitmentReward.save();
  }

  return commitmentReward

}


/*

 Only valid when the reward token is equal to the principal token 

*/
export function calculateCommitmentRewardApy(commitment:Commitment, rewardAllocation:RewardAllocation) : BigInt {

  let rewardPerPrincipal = rewardAllocation.rewardPerLoanPrincipalAmount;
  let maxLoanAmountForCommitment = commitment.committedAmount;
  
  let maxRewardAmount = rewardAllocation.rewardTokenAmountInitial;

  let rewardTokenAmount = rewardPerPrincipal.times( maxLoanAmountForCommitment );

  if(rewardTokenAmount > maxRewardAmount){
    rewardTokenAmount = maxRewardAmount;
  }

  let commitmentDuration = commitment.maxDuration; //in seconds 

  let roi = (rewardTokenAmount).div(maxLoanAmountForCommitment);

  let ONE_YEAR = 365 * 24 * 60 * 60;

  let apy = BigInt.fromI32(ONE_YEAR).times(roi).div(commitmentDuration);


  return apy 

}


// let bidReward = new BidReward(`${bid.id.toString()}-${rewardAllocation.id.toString()}`);

export function getBidRewardId(bid:Bid, rewardAllocation:RewardAllocation):string{
  return `${bid.id.toString()}-${rewardAllocation.id.toString()}`
}

export function loadBidReward(bid:Bid, rewardAllocation:RewardAllocation) : BidReward {
  const idString = getBidRewardId(bid,rewardAllocation);
  let bidReward = BidReward.load(idString);

  if(!bidReward){
    bidReward = new BidReward(idString);

    bidReward.createdAt = BigInt.zero();
    bidReward.updatedAt = BigInt.zero();

    bidReward.reward = rewardAllocation.id.toString();
    bidReward.bid = bid.id.toString();

    let lenderAddress = bid.lenderAddress 
    let borrowerAddress = bid.borrowerAddress

    if(lenderAddress && borrowerAddress){

        //User.load
    if(rewardAllocation.allocationStrategy == "BORROWER"){
     
      bidReward.user = borrowerAddress.toHexString(); ///bid.borrower.user.id.toString();
      
    }else{
     
      bidReward.user = lenderAddress.toHexString(); ///bid.lender.user.id.toString();
      
    }
    

    }
  
    
 

    bidReward.save();
  }

  return bidReward;
} 