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
import { loadBidById, loadProtocol } from "../helpers/loaders";

import { loadBidReward, loadRewardAllocation } from "./loaders";
import {
  createRewardAllocation,
  updateAllocationStatus,
  updateRewardAllocation,
  linkRewardToBids,
  unlinkTokenVolumeFromReward,
  unlinkBidsFromReward,
  linkRewardToCommitments
} from "./updaters";
import { AllocationStatus } from "./utils";

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

  // add rewards to protocol entity
  // if the reward is ever drained completely, can remove it from this array [optimization]

  const protocol = loadProtocol();

  const activeRewardsArray = protocol.activeRewards;
  activeRewardsArray.push(allocation.id);
  protocol.activeRewards = activeRewardsArray;
  protocol.save();

  linkRewardToBids(allocation);
  linkRewardToCommitments(allocation);
}

export function handleCreatedAllocations(events: CreatedAllocation[]): void {
  events.forEach(event => {
    handleCreatedAllocation(event);
  });
}

export function handleUpdatedAllocation(event: UpdatedAllocation): void {
  const allocationId = event.params.allocationId.toString();
  const allocation = updateRewardAllocation(
    allocationId,
    event.address,
    event.block
  );

  linkRewardToBids(allocation);
  linkRewardToCommitments(allocation);
}

export function handleUpdatedAllocations(events: UpdatedAllocation[]): void {
  events.forEach(event => {
    handleUpdatedAllocation(event);
  });
}

export function handleIncreasedAllocation(event: UpdatedAllocation): void {
  const allocationId = event.params.allocationId.toString();
  const allocation = updateRewardAllocation(
    allocationId,
    event.address,
    event.block
  );

  linkRewardToBids(allocation);
  linkRewardToCommitments(allocation);
}

export function handleIncreasedAllocations(events: UpdatedAllocation[]): void {
  events.forEach(event => {
    handleIncreasedAllocation(event);
  });
}

export function handleDecreasedAllocation(event: UpdatedAllocation): void {
  const allocationId = event.params.allocationId.toString();
  const allocation = updateRewardAllocation(
    allocationId,
    event.address,
    event.block
  );

  linkRewardToBids(allocation);
  linkRewardToCommitments(allocation);
}

export function handleDecreasedAllocations(events: UpdatedAllocation[]): void {
  events.forEach(event => {
    handleDecreasedAllocation(event);
  });
}

export function handleDeletedAllocation(event: DeletedAllocation): void {
  const allocationId = event.params.allocationId.toString();
  const allocation = loadRewardAllocation(allocationId);

  allocation.rewardTokenAmountRemaining = BigInt.zero();

  updateAllocationStatus(allocation, AllocationStatus.Deleted);

  allocation.save();
}

export function handleDeletedAllocations(events: DeletedAllocation[]): void {
  events.forEach(event => {
    handleDeletedAllocation(event);
  });
}

// todo
export function handleClaimedReward(event: ClaimedRewards): void {
  const allocationId = event.params.allocationId.toString();

  // update the reward allocation as the amount remaining most likely changed
  const allocation = updateRewardAllocation(
    allocationId,
    event.address,
    event.block
  );

  const bid: Bid = loadBidById(event.params.bidId);

  const rewardRecipient = event.params.recipient;
  const amountRewarded = event.params.amount;

  const bidReward = loadBidReward(bid, allocation);

  bidReward.claimed = true;

  bidReward.save();

  // use the bid and the allocation info to update the BidReward entity status

  /*
  const claimedReward = createClaimedReward(
    allocationId,
    event.params.bidId,
    event.params.recipient,
    event.params.amount,
    event.address,
    event.block
  );*/

  /* if (event.params.tokenAmount.equals(allocation.rewardTokenAmountRemaining)) {
    updateCommitmentStatus(commitment, CommitmentStatus.Drained);
  }*/

  // Link commitment to bid
  /* const bid: Bid = loadBidById(event.params.bidId);
  bid.commitment = allocation.id;
  bid.commitmentId = allocation.id;

  bid.save();*/
  allocation.save();
}

export function handleClaimedRewards(events: ClaimedRewards[]): void {
  events.forEach(event => {
    handleClaimedReward(event);
  });
}
