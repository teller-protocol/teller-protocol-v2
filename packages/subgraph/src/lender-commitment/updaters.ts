import {
  Address,
  BigDecimal,
  BigInt,
  Entity,
  store
} from "@graphprotocol/graph-ts";

import { LenderCommitmentForwarder } from "../../generated/LenderCommitmentForwarder/LenderCommitmentForwarder";
import {
  Commitment,
  CommitmentZScore,
  MarketCommitmentStdDev,
  Token,
  TokenVolume
} from "../../generated/schema";
import {
  loadCollateralTokenVolume,
  loadCommitmentTokenVolume,
  loadLenderByMarketId,
  loadLenderTokenVolume,
  loadMarketTokenVolume,
  loadProtocol,
  loadProtocolTokenVolume,
  loadToken,
  TokenType
} from "../helpers/loaders";
import {
  addToArray,
  calcStdDevAndMeanFromEntities,
  calcWeightedDeviation,
  removeFromArray
} from "../helpers/utils";

import {
  loadCommitment,
  loadCommitmentZScore,
  loadMarketCommitmentStdDev
} from "./loaders";
import {
  CommitmentStatus,
  commitmentStatusToEnum,
  commitmentStatusToString
} from "./utils";

enum CollateralTokenType {
  NONE,
  ERC20,
  ERC721,
  ERC1155,
  ERC721_ANY_ID,
  ERC1155_ANY_ID,
  ERC721_MERKLE,
  ERC1155_MERKLE
}

/**
 * @param {string} commitmentId - ID of the commitment
 * @param {Address} lenderAddress - Address of the lender
 * @param {string} marketId - Market id
 * @param {Address} lendingTokenAddress - Address of the token being lent
 * @param {BigInt} committedAmount - The maximum that can be loaned
 * @param {Address} eventAddress - Address of the emitted event
 */
export function updateLenderCommitment(
  commitmentId: string,
  lenderAddress: Address,
  marketId: string,
  lendingTokenAddress: Address,
  committedAmount: BigInt,
  eventAddress: Address
): Commitment {
  const commitment = loadCommitment(commitmentId);

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

  commitment.expirationTimestamp = lenderCommitment.getExpiration();
  commitment.maxDuration = lenderCommitment.getMaxDuration();
  commitment.minAPY = BigInt.fromI32(lenderCommitment.getMinInterestRate());

  const lendingToken = loadToken(lendingTokenAddress);
  commitment.principalToken = lendingToken.id;
  commitment.principalTokenAddress = lendingTokenAddress;
  commitment.maxPrincipal = lenderCommitment.getMaxPrincipal();

  commitment.collateralTokenType = BigInt.fromI32(
    lenderCommitment.getCollateralTokenType()
  );
  if (lenderCommitment.getCollateralTokenType() != CollateralTokenType.NONE) {
    let tokenType = TokenType.UNKNOWN;
    let nftId: BigInt | null = null;
    switch (lenderCommitment.getCollateralTokenType()) {
      case CollateralTokenType.ERC20:
        tokenType = TokenType.ERC20;
        break;
      case CollateralTokenType.ERC721:
      case CollateralTokenType.ERC721_MERKLE:
        nftId = lenderCommitment.getCollateralTokenId();
      case CollateralTokenType.ERC721_ANY_ID:
        tokenType = TokenType.ERC721;
        break;
      case CollateralTokenType.ERC1155:
      case CollateralTokenType.ERC1155_MERKLE:
        nftId = lenderCommitment.getCollateralTokenId();
      case CollateralTokenType.ERC1155_ANY_ID:
        tokenType = TokenType.ERC1155;
        break;
    }
    const collateralToken = loadToken(
      lenderCommitment.getCollateralTokenAddress(),
      tokenType,
      nftId
    );
    commitment.collateralToken = collateralToken.id;
    commitment.collateralTokenAddress = collateralToken.address;
    commitment.maxPrincipalPerCollateralAmount = lenderCommitment.getMaxPrincipalPerCollateralAmount();
  }

  const volume = loadCommitmentTokenVolume(lendingToken.id, commitment);
  commitment.tokenVolume = volume.id;

  commitment.save();

  updateCommitmentStatus(commitment, CommitmentStatus.Active);
  updateAvailableTokensFromCommitment(commitment);

  return commitment;
}

