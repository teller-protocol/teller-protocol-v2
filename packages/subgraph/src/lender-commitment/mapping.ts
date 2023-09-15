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
import { linkCommitmentToRewards } from "../liquidity-rewards/updaters";

import { loadCommitment } from "./loaders";
import {
  updateCommitmentStatus,
  updateLenderCommitment,
  updateAvailableTokensFromCommitment
} from "./updaters";
import { CommitmentStatus } from "./utils";

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

  updateCommitmentStatus(commitment, CommitmentStatus.Deleted);
  updateAvailableTokensFromCommitment(commitment);

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

  const lenderCommitmentForwarderInstance = LenderCommitmentForwarder.bind(
    event.address
  );
  const acceptedPrincipalResult = lenderCommitmentForwarderInstance.try_commitmentPrincipalAccepted(
    BigInt.fromString(commitment.id)
  );
  // function only exists after an upgrade
  if (acceptedPrincipalResult.reverted) {
    // keep track of old accepted principal
    commitment._oldAcceptedPrincipal = commitment._oldAcceptedPrincipal.plus(
      event.params.tokenAmount
    );
  } else {
    commitment._newAcceptedPrincipal = acceptedPrincipalResult.value;
    commitment.acceptedPrincipal = acceptedPrincipalResult.value;

    // Link commitment to bid (only after accepted amount is tracked on-chain)
    //   - Bids created before the upgrade will not be linked as they skew the calculated available amount
    const bid: Bid = loadBidById(event.params.bidId);
    bid.commitment = commitment.id;
    bid.commitmentId = commitment.id;
    bid.save();
  }

  const availableAmount = commitment.maxPrincipal.minus(
    commitment.acceptedPrincipal
  );
  if (availableAmount.equals(BigInt.zero())) {
    updateCommitmentStatus(commitment, CommitmentStatus.Drained);
  }

  updateAvailableTokensFromCommitment(commitment);
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
