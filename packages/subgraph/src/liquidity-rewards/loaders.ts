import { Address, BigInt } from "@graphprotocol/graph-ts";

import { RewardAllocation } from "../../generated/schema";
 

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

    allocation.committedAmount = BigInt.zero();
    allocation.expirationTimestamp = BigInt.zero();
    allocation.maxDuration = BigInt.zero();
    allocation.minAPY = BigInt.zero();
    allocation.lender = "";
    allocation.lenderAddress = Address.zero();
    allocation.marketplace = "";
    allocation.marketplaceId = BigInt.zero();
    allocation.tokenVolume = "";

    allocation.principalToken = "";
    allocation.principalTokenAddress = Address.zero();

    allocation.collateralToken = "";
    allocation.maxPrincipalPerCollateralAmount = BigInt.zero();
    allocation.commitmentBorrowers = [];

    allocation.save();
  }
  return allocation;
}


//export function loadClaimableReward() 