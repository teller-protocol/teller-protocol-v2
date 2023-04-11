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
import { /*updateRewardAllocationStatus, */ createRewardAllocation, updateAllocationStatus, updateRewardAllocation } from "./updaters";
import { AllocationStatus } from "./utils";
//import { RewardAllocationStatus } from "./utils";

export function handleCreatedAllocation(event: CreatedAllocation): void {
  const allocationId = event.params.allocationId.toString();
  const allocation = createRewardAllocation(
    allocationId,
    event.params.allocator,
    event.params.marketId.toString(),
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

export function handleIncreasedAllocation(event: UpdatedAllocation): void {
  const allocationId = event.params.allocationId.toString();
  updateRewardAllocation(
    allocationId,    
    event.address,
    event.block
  );
}

export function handleIncreasedAllocations(events: UpdatedAllocation[]): void {
  events.forEach(event => {
    handleIncreasedAllocation(event);
  });
}


export function handleDecreasedAllocation(event: UpdatedAllocation): void {
  const allocationId = event.params.allocationId.toString();
  updateRewardAllocation(
    allocationId,    
    event.address,
    event.block
  );
}

export function handleDecreasedAllocations(events: UpdatedAllocation[]): void {
  events.forEach(event => {
    handleDecreasedAllocation(event);
  });
}

export function handleDeletedAllocation(event: DeletedAllocation): void {
  const allocationId = event.params.allocationId.toString();
  const allocation = loadRewardAllocation(allocationId);

  updateAllocationStatus(allocation, AllocationStatus.Deleted);

  allocation.rewardTokenAmountRemaining = BigInt.zero();

  /*allocation.expirationTimestamp = BigInt.zero();
  allocation.maxDuration = BigInt.zero();
  allocation.minAPY = BigInt.zero();
  allocation.maxPrincipalPerCollateralAmount = BigInt.zero();*/
  allocation.save();
}

export function handleDeletedAllocations(events: DeletedAllocation[]): void {
  events.forEach(event => {
    handleDeletedAllocation(event);
  });
}





export function handleClaimedReward(event: ClaimedRewards): void {
  const allocationId = event.params.allocationId.toString();
  const allocation = loadRewardAllocation(allocationId);

 /* if (event.params.tokenAmount.equals(allocation.rewardTokenAmountRemaining)) {
    updateCommitmentStatus(commitment, CommitmentStatus.Drained);
  }*/

  // Link commitment to bid
  /*const bid: Bid = loadBidById(event.params.bidId);
  bid.commitment = allocation.id;
  bid.commitmentId = allocation.id;

  bid.save();*/
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