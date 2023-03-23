import { Address, BigInt } from "@graphprotocol/graph-ts";

import { Commitment } from "../../generated/schema";
import { CommitmentStatus, commitmentStatusToString } from "./utils";

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
    commitment.status = commitmentStatusToString(CommitmentStatus.Active);

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
    commitment.collateralTokenAddress = Address.zero();
    commitment.collateralTokenType = "";
    commitment.maxPrincipalPerCollateralAmount = BigInt.zero();
    commitment.commitmentBorrowers = [];

    commitment.save();
  }
  return commitment;
}
