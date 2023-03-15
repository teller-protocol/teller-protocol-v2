import { Address, BigInt } from "@graphprotocol/graph-ts";

import { LenderCommitmentForwarder } from "../../generated/LenderCommitmentForwarder/LenderCommitmentForwarder";
import { Commitment } from "../../generated/schema";
import { loadLenderByMarketId } from "../helpers/loaders";

import { loadCommitment } from "./loaders";

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
  commitment.committedAmount = committedAmount;

  const lenderCommitmentForwarderInstance = LenderCommitmentForwarder.bind(
    eventAddress
  );
  const lenderCommitment = lenderCommitmentForwarderInstance.commitments(
    BigInt.fromString(commitmentId)
  );

  commitment.expirationTimestamp = lenderCommitment.value1;
  commitment.maxDuration = lenderCommitment.value2;
  commitment.minAPY = BigInt.fromI32(lenderCommitment.value3);
  commitment.collateralTokenAddress = lenderCommitment.value4;
  commitment.collateralTokenId = lenderCommitment.value5;
  commitment.maxPrincipalPerCollateralAmount = lenderCommitment.value6;
  commitment.collateralTokenType = lenderCommitment.value7.toString();
  commitment.principalTokenAddress = lenderCommitment.value10;
  commitment.save();
  return commitment;
}
