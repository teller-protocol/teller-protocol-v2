import { Address, BigInt } from "@graphprotocol/graph-ts";

import { BidReward, RewardAllocation } from "../../generated/schema";
 

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

    allocation.tokenVolume = "";

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


export function loadClaimableReward(claimableRewardId: string) : ClaimableReward {
  const idString = claimableRewardId;
  let claimableReward = ClaimableReward.load(idString);

  if(!claimableReward){
    claimableReward = new ClaimableReward(idString);

    claimableReward.createdAt = BigInt.zero();
    claimableReward.updatedAt = BigInt.zero();

    claimableReward.claimant = "";
    claimableReward.claimantAddress = Address.zero();

    claimableReward.marketplace = "";
    claimableReward.marketplaceId = BigInt.zero();

    claimableReward.rewardToken = "";
    claimableReward.rewardTokenAddress = Address.zero();
    claimableReward.rewardTokenAmount = BigInt.zero();

    claimableReward.hasBeenClaimed = false;

    claimableReward.save();
  }

  return claimableReward;
} 