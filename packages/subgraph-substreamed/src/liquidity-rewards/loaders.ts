import { Address, BigInt } from "@graphprotocol/graph-ts";

import {
  Bid,
  BidReward,
  Commitment,
  CommitmentReward,
  RewardAllocation
} from "../../generated/schema";

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

    allocation.allocator = "";
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

    allocation.bidRewards = [];

    allocation.save();
  }
  return allocation;
}

export function getCommitmentRewardId(
  commitment: Commitment,
  rewardAllocation: RewardAllocation
): string {
  return `${commitment.id.toString()}-${rewardAllocation.id.toString()}`;
}

export function loadCommitmentReward(
  commitment: Commitment,
  rewardAllocation: RewardAllocation
): CommitmentReward {
  const idString = getCommitmentRewardId(commitment, rewardAllocation);
  let commitmentReward = CommitmentReward.load(idString);

  if (!commitmentReward) {
    commitmentReward = new CommitmentReward(idString);

    commitmentReward.createdAt = BigInt.zero();
    commitmentReward.updatedAt = BigInt.zero();

    commitmentReward.reward = rewardAllocation.id.toString();
    commitmentReward.commitment = commitment.id.toString();

    commitmentReward.roi = calculateCommitmentRewardRoi(
      commitment,
      rewardAllocation,
      rewardAllocation.rewardTokenAddress == commitment.principalTokenAddress
    );

    commitmentReward.apy = calculateCommitmentRewardApy(
      commitment,
      rewardAllocation,
      rewardAllocation.rewardTokenAddress == commitment.principalTokenAddress
    );

    commitmentReward.save();
  }

  return commitmentReward;
}

export function calculateCommitmentRewardRoi(
  commitment: Commitment,
  rewardAllocation: RewardAllocation,
  rewardTokenMatchesPrincipalToken: boolean
): BigInt {
  const EXPANSION_PERCENT = BigInt.fromI32(10000);

  const rewardPerPrincipal = rewardAllocation.rewardPerLoanPrincipalAmount;
  const maxLoanAmountForCommitment = commitment.committedAmount;

  const maxRewardAmount = rewardAllocation.rewardTokenAmountInitial;

  let rewardTokenAmount = rewardPerPrincipal.times(maxLoanAmountForCommitment);

  const commitmentDuration = commitment.maxDuration; // in seconds

  if (rewardTokenAmount > maxRewardAmount) {
    rewardTokenAmount = maxRewardAmount;
  }

  if (
    commitmentDuration == BigInt.zero() ||
    maxLoanAmountForCommitment == BigInt.zero()
  ) {
    return BigInt.zero();
  }

  if (rewardTokenMatchesPrincipalToken) {
    const roi = rewardTokenAmount
      .times(EXPANSION_PERCENT)
      .div(maxLoanAmountForCommitment);

    return roi;
  } else {
    const collateralToken = commitment.collateralToken;
    const maxPrincipalPerCollateralAmount =
      commitment.maxPrincipalPerCollateralAmount;

    if (!collateralToken || !maxPrincipalPerCollateralAmount) {
      return BigInt.zero();
    }

    const rewardInPrincipalTokens = rewardTokenAmount.times(
      maxPrincipalPerCollateralAmount
    );

    const roi = rewardInPrincipalTokens
      .times(EXPANSION_PERCENT)
      .div(maxLoanAmountForCommitment);

    return roi;
  }
}

export function calculateCommitmentRewardApy(
  commitment: Commitment,
  rewardAllocation: RewardAllocation,
  rewardTokenMatchesPrincipalToken: boolean
): BigInt {
  const commitmentDuration = commitment.maxDuration; // in seconds
  const ONE_YEAR = 365 * 24 * 60 * 60;

  if (commitmentDuration == BigInt.zero()) {
    return BigInt.zero();
  }

  const roi = calculateCommitmentRewardRoi(
    commitment,
    rewardAllocation,
    rewardTokenMatchesPrincipalToken
  );

  const apy = BigInt.fromI32(ONE_YEAR)
    .times(roi)
    .div(commitmentDuration);

  return apy;
}

// let bidReward = new BidReward(`${bid.id.toString()}-${rewardAllocation.id.toString()}`);

export function getBidRewardId(
  bid: Bid,
  rewardAllocation: RewardAllocation
): string {
  return `${bid.id.toString()}-${rewardAllocation.id.toString()}`;
}

export function loadBidReward(
  bid: Bid,
  rewardAllocation: RewardAllocation
): BidReward {
  const idString = getBidRewardId(bid, rewardAllocation);
  let bidReward = BidReward.load(idString);

  if (!bidReward) {
    bidReward = new BidReward(idString);

    bidReward.createdAt = BigInt.zero();
    bidReward.updatedAt = BigInt.zero();

    bidReward.reward = rewardAllocation.id.toString();
    bidReward.bid = bid.id.toString();

    bidReward.claimed = false;

    const lenderAddress = bid.lenderAddress;
    const borrowerAddress = bid.borrowerAddress;

    if (lenderAddress && borrowerAddress) {
      // User.load
      if (rewardAllocation.allocationStrategy == "BORROWER") {
        bidReward.user = borrowerAddress.toHexString(); // /bid.borrower.user.id.toString();
      } else {
        bidReward.user = lenderAddress.toHexString(); // /bid.lender.user.id.toString();
      }
    }

    bidReward.save();
  }

  return bidReward;
}
