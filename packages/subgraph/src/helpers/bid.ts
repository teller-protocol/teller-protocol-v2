import { BigInt } from "@graphprotocol/graph-ts";

import { Bid } from "../../generated/schema";

export enum BidStatus {
  None,
  Submitted,
  Expired,
  Cancelled,
  Accepted,
  DueSoon,
  Late,
  Defaulted,
  Repaid,
  Liquidated
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
  } else if (status == "Due Soon") {
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

export function bidStatusToString(status: BidStatus): string {
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

export function isBidExpired(bid: Bid, timestamp: BigInt): boolean {
  return bid.expiresAt < timestamp;
}

export function isBidDueSoon(bid: Bid, timestamp: BigInt): boolean {
  const dueDate = bid.nextDueDate;
  if (!dueDate) return false;

  const dueSoonDuration = bid.paymentCycle.div(BigInt.fromI32(4));
  const dueSoonTimestamp = dueDate.minus(dueSoonDuration);
  return dueSoonTimestamp < timestamp;
}

export function isBidLate(bid: Bid, timestamp: BigInt): boolean {
  const dueDate = bid.nextDueDate;
  if (!dueDate) return false;

  return dueDate < timestamp;
}

export function isBidDefaulted(bid: Bid, timestamp: BigInt): boolean {
  const lastPaidTimestamp =
    bid.lastRepaidTimestamp == BigInt.zero()
      ? bid.acceptedTimestamp
      : bid.lastRepaidTimestamp;
  return timestamp.minus(lastPaidTimestamp) > bid.paymentDefaultDuration;
}
