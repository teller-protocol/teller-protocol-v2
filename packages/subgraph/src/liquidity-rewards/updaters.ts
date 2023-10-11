import { Address, BigInt, ethereum, store } from "@graphprotocol/graph-ts";

import { MarketLiquidityRewards } from "../../generated/MarketLiquidityRewards/MarketLiquidityRewards";
import {
  Bid,
  BidCollateral,
  BidReward,
  Commitment,
  RewardAllocation
} from "../../generated/schema";
import { BidStatus, bidStatusToString } from "../helpers/bid";
import {
  loadBidById,
  loadLoanStatusCount,
  loadMarketTokenVolume,
  loadProtocol,
  loadToken
} from "../helpers/loaders";
import { addToArray, removeFromArray } from "../helpers/utils";

import {
  getBidRewardId,
  loadBidReward,
  loadCommitmentReward,
  loadRewardAllocation
} from "./loaders";
import {
  AllocationStatus,
  allocationStatusToEnum,
  allocationStatusToString
} from "./utils";

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
      unlinkTokenVolumeFromReward(allocation);
      unlinkBidsFromReward(allocation);
      break;
    case AllocationStatus.Drained:
    case AllocationStatus.Expired:
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

  const rewardToken = loadToken(allocatedReward.value1).id;
  const requiredPrincipalTokenAddress = allocatedReward.value4;
  const requiredCollateralTokenAddress = allocatedReward.value5;

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
  allocation.allocationStrategy =
    allocatedReward.value10 == 0 ? "BORROWER" : "LENDER";

  allocation.bidRewards = [];

  if (requiredPrincipalTokenAddress != Address.zero()) {
    const principalTokenId = loadToken(requiredPrincipalTokenAddress);

    const marketTokenVolume = loadMarketTokenVolume(
      principalTokenId.id,
      marketplaceId.toString()
    );

    allocation.tokenVolume = marketTokenVolume.id;
  }

  allocation.save();

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

  if (allocation.rewardTokenAmountRemaining > BigInt.zero()) {
    updateAllocationStatus(allocation, AllocationStatus.Active);
  } else {
    updateAllocationStatus(allocation, AllocationStatus.Drained);
  }

  return allocation;
}

export function linkRewardToCommitments(
  rewardAllocation: RewardAllocation
): void {
  const protocol = loadProtocol();

  const activeCommitmentIds = protocol.activeCommitments;

  for (let i = 0; i < activeCommitmentIds.length; i++) {
    const commitmentId = activeCommitmentIds[i];

    const commitment = Commitment.load(commitmentId)!;

    if (
      commitment.marketplaceId == rewardAllocation.marketplaceId &&
      commitment.principalTokenAddress ==
        rewardAllocation.requiredPrincipalTokenAddress
    ) {
      appendCommitmentReward(commitment, rewardAllocation);
    }
  }
}

export function linkCommitmentToRewards(commitment: Commitment): void {
  const protocol = loadProtocol();

  const activeRewardIds = protocol.activeRewards;

  for (let i = 0; i < activeRewardIds.length; i++) {
    const rewardId = activeRewardIds[i];

    const rewardAllocation = RewardAllocation.load(rewardId)!;

    if (
      commitment.marketplaceId == rewardAllocation.marketplaceId &&
      commitment.principalTokenAddress ==
        rewardAllocation.requiredPrincipalTokenAddress
    ) {
      appendCommitmentReward(commitment, rewardAllocation);
    }
  }
}

/*
    Creates a new CommitmentReward entity which is the association between a commitment and a reward allocation
*/

export function appendCommitmentReward(
  commitment: Commitment,
  rewardAllocation: RewardAllocation
): void {
  loadCommitmentReward(commitment, rewardAllocation);
}

/*
RUN THIS FUNCTION :

1. When an allocation is created or updated


DESCRIPTION:
This function will loop through all of the bids (matching market id and principal token) in order to update the protocol entity array


verify that the reward is active and has funds remaining

*/

