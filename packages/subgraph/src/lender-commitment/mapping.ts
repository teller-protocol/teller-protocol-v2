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
import { loadBidById } from "../helpers/loaders";

import { loadCommitment } from "./loaders";
import { updateCommitmentStatus, updateLenderCommitment } from "./updaters";
import { CommitmentStatus } from "./utils";
import { linkCommitmentToRewards } from "../liquidity-rewards/updaters";

export function handleCreatedCommitment(event: CreatedCommitment): void {
  const commitmentId = event.params.commitmentId.toString();
  const commitment = updateLenderCommitment(
    commitmentId,
    event.params.lender,
    event.params.marketId.toString(),
    event.params.lendingToken,
    event.params.tokenAmount,
    event.address,
    event.block
  );

  commitment.createdAt = event.block.timestamp;

  commitment.save();

  linkCommitmentToRewards(commitment);
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
    event.address,
    event.block
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

  updateCommitmentStatus(commitment, CommitmentStatus.Deleted);

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

  if (event.params.tokenAmount.equals(commitment.committedAmount)) {
    updateCommitmentStatus(commitment, CommitmentStatus.Drained);
  }

  // Link commitment to bid
  const bid: Bid = loadBidById(event.params.bidId);
  bid.commitment = commitment.id;
  bid.commitmentId = commitment.id;

  bid.save();
  commitment.save();
}

export function handleExercisedCommitments(
  events: ExercisedCommitment[]
): void {
  events.forEach(event => {
    handleExercisedCommitment(event);
  });
}

export function handleUpdatedCommitmentBorrower(
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

export function handleUpdatedCommitmentBorrowers(
  events: UpdatedCommitmentBorrowers[]
): void {
  events.forEach(event => {
    handleUpdatedCommitmentBorrower(event);
  });
}
