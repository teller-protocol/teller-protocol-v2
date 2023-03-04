import { Address, BigInt, ethereum } from "@graphprotocol/graph-ts";

import { CollateralCommitted } from "../../generated/CollateralManager/CollateralManager";
import {
  Bid,
  Borrower,
  Collateral,
  Commitment,
  Lender,
  LoanCounts,
  MarketPlace,
  Payment,
  TokenVolume
} from "../../generated/schema";
import {
  TellerV2,
  TellerV2__bidsResult
} from "../../generated/TellerV2/TellerV2";

import {
  getBid,
  loadBorrowerByMarketId,
  loadBorrowerFromBidId,
  loadBorrowerTokenVolume,
  loadLenderByMarketId,
  loadLenderFromBidId,
  loadLenderTokenVolume,
  loadMarketById,
  loadProtocolTokenVolume,
  loadTokenVolumeByMarketId
} from "./loaders";

export function updateTokenVolumeOnPayment(
  lastPayment: BigInt,
  lastInterestPayment: BigInt,
  bidState: string,
  tokenVolume: TokenVolume
): void {
  tokenVolume.outstandingCapital = tokenVolume.outstandingCapital.minus(
    lastPayment
  );
  if (tokenVolume.outstandingCapital.lt(BigInt.zero())) {
    tokenVolume.outstandingCapital = BigInt.zero();
  }

  tokenVolume.totalRepaidInterest = tokenVolume.totalRepaidInterest.plus(
    lastInterestPayment
  );

  tokenVolume.save();
}

export function updateLoanCountsFromBid(bid: Bid, prevStatus: string): void {
  updateProtocolLoanCounts(bid, prevStatus);
  updateMarketLoanCounts(bid, prevStatus);
  updateBorrowerLoanCounts(bid, prevStatus);
  updateLenderLoanCounts(bid, prevStatus);
}

function updateProtocolLoanCounts(
  bid: Bid,
  prevStatus: string,
  type: UpdateLoanCountsType = UpdateLoanCountsType.Increment |
    UpdateLoanCountsType.Decrement
): void {
  // TODO: protocol loan stats

  // Update the protocol's overall token volume
  const protocolVolume = loadProtocolTokenVolume(
    Address.fromBytes(bid.lendingTokenAddress)
  );
  updateLoanCounts(protocolVolume.loanCounts, bid.status, prevStatus, type);
}

function updateMarketLoanCounts(
  bid: Bid,
  prevStatus: string,
  type: UpdateLoanCountsType = UpdateLoanCountsType.Increment |
    UpdateLoanCountsType.Decrement
): void {
  const market = MarketPlace.load(bid.marketplace);
  if (market) updateLoanCounts(market.loanCounts, bid.status, prevStatus, type);

  const marketVolume = loadTokenVolumeByMarketId(
    Address.fromBytes(bid.lendingTokenAddress),
    bid.marketplace
  );
  updateLoanCounts(marketVolume.loanCounts, bid.status, prevStatus, type);
}

function updateBorrowerLoanCounts(
  bid: Bid,
  prevStatus: string,
  type: UpdateLoanCountsType = UpdateLoanCountsType.Increment |
    UpdateLoanCountsType.Decrement
): void {
  const borrower = loadBorrowerFromBidId(bid.id);
  updateLoanCounts(borrower.loanCounts, bid.status, prevStatus, type);

  const borrowerVolume = loadBorrowerTokenVolume(
    Address.fromBytes(bid.lendingTokenAddress),
    borrower
  );
  updateLoanCounts(borrowerVolume.loanCounts, bid.status, prevStatus, type);
}

function updateLenderLoanCounts(
  bid: Bid,
  prevStatus: string,
  type: UpdateLoanCountsType = UpdateLoanCountsType.Increment |
    UpdateLoanCountsType.Decrement
): boolean {
  if (bidStatusToEnum(prevStatus) == BidStatus.Submitted) {
    // eslint-disable-next-line no-param-reassign
    type = UpdateLoanCountsType.Increment;
  }

  const lender = loadLenderFromBidId(bid.id);
  if (lender) {
    updateLoanCounts(lender.loanCounts, bid.status, prevStatus, type);

    const lenderVolume = loadLenderTokenVolume(
      Address.fromBytes(bid.lendingTokenAddress),
      lender
    );
    updateLoanCounts(lenderVolume.loanCounts, bid.status, prevStatus, type);
    return true;
  }
  return false;
}

enum UpdateLoanCountsType {
  Increment = 1,
  Decrement = 2
}