export function linkRewardToBids(rewardAllocation: RewardAllocation): void {
  const loansForMarket = loadLoanStatusCount(
    "market",
    rewardAllocation.marketplaceId.toString()
  );

  const rewardableLoans = loansForMarket.accepted
    .concat(loansForMarket.repaid)
    .concat(loansForMarket.late)
    .concat(loansForMarket.dueSoon)
    .concat(loansForMarket.defaulted)
    .concat(loansForMarket.liquidated);

  for (let i = 0; i < rewardableLoans.length; i++) {
    const bidId = BigInt.fromString(rewardableLoans[i]);
    const bid = loadBidById(bidId);

    if (
      rewardAllocation.allocationStrategy == "BORROWER" &&
      !borrowerIsEligibleForRewardWithBidStatus(bid.status)
    ) {
      continue;
    }

    if (
      rewardAllocation.allocationStrategy == "LENDER" &&
      !lenderIsEligibleForRewardWithBidStatus(bid.status)
    ) {
      continue;
    }

    // check to see if the bid is eligible for the reward

    if (
      allocationStatusToEnum(rewardAllocation.status) ==
        AllocationStatus.Active &&
      bidIsEligibleForReward(bid, rewardAllocation)
    ) {
      appendAllocationRewardToBidParticipants(bid, rewardAllocation);
    }

    bid.save();
  }
}

/*
  when a bid is accepted or repaid ...


  find all of the allocations that are active , see if the bid can be assigned to the allocation
*/
export function linkBidToRewards(bid: Bid): void {
  const protocol = loadProtocol();

  const activeRewardIds = protocol.activeRewards;

  for (let i = 0; i < activeRewardIds.length; i++) {
    const allocationRewardId = activeRewardIds[i];

    const rewardAllocation = RewardAllocation.load(allocationRewardId)!;

    if (
      rewardAllocation.allocationStrategy == "BORROWER" &&
      !borrowerIsEligibleForRewardWithBidStatus(bid.status)
    ) {
      continue;
    }

    if (
      rewardAllocation.allocationStrategy == "LENDER" &&
      !lenderIsEligibleForRewardWithBidStatus(bid.status)
    ) {
      continue;
    }

    if (
      allocationStatusToEnum(rewardAllocation.status) ==
        AllocationStatus.Active &&
      bidIsEligibleForReward(bid, rewardAllocation)
    ) {
      appendAllocationRewardToBidParticipants(bid, rewardAllocation);
    }
  }
}

/*
  Unlink bids that are ineligible to claim because its been deleted and not claimed 

  bidreward claimed = false 
  reward has been deleted  -> unlink it 
*/
export function unlinkBidsFromReward(rewardAllocation: RewardAllocation): void {
  const bidRewards = rewardAllocation.bidRewards;

  for (let i = 0; i < bidRewards.length; i++) {
    const bidRewardId = bidRewards[i];

    const bidReward = BidReward.load(bidRewardId);
    if (bidReward && bidReward.claimed) {
      // only unlink unclaimed rewards for drained/deleted rewards
      continue;
    }

    removeFromArray(rewardAllocation.bidRewards, bidRewardId);

    store.remove("BidReward", bidRewardId);
  }

  rewardAllocation.save();
}

export function unlinkTokenVolumeFromReward(
  rewardAllocation: RewardAllocation
): void {
  rewardAllocation.tokenVolume = null;
  rewardAllocation.save();
}

function appendAllocationRewardToBidParticipants(
  bid: Bid,
  rewardAllocation: RewardAllocation
): void {
  // create a bid reward entity
  const bidRewardId = getBidRewardId(bid, rewardAllocation);

  // this created a bidReward which is an attachment of the reward to a bid
  const bidReward = loadBidReward(bid, rewardAllocation);

  // manually add the association
  rewardAllocation.bidRewards = addToArray(
    rewardAllocation.bidRewards,
    bidReward.id
  );
  rewardAllocation.save();
}

