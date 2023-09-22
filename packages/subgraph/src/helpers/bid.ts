import { BigInt } from "@graphprotocol/graph-ts";

import { Bid } from "../../generated/schema";

export enum BidStatus {
  None,
  Submitted,
  Cancelled,
  Accepted,
  Repaid,
  Liquidated,

  Expired,
  DueSoon,
  Late,
  Defaulted
}

export const BidStatusValues = new Array<string>(10);
BidStatusValues[BidStatus.None] = "";
BidStatusValues[BidStatus.Submitted] = "Submitted";
BidStatusValues[BidStatus.Cancelled] = "Cancelled";
BidStatusValues[BidStatus.Accepted] = "Accepted";
BidStatusValues[BidStatus.Repaid] = "Repaid";
BidStatusValues[BidStatus.Liquidated] = "Liquidated";

BidStatusValues[BidStatus.Expired] = "Expired";
BidStatusValues[BidStatus.DueSoon] = "Due Soon";
BidStatusValues[BidStatus.Late] = "Late";
BidStatusValues[BidStatus.Defaulted] = "Defaulted";

export function bidStatusToEnum(status: string): BidStatus {
  return BidStatusValues.indexOf(status);
}

export function bidStatusToString(status: BidStatus): string {
  return BidStatusValues[status];
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
  if (bid.paymentDefaultDuration.isZero()) return false;

  const dueDate = bid.nextDueDate;
  if (!dueDate) return false;

  return timestamp > dueDate.plus(bid.paymentDefaultDuration);
}