function updateLoanCounts(
  loanCountsId: string,
  currStatus: string,
  prevStatus: string,
  type: UpdateLoanCountsType = UpdateLoanCountsType.Increment |
    UpdateLoanCountsType.Decrement
): LoanCounts {
  let loanCounts: LoanCounts | null = null;
  if (
    (type & UpdateLoanCountsType.Increment) ==
    UpdateLoanCountsType.Increment
  ) {
    loanCounts = incrementLoanCounts(loanCountsId, currStatus);
  }
  if (
    (type & UpdateLoanCountsType.Decrement) ==
    UpdateLoanCountsType.Decrement
  ) {
    loanCounts = decrementLoanCounts(loanCountsId, prevStatus);
  }
  if (!loanCounts) throw new Error("Loan counts not found");
  return loanCounts;
}

export function incrementLoanCounts(
  loanCountsId: string,
  status: string
): LoanCounts {
  const loanCounts = LoanCounts.load(loanCountsId);
  if (!loanCounts) throw new Error("Loan counts not found");

  const ONE = BigInt.fromI32(1);

  switch (bidStatusToEnum(status)) {
    case BidStatus.Submitted:
      loanCounts.submitted = loanCounts.submitted.plus(ONE);
      loanCounts.total = loanCounts.total.plus(ONE);
      break;
    case BidStatus.Cancelled:
      loanCounts.cancelled = loanCounts.cancelled.plus(ONE);
      break;
    case BidStatus.Accepted:
      loanCounts.accepted = loanCounts.accepted.plus(ONE);
      loanCounts.total = loanCounts.total.plus(ONE);
      break;
    case BidStatus.Repaid:
      loanCounts.repaid = loanCounts.repaid.plus(ONE);
      loanCounts.total = loanCounts.total.plus(ONE);
      break;
    case BidStatus.Defaulted:
      loanCounts.defaulted = loanCounts.defaulted.plus(ONE);
      loanCounts.total = loanCounts.total.plus(ONE);
      break;
    case BidStatus.Liquidated:
      loanCounts.liquidated = loanCounts.liquidated.plus(ONE);
      loanCounts.total = loanCounts.total.plus(ONE);
      break;
  }
  loanCounts.save();

  return loanCounts;
}

enum BidStatus {
  None,
  Submitted,
  Cancelled,
  Accepted,
  Repaid,
  Defaulted,
  Liquidated
}

export function bidStatusToEnum(status: string): BidStatus {
  if (status == "Submitted") {
    return BidStatus.Submitted;
  } else if (status == "Cancelled") {
    return BidStatus.Cancelled;
  } else if (status == "Accepted") {
    return BidStatus.Accepted;
  } else if (status == "Repaid") {
    return BidStatus.Repaid;
  } else if (status == "Defaulted") {
    return BidStatus.Defaulted;
  } else if (status == "Liquidated") {
    return BidStatus.Liquidated;
  } else {
    return BidStatus.None;
  }
}

export function decrementLoanCounts(
  loanCountsId: string,
  status: string
): LoanCounts {
  const loanCounts = LoanCounts.load(loanCountsId);
  if (!loanCounts) throw new Error("Loan counts not found");

  const ONE = BigInt.fromI32(1);

  switch (bidStatusToEnum(status)) {
    case BidStatus.Submitted:
      loanCounts.submitted = loanCounts.submitted.minus(ONE);
      loanCounts.total = loanCounts.total.minus(ONE);
      break;
    case BidStatus.Cancelled:
      loanCounts.cancelled = loanCounts.cancelled.minus(ONE);
      break;
    case BidStatus.Accepted:
      loanCounts.accepted = loanCounts.accepted.minus(ONE);
      loanCounts.total = loanCounts.total.minus(ONE);
      break;
    case BidStatus.Repaid:
      loanCounts.repaid = loanCounts.repaid.minus(ONE);
      loanCounts.total = loanCounts.total.minus(ONE);
      break;
    case BidStatus.Defaulted:
      loanCounts.defaulted = loanCounts.defaulted.minus(ONE);
      loanCounts.total = loanCounts.total.minus(ONE);
      break;
    case BidStatus.Liquidated:
      loanCounts.liquidated = loanCounts.liquidated.minus(ONE);
      loanCounts.total = loanCounts.total.minus(ONE);
      break;
  }

  loanCounts.save();
  return loanCounts;
}