function bidIsEligibleForReward(
  bid: Bid,
  rewardAllocation: RewardAllocation
): boolean {
  if (bid.marketplaceId != rewardAllocation.marketplaceId) {
    return false;
  }

  // must use address.zero and not address.empty
  if (
    rewardAllocation.requiredPrincipalTokenAddress != Address.zero() &&
    bid.lendingTokenAddress != rewardAllocation.requiredPrincipalTokenAddress
  ) {
    return false;
  }

  if (
    rewardAllocation.bidStartTimeMin > BigInt.zero() &&
    bid.acceptedTimestamp < rewardAllocation.bidStartTimeMin
  ) {
    return false;
  }
  if (
    rewardAllocation.bidStartTimeMax > BigInt.zero() &&
    bid.acceptedTimestamp > rewardAllocation.bidStartTimeMax
  ) {
    return false;
  }

  // filter by collateral requirements!
  if (
    rewardAllocation.requiredCollateralTokenAddress != Address.zero() &&
    rewardAllocation.minimumCollateralPerPrincipalAmount > BigInt.zero()
  ) {
    // make sure the bid has the required collateral, and with enough ratio

    let hasValidCollateral = false;

    const bidCollaterals = changetype<BidCollateral[]>(
      store.loadRelated("Bid", bid.id, "collateral")
    );

    if (bidCollaterals) {
      for (let i = 0; i < bidCollaterals.length; i++) {
        const bidCollateral = bidCollaterals[i];

        const principalToken = loadToken(bid.lendingTokenAddress);
        let principalTokenDecimals = principalToken.decimals;
        if (!principalTokenDecimals) {
          principalTokenDecimals = BigInt.zero();
        }

        const collateralToken = loadToken(bidCollateral.collateralAddress);
        let collateralTokenDecimals = collateralToken.decimals;
        if (!collateralTokenDecimals) {
          collateralTokenDecimals = BigInt.zero();
        }

        const requiredCollateralAmount = getRequiredCollateralAmount(
          bid.principal,
          rewardAllocation.minimumCollateralPerPrincipalAmount,
          principalTokenDecimals,
          collateralTokenDecimals
        );

        if (
          bidCollateral.collateralAddress ==
            rewardAllocation.requiredCollateralTokenAddress &&
          bidCollateral.amount >= requiredCollateralAmount
        ) {
          hasValidCollateral = true;
          break;
        }
      }
    }

    if (!hasValidCollateral) return false;
  }
  return true;
}

/*
  Make sure this rounds like the solidity method 
*/
function getRequiredCollateralAmount(
  principal: BigInt,
  minimumCollateralPerPrincipalAmount: BigInt,
  principalTokenDecimals: BigInt,
  collateralTokenDecimals: BigInt
): BigInt {
  const expansion: i64 =
    10 ** principalTokenDecimals.plus(collateralTokenDecimals).toI32();

  const requiredCollateralAmount = minimumCollateralPerPrincipalAmount
    .times(principal)
    .div(BigInt.fromI64(expansion));

  return requiredCollateralAmount;
}

function borrowerIsEligibleForRewardWithBidStatus(bidStatus: string): boolean {
  if (bidStatus == bidStatusToString(BidStatus.Repaid)) return true;

  return false;
}

function lenderIsEligibleForRewardWithBidStatus(bidStatus: string): boolean {
  if (bidStatus == bidStatusToString(BidStatus.Repaid)) return true;
  if (bidStatus == bidStatusToString(BidStatus.Defaulted)) return true;
  if (bidStatus == bidStatusToString(BidStatus.Accepted)) return true;
  if (bidStatus == bidStatusToString(BidStatus.DueSoon)) return true;
  if (bidStatus == bidStatusToString(BidStatus.Late)) return true;
  if (bidStatus == bidStatusToString(BidStatus.Liquidated)) return true;

  return false;
}
