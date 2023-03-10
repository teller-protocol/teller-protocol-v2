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

const BidStatusValues = new Array<string>(10);
BidStatusValues[BidStatus.None] = "";
BidStatusValues[BidStatus.Submitted] = "Submitted";
BidStatusValues[BidStatus.Expired] = "Expired";
BidStatusValues[BidStatus.Cancelled] = "Cancelled";
BidStatusValues[BidStatus.Accepted] = "Accepted";
BidStatusValues[BidStatus.DueSoon] = "Due Soon";
BidStatusValues[BidStatus.Late] = "Late";
BidStatusValues[BidStatus.Defaulted] = "Defaulted";
BidStatusValues[BidStatus.Repaid] = "Repaid";
BidStatusValues[BidStatus.Liquidated] = "Liquidated";

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
  const lastPaidTimestamp =
    bid.lastRepaidTimestamp == BigInt.zero()
      ? bid.acceptedTimestamp
      : bid.lastRepaidTimestamp;
  return timestamp.minus(lastPaidTimestamp) > bid.paymentDefaultDuration;
}
