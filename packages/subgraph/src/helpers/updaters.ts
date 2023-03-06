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

import { BidStatus, bidStatusToEnum, isBidLate } from "./bid";
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
import { addToArray, removeFromArray } from "./utils";

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
  updateLoanCounts(protocolVolume.loans, bid.id, bid.status, prevStatus, type);
}

function updateMarketLoanCounts(
  bid: Bid,
  prevStatus: string,
  type: UpdateLoanCountsType = UpdateLoanCountsType.Increment |
    UpdateLoanCountsType.Decrement
): void {
  const market = MarketPlace.load(bid.marketplace);
  if (market)
    updateLoanCounts(market.loans, bid.id, bid.status, prevStatus, type);

  const marketVolume = loadTokenVolumeByMarketId(
    Address.fromBytes(bid.lendingTokenAddress),
    bid.marketplace
  );
  updateLoanCounts(marketVolume.loans, bid.id, bid.status, prevStatus, type);
}

function updateBorrowerLoanCounts(
  bid: Bid,
  prevStatus: string,
  type: UpdateLoanCountsType = UpdateLoanCountsType.Increment |
    UpdateLoanCountsType.Decrement
): void {
  const borrower = loadBorrowerFromBidId(bid.id);
  updateLoanCounts(borrower.loans, bid.id, bid.status, prevStatus, type);

  const borrowerVolume = loadBorrowerTokenVolume(
    Address.fromBytes(bid.lendingTokenAddress),
    borrower
  );
  updateLoanCounts(borrowerVolume.loans, bid.id, bid.status, prevStatus, type);
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
    updateLoanCounts(lender.loans, bid.id, bid.status, prevStatus, type);

    const lenderVolume = loadLenderTokenVolume(
      Address.fromBytes(bid.lendingTokenAddress),
      lender
    );
    updateLoanCounts(lenderVolume.loans, bid.id, bid.status, prevStatus, type);
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
  bidId: string,
  currStatus: string,
  prevStatus: string,
  type: UpdateLoanCountsType = UpdateLoanCountsType.Increment |
    UpdateLoanCountsType.Decrement
): LoanCounts {
  let loans: LoanCounts | null = null;
  if (
    (type & UpdateLoanCountsType.Increment) ==
    UpdateLoanCountsType.Increment
  ) {
    loans = incrementLoanCounts(loanCountsId, bidId, currStatus);
  }
  if (
    (type & UpdateLoanCountsType.Decrement) ==
    UpdateLoanCountsType.Decrement
  ) {
    loans = decrementLoanCounts(loanCountsId, bidId, prevStatus);
  }
  if (!loans) throw new Error("Loan counts not found");
  return loans;
}

export function incrementLoanCounts(
  loanCountsId: string,
  bidId: string,
  status: string
): LoanCounts {
  const loans = LoanCounts.load(loanCountsId);
  if (!loans) throw new Error("Loan counts not found");

  const bidStatus = bidStatusToEnum(status);
  switch (bidStatus) {
    case BidStatus.Submitted:
      loans.submitted = addToArray(loans.submitted, bidId);
      loans.submittedCount = BigInt.fromI32(loans.submitted.length);
      break;
    case BidStatus.Cancelled:
      loans.cancelled = addToArray(loans.cancelled, bidId);
      loans.cancelledCount = BigInt.fromI32(loans.cancelled.length);
      break;
    case BidStatus.Accepted:
      loans.accepted = addToArray(loans.accepted, bidId);
      loans.acceptedCount = BigInt.fromI32(loans.accepted.length);
      break;
    case BidStatus.Repaid:
      loans.repaid = addToArray(loans.repaid, bidId);
      loans.repaidCount = BigInt.fromI32(loans.repaid.length);
      break;
    case BidStatus.Late:
      loans.late = addToArray(loans.late, bidId);
      loans.lateCount = BigInt.fromI32(loans.late.length);
      break;
    case BidStatus.Defaulted:
      loans.defaulted = addToArray(loans.defaulted, bidId);
      loans.defaultedCount = BigInt.fromI32(loans.defaulted.length);
      break;
    case BidStatus.Liquidated:
      loans.liquidated = addToArray(loans.liquidated, bidId);
      loans.liquidatedCount = BigInt.fromI32(loans.liquidated.length);
      break;
    default:
      throw new Error("Invalid bid status");
  }

  if (bidStatus != BidStatus.Cancelled) {
    loans.all = addToArray(loans.all, bidId);
    loans.totalCount = BigInt.fromI32(loans.all.length);
  }

  loans.save();

  return loans;
}

