import { ethereum, BigInt } from "@graphprotocol/graph-ts";

import { Bid, Commitment } from "../generated/schema";

import {
  BidStatus,
  isBidDefaulted,
  isBidDueSoon,
  isBidExpired,
  isBidLate
} from "./helpers/bid";
import { loadLoanStatusCount, loadProtocol } from "./helpers/loaders";
import { updateBidStatus } from "./helpers/updaters";
import {
  updateAvailableTokensFromCommitment,
  updateCommitmentStatus
} from "./lender-commitment/updaters";
import { CommitmentStatus } from "./lender-commitment/utils";

export function handleBlock(block: ethereum.Block): void {
  const mod = block.number.mod(BigInt.fromI32(10));
  switch (mod.toI32()) {
    case 0:
      checkActiveBids(block);
      break;
    case 1:
      checkActiveCommitments(block);
      break;
  }
}

export function checkActiveBids(block: ethereum.Block): void {
  const loans = loadLoanStatusCount("protocol", "v2");
  const pendingBids = loans.submitted;
  const lateLoans = loans.late;
  const dueSoonLoans = loans.dueSoon;
  const acceptedLoans = loans.accepted;

  for (let i = 0; i < pendingBids.length; i++) {
    const bid = Bid.load(pendingBids[i]);
    if (!bid) continue;
    if (isBidExpired(bid, block.timestamp)) {
      updateBidStatus(bid, BidStatus.Expired);
    }
  }

  for (let i = 0; i < acceptedLoans.length; i++) {
    const bid = Bid.load(acceptedLoans[i]);
    if (!bid) continue;

    if (isBidDueSoon(bid, block.timestamp)) {
      updateBidStatus(bid, BidStatus.DueSoon);
      dueSoonLoans.push(bid.id);
    }
  }

  for (let i = 0; i < dueSoonLoans.length; i++) {
    const bid = Bid.load(dueSoonLoans[i]);
    if (!bid) continue;

    if (isBidLate(bid, block.timestamp)) {
      updateBidStatus(bid, BidStatus.Late);
      lateLoans.push(bid.id);
    }
  }

  for (let i = 0; i < lateLoans.length; i++) {
    const bid = Bid.load(lateLoans[i]);
    if (!bid) continue;

    if (isBidDefaulted(bid, block.timestamp)) {
      updateBidStatus(bid, BidStatus.Defaulted);
    }
  }
}

export function checkActiveCommitments(block: ethereum.Block): void {
  const protocol = loadProtocol();
  const activeCommitments = protocol.activeCommitments;
  for (let i = 0; i < activeCommitments.length; i++) {
    const commitmentId = protocol.activeCommitments[i];
    const commitment = Commitment.load(commitmentId)!;

    // TODO: check the lender's token balance + allowance

    if (commitment.expirationTimestamp.lt(block.timestamp)) {
      updateCommitmentStatus(commitment, CommitmentStatus.Expired);
      updateAvailableTokensFromCommitment(commitment);
    }
  }
}
