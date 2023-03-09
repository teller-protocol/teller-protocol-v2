import { ethereum } from "@graphprotocol/graph-ts";

import { Bid } from "../generated/schema";

import {
  isBidDefaulted,
  isBidDueSoon,
  isBidExpired,
  isBidLate
} from "./helpers/bid";
import { loadLoanStatusCount } from "./helpers/loaders";
import { updateBidStatus } from "./helpers/updaters";

export function handleBlock(block: ethereum.Block): void {
  checkActiveBids(block);
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
      updateBidStatus(bid, "Expired");
    }
  }

  for (let i = 0; i < acceptedLoans.length; i++) {
    const bid = Bid.load(acceptedLoans[i]);
    if (!bid) continue;

    if (isBidDueSoon(bid, block.timestamp)) {
      updateBidStatus(bid, "Due Soon");
      dueSoonLoans.push(bid.id);
    }
  }

  for (let i = 0; i < dueSoonLoans.length; i++) {
    const bid = Bid.load(dueSoonLoans[i]);
    if (!bid) continue;

    if (isBidLate(bid, block.timestamp)) {
      updateBidStatus(bid, "Late");
      lateLoans.push(bid.id);
    }
  }

  for (let i = 0; i < lateLoans.length; i++) {
    const bid = Bid.load(lateLoans[i]);
    if (!bid) continue;

    if (isBidDefaulted(bid, block.timestamp)) {
      updateBidStatus(bid, "Defaulted");
    }
  }
}