export function updateBidOnPayment(
  bid: Bid,
  event: ethereum.Event,
  bidState: string
): void {
  const tellerV2Instance = TellerV2.bind(event.address);
  const storedBid = getBid(event.address, bid.bidId);

  bid.totalRepaidPrincipal = storedBid.value5.totalRepaid.principal;
  bid.totalRepaidInterest = storedBid.value5.totalRepaid.interest;
  bid.lastRepaidTimestamp = storedBid.value5.lastRepaidTimestamp;

  const _lastPayment = storedBid.value5.totalRepaid.principal.minus(
    bid._lastTotalRepaidAmount
  );
  bid._lastTotalRepaidAmount = _lastPayment.plus(bid._lastTotalRepaidAmount);

  const _lastInterestPayment = storedBid.value5.totalRepaid.interest.minus(
    bid._lastTotalRepaidInterestAmount
  );
  bid._lastTotalRepaidInterestAmount = _lastInterestPayment.plus(
    bid._lastTotalRepaidInterestAmount
  );

  if (bidState !== "Liquidated") {
    // The outstanding capital and payment entities are not updated on liquidation events
    // because the Liquidation event is fired after the Repayment event
    updateOutstandingCapital(
      bid,
      storedBid,
      _lastPayment,
      _lastInterestPayment,
      bidState
    );

    const payment = new Payment(event.transaction.hash.toHex());
    payment.bid = bid.id;
    payment.principal = _lastPayment;
    payment.interest = _lastInterestPayment;
    payment.paymentDate = event.block.timestamp;
    payment.outstandingCapital = bid.principal.minus(bid.totalRepaidPrincipal);
    if (bid.nextDueDate && bid.nextDueDate < event.block.timestamp) {
      payment.status = "Late";
    } else {
      payment.status = "On Time";
    }
    payment.save();
  }

  if (bidState === "Repayment") {
    bid.nextDueDate = tellerV2Instance.calculateNextDueDate(bid.bidId);
  } else {
    bid.nextDueDate = BigInt.zero();
    bid.status = bidState;
  }

  bid.save();
}

export function updateBidTokenVolumesOnAccept(bid: Bid): void {
  // Update the borrower's token volume
  const borrower = loadBorrowerFromBidId(bid.id);
  const borrowerVolume = loadBorrowerTokenVolume(
    Address.fromBytes(bid.lendingTokenAddress),
    borrower
  );
  addBidToTokenVolume(borrowerVolume, bid);

  // Update the lender's token volume
  const lender = loadLenderFromBidId(bid.id);
  if (!lender) throw new Error("Lender not found");
  const lenderVolume = loadLenderTokenVolume(
    Address.fromBytes(bid.lendingTokenAddress),
    lender
  );
  addBidToTokenVolume(lenderVolume, bid);

  // Update the market's token volume
  const tokenVolume = loadTokenVolumeByMarketId(
    Address.fromBytes(bid.lendingTokenAddress),
    bid.marketplace
  );
  addBidToTokenVolume(tokenVolume, bid);

  // Update the protocol's overall token volume
  const protocolVolume = loadProtocolTokenVolume(
    Address.fromBytes(bid.lendingTokenAddress)
  );
  addBidToTokenVolume(protocolVolume, bid);
}

export function addBidToTokenVolume(tokenVolume: TokenVolume, bid: Bid): void {
  const bidIds = tokenVolume.bids;
  const index = bidIds.indexOf(bid.id);
  if (index == -1) {
    tokenVolume.bids = tokenVolume.bids.concat([bid.id]);
  }

  tokenVolume.outstandingCapital = tokenVolume.outstandingCapital.plus(
    bid.principal.minus(bid.totalRepaidPrincipal)
  );

  const loanCounts = LoanCounts.load(tokenVolume.loanCounts);
  if (!loanCounts) throw new Error("Loan counts not found");

  tokenVolume._aprTotal = tokenVolume._aprTotal.plus(bid.apr);
  tokenVolume.aprAverage = tokenVolume._aprTotal.div(loanCounts.total);

  tokenVolume.totalLoaned = tokenVolume.totalLoaned.plus(bid.principal);
  tokenVolume.loanAverage = tokenVolume.totalLoaned.div(loanCounts.total);

  tokenVolume._durationTotal = tokenVolume._durationTotal.plus(
    bid.loanDuration
  );
  tokenVolume.durationAverage = tokenVolume._durationTotal.div(
    loanCounts.total
  );

  tokenVolume.save();
}

export function removeBidFromTokenVolume(
  tokenVolume: TokenVolume,
  bid: Bid
): void {
  const bidIds = tokenVolume.bids;
  const index = bidIds.indexOf(bid.id);
  if (index > -1) {
    bidIds.splice(index, 1);
    tokenVolume.bids = bidIds;
  }

  tokenVolume.outstandingCapital = tokenVolume.outstandingCapital.minus(
    bid.principal.minus(bid.totalRepaidPrincipal)
  );

  const loanCounts = LoanCounts.load(tokenVolume.loanCounts);
  if (!loanCounts) throw new Error("Loan counts not found");

  tokenVolume._aprTotal = tokenVolume._aprTotal.minus(bid.apr);
  tokenVolume.aprAverage = tokenVolume._aprTotal.div(loanCounts.total);

  tokenVolume.totalLoaned = tokenVolume.totalLoaned.minus(bid.principal);
  tokenVolume.loanAverage = tokenVolume.totalLoaned.div(loanCounts.total);

  tokenVolume._durationTotal = tokenVolume._durationTotal.minus(
    bid.loanDuration
  );
  tokenVolume.durationAverage = tokenVolume._durationTotal.div(
    loanCounts.total
  );

  tokenVolume.save();
}