export function decrementLoanCounts(
  loanCountsId: string,
  bidId: string,
  status: string
): LoanCounts {
  const loans = LoanCounts.load(loanCountsId);
  if (!loans) throw new Error("Loan counts not found");

  const bidStatus = bidStatusToEnum(status);
  switch (bidStatus) {
    case BidStatus.Submitted:
      loans.submitted = removeFromArray(loans.submitted, bidId);
      loans.submittedCount = BigInt.fromI32(loans.submitted.length);
      break;
    case BidStatus.Cancelled:
      loans.cancelled = removeFromArray(loans.cancelled, bidId);
      loans.cancelledCount = BigInt.fromI32(loans.cancelled.length);
      break;
    case BidStatus.Accepted:
      loans.accepted = removeFromArray(loans.accepted, bidId);
      loans.acceptedCount = BigInt.fromI32(loans.accepted.length);
      break;
    case BidStatus.Repaid:
      loans.repaid = removeFromArray(loans.repaid, bidId);
      loans.repaidCount = BigInt.fromI32(loans.repaid.length);
      break;
    case BidStatus.Late:
      loans.late = removeFromArray(loans.late, bidId);
      loans.lateCount = BigInt.fromI32(loans.late.length);
      break;
    case BidStatus.Defaulted:
      loans.defaulted = removeFromArray(loans.defaulted, bidId);
      loans.defaultedCount = BigInt.fromI32(loans.defaulted.length);
      break;
    case BidStatus.Liquidated:
      loans.liquidated = removeFromArray(loans.liquidated, bidId);
      loans.liquidatedCount = BigInt.fromI32(loans.liquidated.length);
      break;
    default:
      throw new Error("Invalid bid status");
  }

  if (bidStatus != BidStatus.Cancelled) {
    loans.all = removeFromArray(loans.all, bidId);
    loans.totalCount = BigInt.fromI32(loans.all.length);
  }

  loans.save();
  return loans;
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
    if (isBidLate(bid, event.block)) {
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

  const loans = LoanCounts.load(tokenVolume.loans);
  if (!loans) throw new Error("Loan counts not found");

  tokenVolume._aprTotal = tokenVolume._aprTotal.plus(bid.apr);
  tokenVolume.aprAverage = tokenVolume._aprTotal.div(loans.totalCount);

  tokenVolume.totalLoaned = tokenVolume.totalLoaned.plus(bid.principal);
  tokenVolume.loanAverage = tokenVolume.totalLoaned.div(loans.totalCount);

  tokenVolume._durationTotal = tokenVolume._durationTotal.plus(
    bid.loanDuration
  );
  tokenVolume.durationAverage = tokenVolume._durationTotal.div(
    loans.totalCount
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

  const loans = LoanCounts.load(tokenVolume.loans);
  if (!loans) throw new Error("Loan counts not found");

  tokenVolume._aprTotal = tokenVolume._aprTotal.minus(bid.apr);
  tokenVolume.aprAverage = tokenVolume._aprTotal.div(loans.totalCount);

  tokenVolume.totalLoaned = tokenVolume.totalLoaned.minus(bid.principal);
  tokenVolume.loanAverage = tokenVolume.totalLoaned.div(loans.totalCount);

  tokenVolume._durationTotal = tokenVolume._durationTotal.minus(
    bid.loanDuration
  );
  tokenVolume.durationAverage = tokenVolume._durationTotal.div(
    loans.totalCount
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
