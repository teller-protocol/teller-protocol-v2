import { BigInt, Bytes } from "@graphprotocol/graph-ts";

import {
  CreatedCommitment,
  DeletedCommitment,
  ExercisedCommitment,
  LenderCommitmentForwarder,
  UpdatedCommitment,
  UpdatedCommitmentBorrowers
} from "../../generated/LenderCommitmentForwarder/LenderCommitmentForwarder";
import { Bid } from "../../generated/schema";
import { BidStatus } from "../helpers/bid";
import { loadBidById } from "../helpers/loaders";
import { updateBidStatus } from "../helpers/updaters";

import { loadCommitment } from "./loaders";
import {
  updateAvailableTokensFromCommitment,
  updateLenderCommitment
} from "./updaters";

export function handleCreatedCommitment(event: CreatedCommitment): void {
  const commitmentId = event.params.commitmentId.toString();
  const commitment = updateLenderCommitment(
    commitmentId,
    event.params.lender,
    event.params.marketId.toString(),
    event.params.lendingToken,
    event.params.tokenAmount,
    event.address
  );

  commitment.createdAt = event.block.timestamp;

  commitment.save();
}

export function handleCreatedCommitments(events: CreatedCommitment[]): void {
  events.forEach(event => {
    handleCreatedCommitment(event);
  });
}

export function handleUpdatedCommitment(event: UpdatedCommitment): void {
  const commitmentId = event.params.commitmentId.toString();
  updateLenderCommitment(
    commitmentId,
    event.params.lender,
    event.params.marketId.toString(),
    event.params.lendingToken,
    event.params.tokenAmount,
    event.address
  );
}

export function handleUpdatedCommitments(events: UpdatedCommitment[]): void {
  events.forEach(event => {
    handleUpdatedCommitment(event);
  });
}

export function handleDeletedCommitment(event: DeletedCommitment): void {
  const commitmentId = event.params.commitmentId.toString();
  const commitment = loadCommitment(commitmentId);
  commitment.committedAmount = BigInt.zero();
  commitment.expirationTimestamp = BigInt.zero();
  commitment.maxDuration = BigInt.zero();
  commitment.minAPY = BigInt.zero();
  commitment.maxPrincipalPerCollateralAmount = BigInt.zero();
  commitment.save();
}

export function handleDeletedCommitments(events: DeletedCommitment[]): void {
  events.forEach(event => {
    handleDeletedCommitment(event);
  });
}

export function handleExercisedCommitment(event: ExercisedCommitment): void {
  const commitmentId = event.params.commitmentId.toString();
  const commitment = loadCommitment(commitmentId);

  const amountAvailable = commitment.committedAmount.minus(
    event.params.tokenAmount
  );
  updateAvailableTokensFromCommitment(commitment, amountAvailable);

  // Link commitment to bid
  const bid: Bid = loadBidById(event.params.bidId);
  bid.commitment = commitment.id;
  bid.commitmentId = commitment.id;

  bid.save();
  commitment.save();

  updateBidStatus(bid, BidStatus.Accepted);
}

export function handleExercisedCommitments(
  events: ExercisedCommitment[]
): void {
  events.forEach(event => {
    handleExercisedCommitment(event);
  });
}

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