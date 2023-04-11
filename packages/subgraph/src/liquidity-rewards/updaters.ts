import { Address, BigInt, ethereum } from "@graphprotocol/graph-ts";

import { MarketLiquidityRewards } from "../../generated/MarketLiquidityRewards/MarketLiquidityRewards";
import { RewardAllocation, Token, TokenVolume } from "../../generated/schema";
import {
 
} from "../helpers/loaders";
import { addToArray, removeFromArray } from "../helpers/utils";

import { loadRewardAllocation } from "./loaders";
//import { CommitmentStatus, commitmentStatusToString } from "./utils";

enum CollateralTokenType {
  NONE,
  ERC20,
  ERC721,
  ERC1155,
  ERC721_ANY_ID,
  ERC1155_ANY_ID
}

/*
export function updateRewardAllocationStatus(
  commitment: RewardAllocation,
  status: RewardAllocationStatus
): void {
  commitment.status = commitmentStatusToString(status);

  switch (status) {
    case CommitmentStatus.Active:
      addCommitmentToProtocol(commitment);
      break;
    case CommitmentStatus.Deleted:
    case CommitmentStatus.Drained:
    case CommitmentStatus.Expired:
      updateAvailableTokensFromCommitment(
        commitment,
        commitment.committedAmount.neg()
      );
      removeCommitmentToProtocol(commitment);

      break;
  }

  commitment.save();
}
*/

/**
 * @param {string} commitmentId - ID of the commitment
 * @param {Address} lenderAddress - Address of the lender
 * @param {string} marketId - Market id
 * @param {Address} lendingTokenAddress - Address of the token being lent
 * @param {BigInt} committedAmount - The maximum that can be loaned
 * @param {Address} eventAddress - Address of the emitted event
 * @param {ethereum.Block} eventBlock - Block of the emitted event
 */
export function updateRewardAllocation(
  allocationId: string,
//  lenderAddress: Address,
//  marketId: string,
//  lendingTokenAddress: Address,
//  committedAmount: BigInt,
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
function addCommitmentToProtocol(commitment: Commitment): void {
  const protocol = loadProtocol();
  protocol.activeCommitments = addToArray(
    protocol.activeCommitments,
    commitment.id
  );
  protocol.save();
}
function removeCommitmentToProtocol(commitment: Commitment): void {
  const protocol = loadProtocol();
  protocol.activeCommitments = removeFromArray(
    protocol.activeCommitments,
    commitment.id
  );
  protocol.save();
}

export function updateAvailableTokensFromCommitment(
  commitment: Commitment,
  committedAmountDiff: BigInt
): void {
  if (committedAmountDiff.isZero()) {
    return;
  }

  commitment.committedAmount = commitment.committedAmount.plus(
    committedAmountDiff
  );
  commitment.save();

  const tokenVolumes = getTokenVolumesFromCommitment(commitment);
  for (let i = 0; i < tokenVolumes.length; i++) {
    const tokenVolume = tokenVolumes[i];
    tokenVolume.totalAvailable = tokenVolume.totalAvailable.plus(
      committedAmountDiff
    );
    tokenVolume.save();
  }
}

function getTokenVolumesFromCommitment(commitment: Commitment): TokenVolume[] {
  const tokenVolumes = new Array<TokenVolume>();

  const protocolVolume = loadProtocolTokenVolume(commitment.principalToken);
  tokenVolumes.push(protocolVolume);

  const commitmentVolume = loadCommitmentTokenVolume(
    commitment.principalToken,
    commitment
  );
  tokenVolumes.push(commitmentVolume);

  const marketVolume = loadMarketTokenVolume(
    commitment.principalToken,
    commitment.marketplace
  );
  tokenVolumes.push(marketVolume);

  const lenderVolume = loadLenderTokenVolume(
    commitment.principalToken,
    loadLenderByMarketId(commitment.lenderAddress, commitment.marketplace)
  );
  tokenVolumes.push(lenderVolume);

  const collateralTokenId = commitment.collateralToken;
  const collateralToken = Token.load(
    collateralTokenId ? collateralTokenId : ""
  );
  const volumesCount = tokenVolumes.length;
  for (let i = 0; i < volumesCount; i++) {
    const tokenVolume = tokenVolumes[i];
    const collateralVolume = loadCollateralTokenVolume(
      tokenVolume,
      collateralToken
    );
    tokenVolumes.push(collateralVolume);
  }

  return tokenVolumes;
}
*/