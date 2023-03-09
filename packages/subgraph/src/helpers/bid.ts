import { BigInt } from "@graphprotocol/graph-ts";

import { Bid } from "../../generated/schema";

export enum BidStatus {
  None = 1,
  Submitted = 2,
  Expired = 4,
  Cancelled = 8,
  Accepted = 16,
  DueSoon = 32,
  Late = 64,
  Defaulted = 128,
  Repaid = 256,
  Liquidated = 512
}

export function bidStatusToEnum(status: string): BidStatus {
  if (status == "Submitted") {
    return BidStatus.Submitted;
  } else if (status == "Expired") {
    return BidStatus.Expired;
  } else if (status == "Cancelled") {
    return BidStatus.Cancelled;
  } else if (status == "Accepted") {
    return BidStatus.Accepted;
  } else if (status == "DueSoon") {
    return BidStatus.DueSoon;
  } else if (status == "Late") {
    return BidStatus.Late;
  } else if (status == "Defaulted") {
    return BidStatus.Defaulted;
  } else if (status == "Repaid") {
    return BidStatus.Repaid;
  } else if (status == "Liquidated") {
    return BidStatus.Liquidated;
  } else {
    return BidStatus.None;
  }
}

function bidStatusToString(status: BidStatus): string {
  if (status == BidStatus.Submitted) {
    return "Submitted";
  } else if (status == BidStatus.Expired) {
    return "Expired";
  } else if (status == BidStatus.Cancelled) {
    return "Cancelled";
  } else if (status == BidStatus.Accepted) {
    return "Accepted";
  } else if (status == BidStatus.DueSoon) {
    return "Due Soon";
  } else if (status == BidStatus.Late) {
    return "Late";
  } else if (status == BidStatus.Defaulted) {
    return "Defaulted";
  } else if (status == BidStatus.Repaid) {
    return "Repaid";
  } else if (status == BidStatus.Liquidated) {
    return "Liquidated";
  } else {
    return "None";
  }
}

function hasAllowedStatus(status: string, bitOredAllowedStatus: i32): boolean {
  const bidStatus = BigInt.fromI32(bidStatusToEnum(status));
  const allowedStatus = BigInt.fromI32(bitOredAllowedStatus);
  return bidStatus.bitAnd(allowedStatus) == bidStatus;
}

export function isBidExpired(bid: Bid, timestamp: BigInt): boolean {
  return bidStatusToEnum(bid.status) == BidStatus.Submitted
    ? bid.expiresAt < timestamp
    : false;
}

export function isBidDueSoon(bid: Bid, timestamp: BigInt): boolean {
  const allowedStatus = BidStatus.Accepted;
  const dueDate = bid.nextDueDate;
  if (hasAllowedStatus(bid.status, allowedStatus) || !dueDate) return false;

  const dueSoonTimestamp = dueDate.plus(BigInt.fromI32(60 * 60 * 24 * 7));
  return dueSoonTimestamp < timestamp;
}

export function isBidLate(bid: Bid, timestamp: BigInt): boolean {
  const allowedStatus = BidStatus.Accepted | BidStatus.DueSoon;
  const dueDate = bid.nextDueDate;
  if (hasAllowedStatus(bid.status, allowedStatus) || !dueDate) return false;

  return bidStatusToEnum(bid.status) == BidStatus.Accepted
    ? dueDate < timestamp
    : false;
}

export function isBidDefaulted(bid: Bid, timestamp: BigInt): boolean {
  const allowedStatus = BidStatus.Accepted | BidStatus.DueSoon | BidStatus.Late;
  if (hasAllowedStatus(bid.status, allowedStatus)) return false;

  const defaultTimestamp = bid.lastRepaidTimestamp.plus(
    bid.paymentDefaultDuration
  );
  return defaultTimestamp < timestamp;
}
