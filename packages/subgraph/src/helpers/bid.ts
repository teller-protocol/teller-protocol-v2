import { ethereum } from "@graphprotocol/graph-ts";

import { Bid } from "../../generated/schema";

export enum BidStatus {
  None,
  Submitted,
  Expired,
  Cancelled,
  Accepted,
  Repaid,
  Late,
  Defaulted,
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
  } else if (status == "Repaid") {
    return BidStatus.Repaid;
  } else if (status == "Late") {
    return BidStatus.Late;
  } else if (status == "Defaulted") {
    return BidStatus.Defaulted;
  } else if (status == "Liquidated") {
    return BidStatus.Liquidated;
  } else {
    return BidStatus.None;
  }
}

export function isBidLate(bid: Bid, block: ethereum.Block): boolean {
  return bid.nextDueDate ? bid.nextDueDate < block.timestamp : false;
}

export function isBidDefaulted(bid: Bid, block: ethereum.Block): boolean {
  if (!bid.nextDueDate) return false;

  const defaultTimestamp = bid.lastRepaidTimestamp.plus(
    bid.paymentDefaultDuration
  );
  return defaultTimestamp < block.timestamp;
}