export function updateCommitmentStatus(
  commitment: Commitment,
  status: CommitmentStatus
): void {
  commitment.status = commitmentStatusToString(status);

  const commitmentZScore = loadCommitmentZScore(commitment);
  const marketCommitments = loadMarketCommitmentStdDev(commitment);

  switch (status) {
    case CommitmentStatus.Active:
      addCommitmentToProtocol(commitment);
      marketCommitments.commitmentZScores = addToArray(
        marketCommitments.commitmentZScores,
        commitmentZScore.id
      );
      break;
    case CommitmentStatus.Deleted:
    case CommitmentStatus.Drained:
    case CommitmentStatus.Expired:
      removeCommitmentToProtocol(commitment);
      marketCommitments.commitmentZScores = removeFromArray(
        marketCommitments.commitmentZScores,
        commitmentZScore.id
      );
      // Delete the commitment z-score entity from the store
      store.remove("CommitmentZScore", commitmentZScore.id);

      break;
  }

  commitment.save();
  marketCommitments.save();

  // Update the market commitment standard deviation and rescore the commitments
  updateMarketCommitmentStdDev(marketCommitments);
}

export function updateMarketCommitmentStdDev(
  marketCommitments: MarketCommitmentStdDev
): void {
  const commitments = updateMarketCommitmentStdDevAndMean(marketCommitments);
  for (let i = 0; i < commitments.length; i++) {
    const commitment = commitments[i];
    const commitmentZScore = loadCommitmentZScore(commitment);

    updateCommitmentZScore(commitment, commitmentZScore, marketCommitments);
  }
}

export function updateMarketCommitmentStdDevAndMean(
  marketCommitments: MarketCommitmentStdDev
): Commitment[] {
  const commitments: Entity[] = [];
  const commitmentZScores = marketCommitments.commitmentZScores;
  for (let i = 0; i < commitmentZScores.length; i++) {
    commitments.push(Commitment.load(commitmentZScores[i])!);
  }

  const maxPrincipalPerCollateral = calcStdDevAndMeanFromEntities(
    commitments,
    "maxPrincipalPerCollateralAmount"
  );
  const minApy = calcStdDevAndMeanFromEntities(commitments, "minAPY");
  const maxDuration = calcStdDevAndMeanFromEntities(commitments, "maxDuration");

  marketCommitments.maxPrincipalPerCollateralStdDev =
    maxPrincipalPerCollateral[0];
  marketCommitments.maxPrincipalPerCollateralMean =
    maxPrincipalPerCollateral[1];

  marketCommitments.minApyStdDev = minApy[0];
  marketCommitments.minApyMean = minApy[1];

  marketCommitments.maxDurationStdDev = maxDuration[0];
  marketCommitments.maxDurationMean = maxDuration[1];

  marketCommitments.save();

  return changetype<Commitment[]>(commitments);
}

export function updateCommitmentZScore(
  commitment: Commitment,
  commitmentZScore: CommitmentZScore,
  marketCommitments: MarketCommitmentStdDev
): void {
  commitmentZScore.zScore = BigDecimal.zero()
    .plus(
      calcWeightedDeviation(
        marketCommitments.maxPrincipalPerCollateralMean,
        marketCommitments.maxPrincipalPerCollateralStdDev,
        BigDecimal.fromString("4"),
        commitment.maxPrincipalPerCollateralAmount
      )
    )
    .plus(
      calcWeightedDeviation(
        marketCommitments.minApyMean,
        marketCommitments.minApyStdDev,
        BigDecimal.fromString("-1.333"),
        commitment.minAPY
      )
    )
    .plus(
      calcWeightedDeviation(
        marketCommitments.maxDurationMean,
        marketCommitments.maxDurationStdDev,
        BigDecimal.fromString("0.444"),
        commitment.maxDuration
      )
    );

  commitmentZScore.save();
}

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

// TODO: Need to account for the case where the collateral token changes
export function updateAvailableTokensFromCommitment(
  commitment: Commitment
): void {
  const availableAmount = commitment.maxPrincipal.minus(
    commitment.acceptedPrincipal
  );

  let committedAmountDiff: BigInt;
  if (commitmentStatusToEnum(commitment.status) == CommitmentStatus.Active) {
    committedAmountDiff = availableAmount.minus(commitment.committedAmount);
  } else {
    committedAmountDiff = availableAmount.neg();
  }

  commitment.committedAmount = availableAmount;
  commitment.save();

  if (!committedAmountDiff.equals(BigInt.zero())) {
    const tokenVolumes = getTokenVolumesFromCommitment(commitment);
    for (let i = 0; i < tokenVolumes.length; i++) {
      const tokenVolume = tokenVolumes[i];
      tokenVolume.totalAvailable = tokenVolume.totalAvailable.plus(
        committedAmountDiff
      );
      tokenVolume.save();
    }
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