export function updateOutstandingCapital(
  bid: Bid,
  storedBid: TellerV2__bidsResult,
  _lastPayment: BigInt,
  _lastInterestPayment: BigInt,
  bidState: string
): void {
  const market = loadMarketById(storedBid.value3.toString());
  const lender = loadLenderByMarketId(storedBid.value2, market.id);
  const borrower: Borrower = loadBorrowerByMarketId(
    storedBid.value0,
    market.id
  );

  // Update market's token volume
  const tokenVolume = loadTokenVolumeByMarketId(
    storedBid.value5.lendingToken,
    market.id
  );
  updateTokenVolumeOnPayment(
    _lastPayment,
    _lastInterestPayment,
    bidState,
    tokenVolume
  );

  // Update protocol's overall token volume
  const protocolVolume = loadProtocolTokenVolume(storedBid.value5.lendingToken);
  updateTokenVolumeOnPayment(
    _lastPayment,
    _lastInterestPayment,
    bidState,
    protocolVolume
  );

  // Update lender's token volume
  const lenderVolume = loadLenderTokenVolume(
    storedBid.value5.lendingToken,
    lender
  );
  updateTokenVolumeOnPayment(
    _lastPayment,
    _lastInterestPayment,
    bidState,
    lenderVolume
  );
  const earnedLenderInterest = lenderVolume.commissionEarned;
  if (earnedLenderInterest) {
    lenderVolume.commissionEarned = earnedLenderInterest.plus(
      _lastInterestPayment
    );
  }
  lenderVolume.save();

  const commitmentId = bid.commitment;
  if (commitmentId) {
    const commitment = Commitment.load(commitmentId);
    if (commitment) {
      const commitmentStats = TokenVolume.load(commitment.stats);
      updateTokenVolumeOnPayment(
        _lastPayment,
        _lastInterestPayment,
        bidState,
        commitmentStats!
      );
      if (commitmentStats && commitmentStats.commissionEarned) {
        commitmentStats.commissionEarned = commitmentStats.commissionEarned.plus(
          _lastInterestPayment
        );
        commitmentStats.save();
      }
    }
  }

  // Update borrower's token volume
  const borrowerVolume = loadBorrowerTokenVolume(
    Address.fromBytes(bid.lendingTokenAddress),
    borrower
  );
  updateTokenVolumeOnPayment(
    _lastPayment,
    _lastInterestPayment,
    bidState,
    borrowerVolume
  );
  borrowerVolume.save();

  lender.save();
  market.save();
  borrower.save();
}

export function updateCollateral(
  collateral: Collateral,
  event: ethereum.Event
): void {
  const evt = changetype<CollateralCommitted>(event);
  collateral.amount = evt.params._amount;
  collateral.tokenId = evt.params._tokenId;
  collateral.type = getTypeString(evt.params._type);
  collateral.collateralAddress = evt.params._collateralAddress;
}
function getTypeString(tokenType: i32): string {
  let type = "";
  if (tokenType == i32(0)) {
    type = "ERC20";
  } else if (tokenType == i32(1)) {
    type = "ERC721";
  } else if (tokenType == i32(2)) {
    type = "ERC1155";
  }
  return type;
}

export function incrementLenderStats(lender: Lender, bid: Bid): void {
  const successful = updateLenderLoanCounts(
    bid,
    "",
    UpdateLoanCountsType.Increment
  );
  if (!successful) throw new Error("Failed to increment lender loan counts");

  // Update the lender's token volume
  const lenderVolume = loadLenderTokenVolume(
    Address.fromBytes(bid.lendingTokenAddress),
    lender
  );
  addBidToTokenVolume(lenderVolume, bid);
}

export function decrementLenderStats(lender: Lender, bid: Bid): void {
  // Pass the current status as the previous status to be decremented
  updateLenderLoanCounts(bid, bid.status, UpdateLoanCountsType.Decrement);

  // Update the lender's token volume
  const lenderVolume = loadLenderTokenVolume(
    Address.fromBytes(bid.lendingTokenAddress),
    lender
  );
  removeBidFromTokenVolume(lenderVolume, bid);
}
