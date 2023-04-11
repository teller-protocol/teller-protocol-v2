import { BigInt, Bytes } from "@graphprotocol/graph-ts";

import {
  CreatedAllocation,
  IncreasedAllocation,
  DecreasedAllocation,
  UpdatedAllocation,
  DeletedAllocation,
  ClaimedRewards
} from "../../generated/MarketLiquidityRewards/MarketLiquidityRewards";
import { Bid } from "../../generated/schema";
import { loadBidById } from "../helpers/loaders";

import { loadRewardAllocation } from "./loaders";
import { /*updateRewardAllocationStatus, */ updateRewardAllocation } from "./updaters";
//import { RewardAllocationStatus } from "./utils";

export function handleCreatedAllocation(event: CreatedAllocation): void {
  const allocationId = event.params.allocationId.toString();
  const allocation = updateRewardAllocation(
    allocationId,
 //   event.params.allocator,
 //   event.params.marketId.toString(),
 //   event.params.lendingToken,
 //   event.params.tokenAmount,
    event.address,
    event.block
  );

  allocation.createdAt = event.block.timestamp;

  allocation.save();
}

export function handleCreatedAllocations(events: CreatedAllocation[]): void {
  events.forEach(event => {
    handleCreatedAllocation(event);
  });
}

export function handleUpdatedAllocation(event: UpdatedAllocation): void {
  const allocationId = event.params.allocationId.toString();
  updateRewardAllocation(
    allocationId,
    
    event.address,
    event.block
  );
}

export function handleUpdatedAllocations(events: UpdatedAllocation[]): void {
  events.forEach(event => {
    handleUpdatedAllocation(event);
  });
}

export function handleDeletedAllocation(event: DeletedAllocation): void {
  const allocationId = event.params.allocationId.toString();
  const commitment = loadRewardAllocation(allocationId);

  updateCommitmentStatus(commitment, CommitmentStatus.Deleted);

  commitment.expirationTimestamp = BigInt.zero();
  commitment.maxDuration = BigInt.zero();
  commitment.minAPY = BigInt.zero();
  commitment.maxPrincipalPerCollateralAmount = BigInt.zero();
  commitment.save();
}

export function handleDeletedAllocations(events: DeletedAllocation[]): void {
  events.forEach(event => {
    handleDeletedAllocation(event);
  });
}





export function handleClaimedReward(event: ClaimedRewards): void {
  const allocationId = event.params.allocationId.toString();
  const allocation = loadRewardAllocation(allocationId);

  if (event.params.tokenAmount.equals(allocation.committedAmount)) {
    updateCommitmentStatus(commitment, CommitmentStatus.Drained);
  }

  // Link commitment to bid
  const bid: Bid = loadBidById(event.params.bidId);
  bid.commitment = commitment.id;
  bid.commitmentId = commitment.id;

  bid.save();
  allocation.save();
}

 

export function handleClaimedRewards(
  events: ClaimedRewards[]
): void {
  events.forEach(event => {
    handleClaimedReward(event);
  });
}

/*
export function handeUpdatedCommitmentBorrower(
  event: UpdatedCommitmentBorrowers
): void {
  const commitmentId = event.params.commitmentId.toString();
  const commitment = loadCommitment(commitmentId);
  const lenderCommitmentForwarderInstance = LenderCommitmentForwarder.bind(
    event.address
  );
  const borrowers = lenderCommitmentForwarderInstance.getCommitmentBorrowers(
    BigInt.fromString(commitmentId)
  );
  if (borrowers) {
    commitment.commitmentBorrowers = changetype<Bytes[]>(borrowers);
  }
  commitment.save();
}

export function handeUpdatedCommitmentBorrowers(
  events: UpdatedCommitmentBorrowers[]
): void {
  events.forEach(event => {
    handeUpdatedCommitmentBorrower(event);
  });
}
*/