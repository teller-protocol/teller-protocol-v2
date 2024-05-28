import { ethereum } from "@graphprotocol/graph-ts";

import { Bid } from "../../generated/schema";
import {
  BidStatus,
  isBidDefaulted,
  isBidDueSoon,
  isBidExpired,
  isBidLate
} from "../helpers-old/bid";
import { loadLoanStatusCount } from "../helpers-old/loaders";
import { updateBidStatus } from "../helpers-old/updaters";

export function handleActiveBids(block: ethereum.Block): void {
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
