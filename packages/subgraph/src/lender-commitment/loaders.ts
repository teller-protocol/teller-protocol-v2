import { Address, BigDecimal, BigInt } from "@graphprotocol/graph-ts";

import {
  Commitment,
  CommitmentZScore,
  MarketCommitmentStdDev
} from "../../generated/schema";
import { addToArray } from "../helpers/utils";

/**
 * @param {string} commitmentId - ID of the commitment
 * @returns {Commitment} The Commitment entity for the lender
 */
export function loadCommitment(commitmentId: string): Commitment {
  const idString = commitmentId;
  let commitment = Commitment.load(idString);

  if (!commitment) {
    commitment = new Commitment(idString);
    commitment.createdAt = BigInt.zero();
    commitment.updatedAt = BigInt.zero();
    commitment.status = "";

    commitment.committedAmount = BigInt.zero();
    commitment.expirationTimestamp = BigInt.zero();
    commitment.maxDuration = BigInt.zero();
    commitment.minAPY = BigInt.zero();
    commitment.lender = "";
    commitment.lenderAddress = Address.zero();
    commitment.marketplace = "";
    commitment.marketplaceId = BigInt.zero();
    commitment.tokenVolume = "";

    commitment.principalToken = "";
    commitment.principalTokenAddress = Address.zero();

    commitment.collateralToken = "";
    commitment.maxPrincipalPerCollateralAmount = BigInt.zero();
    commitment.commitmentBorrowers = [];

    commitment.save();
  }
  return commitment;
}

function getMarketCommitmentStdDevId(commitment: Commitment): string {
  const collateralTokenId = commitment.collateralToken
    ? commitment.collateralToken
    : "none";
  return [
    "market",
    commitment.marketplace,
    "token",
    commitment.principalToken,
    "collateral",
    collateralTokenId
  ].join("-");
}

export function loadMarketCommitmentStdDev(
  commitment: Commitment
): MarketCommitmentStdDev {
  const id = getMarketCommitmentStdDevId(commitment);
  let commitmentZScores = MarketCommitmentStdDev.load(id);
  if (!commitmentZScores) {
    commitmentZScores = new MarketCommitmentStdDev(id);
    commitmentZScores.market = commitment.marketplace;
    commitmentZScores.lendingToken = commitment.principalToken;
    commitmentZScores.collateralToken = commitment.collateralToken;

    commitmentZScores.commitmentZScores = [];
    commitmentZScores.maxPrincipalPerCollateralStdDev = BigDecimal.zero();
    commitmentZScores.maxPrincipalPerCollateralMean = BigDecimal.zero();
    commitmentZScores.minApyStdDev = BigDecimal.zero();
    commitmentZScores.minApyMean = BigDecimal.zero();
    commitmentZScores.maxDurationStdDev = BigDecimal.zero();
    commitmentZScores.maxDurationMean = BigDecimal.zero();
    commitmentZScores.save();
  }

  return commitmentZScores;
}

export function loadCommitmentZScore(commitment: Commitment): CommitmentZScore {
  let commitmentZScore = CommitmentZScore.load(commitment.id);
  if (!commitmentZScore) {
    commitmentZScore = new CommitmentZScore(commitment.id);
    commitmentZScore.commitment = commitment.id;
    commitmentZScore.zScore = BigDecimal.zero();
    commitmentZScore.save();
  }

  return commitmentZScore;
}
