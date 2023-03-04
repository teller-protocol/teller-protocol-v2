import { BigInt, Bytes } from "@graphprotocol/graph-ts";

import {
  CreatedCommitment,
  DeletedCommitment,
  ExercisedCommitment,
  LenderCommitmentForwarder,
  UpdatedCommitment,
  UpdatedCommitmentBorrowers
} from "../../generated/LenderCommitmentForwarder/LenderCommitmentForwarder";
import { Bid, TokenVolume } from "../../generated/schema";
import { initTokenVolume } from "../helpers/intializers";
import {
  loadBidById,
  loadCommitment,
  updateLenderCommitment
} from "../helpers/loaders";
import { addBidToTokenVolume, incrementLoanCounts } from "../helpers/updaters";

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

  const stats = new TokenVolume(`commitment-stats-${commitment.id}`);
  initTokenVolume(stats, event.params.lendingToken);
  stats.save();

  commitment.stats = stats.id;
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
  const committedAmount = commitment.committedAmount;
  // Updated stored committed amount
  if (committedAmount) {
    commitment.committedAmount = committedAmount.minus(
      event.params.tokenAmount
    );
  }
  // Link commitment to bid
  const bid: Bid = loadBidById(event.params.bidId);
  bid.commitment = commitment.id;
  bid.commitmentId = commitment.id;

  bid.save();
  commitment.save();

  const stats = TokenVolume.load(commitment.stats);
  if (stats) {
    incrementLoanCounts(stats.loanCounts, bid.status);
    addBidToTokenVolume(stats, bid);
  }
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
