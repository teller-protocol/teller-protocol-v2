import { Address, BigInt, ethereum } from "@graphprotocol/graph-ts";

import { CollateralCommitted } from "../../generated/CollateralManager/CollateralManager";
import {
  Bid,
  Collateral,
  Lender,
  LoanStatusCount,
  Payment,
  TokenVolume
} from "../../generated/schema";
import { TellerV2 } from "../../generated/TellerV2/TellerV2";

import {
  BidStatus,
  bidStatusToEnum,
  bidStatusToString,
  isBidLate
} from "./bid";
import {
  getBid,
  loadBorrowerByMarketId,
  loadBorrowerTokenVolume,
  loadLenderByMarketId,
  loadLenderTokenVolume,
  loadProtocolTokenVolume,
  loadTokenVolumeByMarketId
} from "./loaders";
import { addToArray, removeFromArray } from "./utils";

export function updateBidStatus(bid: Bid, status: BidStatus): void {
  const prevStatus = bid.isSet("status") ? bid.status : "";
  bid.status = bidStatusToString(status);
  bid.save();
  updateLoanStatusCountsFromBid(bid.id, prevStatus);
}

export function getLoanStatusCountIdsForBid(bidId: string): string[] {
  const bid = Bid.load(bidId);
  if (!bid) throw new Error(`Bid ${bidId} does not exist`);

  const loanStatusCountIds = [
    "protocol-v2",
    `market-${bid.marketplace}`,
    `borrower-${bid.borrower}`
  ];

  const lenderId = bid.lender;
  if (lenderId) loanStatusCountIds.push(`lender-${lenderId}`);

  const tokenVolumes = getTokenVolumesForBid(bid.id);
  for (let i = 0; i < tokenVolumes.length; i++) {
    loanStatusCountIds.push(`tokenVolume-${tokenVolumes[i].id}`);
  }

  return loanStatusCountIds;
}

export function getTokenVolumesForBid(bidId: string): TokenVolume[] {
  const bid = Bid.load(bidId);
  if (!bid) throw new Error(`Bid ${bidId} does not exist`);
  const tokenVolumes = new Array<TokenVolume>(0);
  const lendingTokenAddress = Address.fromBytes(bid.lendingTokenAddress);

  const protocolVolume = loadProtocolTokenVolume(lendingTokenAddress);
  tokenVolumes.push(protocolVolume);

  const marketVolume = loadTokenVolumeByMarketId(
    lendingTokenAddress,
    bid.marketplace
  );
  tokenVolumes.push(marketVolume);

  const borrowerVolume = loadBorrowerTokenVolume(
    lendingTokenAddress,
    loadBorrowerByMarketId(
      Address.fromBytes(bid.borrowerAddress),
      bid.marketplace
    )
  );
  tokenVolumes.push(borrowerVolume);

  const lenderAddress = bid.lenderAddress;
  if (lenderAddress) {
    const lenderVolume = loadLenderTokenVolume(
      lendingTokenAddress,
      loadLenderByMarketId(Address.fromBytes(lenderAddress), bid.marketplace)
    );
    tokenVolumes.push(lenderVolume);
  }

  return tokenVolumes;
}

export function updateLoanStatusCountsFromBid(
  bidId: string,
  prevStatus: string
): void {
  const bid = Bid.load(bidId);
  if (!bid) throw new Error(`Bid ${bidId} does not exist`);
  const loanStatusCountIds = getLoanStatusCountIdsForBid(bidId);
  for (let i = 0; i < loanStatusCountIds.length; i++) {
    incrementLoanStatusCount(loanStatusCountIds[i], bid.id, bid.status);
    decrementLoanStatusCount(loanStatusCountIds[i], bid.id, prevStatus);
  }
}

export function incrementLoanStatusCount(
  loanStatusCountId: string,
  bidId: string,
  status: string
): LoanStatusCount {
  const loanStatusCount = LoanStatusCount.load(loanStatusCountId);
  if (!loanStatusCount)
    throw new Error(`Loan status count not found: ${loanStatusCountId}`);

  const bidStatus = bidStatusToEnum(status);
  switch (bidStatus) {
    case BidStatus.Submitted:
      loanStatusCount.submitted = addToArray(loanStatusCount.submitted, bidId);
      loanStatusCount.submittedCount = BigInt.fromI32(
        loanStatusCount.submitted.length
      );
      break;
    case BidStatus.Expired:
      loanStatusCount.expired = addToArray(loanStatusCount.expired, bidId);
      loanStatusCount.expiredCount = BigInt.fromI32(
        loanStatusCount.expired.length
      );
      break;
    case BidStatus.Cancelled:
      loanStatusCount.cancelled = addToArray(loanStatusCount.cancelled, bidId);
      loanStatusCount.cancelledCount = BigInt.fromI32(
        loanStatusCount.cancelled.length
      );
      break;
    case BidStatus.Accepted:
      loanStatusCount.accepted = addToArray(loanStatusCount.accepted, bidId);
      loanStatusCount.acceptedCount = BigInt.fromI32(
        loanStatusCount.accepted.length
      );
      break;
    case BidStatus.DueSoon:
      loanStatusCount.dueSoon = addToArray(loanStatusCount.dueSoon, bidId);
      loanStatusCount.dueSoonCount = BigInt.fromI32(
        loanStatusCount.dueSoon.length
      );
      break;
    case BidStatus.Late:
      loanStatusCount.late = addToArray(loanStatusCount.late, bidId);
      loanStatusCount.lateCount = BigInt.fromI32(loanStatusCount.late.length);
      break;
    case BidStatus.Defaulted:
      loanStatusCount.defaulted = addToArray(loanStatusCount.defaulted, bidId);
      loanStatusCount.defaultedCount = BigInt.fromI32(
        loanStatusCount.defaulted.length
      );
      break;
    case BidStatus.Repaid:
      loanStatusCount.repaid = addToArray(loanStatusCount.repaid, bidId);
      loanStatusCount.repaidCount = BigInt.fromI32(
        loanStatusCount.repaid.length
      );
      break;
    case BidStatus.Liquidated:
      loanStatusCount.liquidated = addToArray(
        loanStatusCount.liquidated,
        bidId
      );
      loanStatusCount.liquidatedCount = BigInt.fromI32(
        loanStatusCount.liquidated.length
      );
      break;
    case BidStatus.None:
      return loanStatusCount;
    default:
      throw new Error(`Invalid bid status: ${status}`);
  }

  updateTotalLoanStatusCount(loanStatusCount);

  loanStatusCount.save();
  return loanStatusCount;
}

export function decrementLoanStatusCount(
  loanStatusCountId: string,
  bidId: string,
  status: string
): LoanStatusCount {
  const loanStatusCount = LoanStatusCount.load(loanStatusCountId);
  if (!loanStatusCount)
    throw new Error(`Loan status count not found: ${loanStatusCountId}`);

  const bidStatus = bidStatusToEnum(status);
  switch (bidStatus) {
    case BidStatus.Submitted:
      loanStatusCount.submitted = removeFromArray(
        loanStatusCount.submitted,
        bidId
      );
      loanStatusCount.submittedCount = BigInt.fromI32(
        loanStatusCount.submitted.length
      );
      break;
    case BidStatus.Expired:
      loanStatusCount.expired = removeFromArray(loanStatusCount.expired, bidId);
      loanStatusCount.expiredCount = BigInt.fromI32(
        loanStatusCount.expired.length
      );
      break;
    case BidStatus.Cancelled:
      loanStatusCount.cancelled = removeFromArray(
        loanStatusCount.cancelled,
        bidId
      );
      loanStatusCount.cancelledCount = BigInt.fromI32(
        loanStatusCount.cancelled.length
      );
      break;
    case BidStatus.Accepted:
      loanStatusCount.accepted = removeFromArray(
        loanStatusCount.accepted,
        bidId
      );
      loanStatusCount.acceptedCount = BigInt.fromI32(
        loanStatusCount.accepted.length
      );
      break;
    case BidStatus.DueSoon:
      loanStatusCount.dueSoon = removeFromArray(loanStatusCount.dueSoon, bidId);
      loanStatusCount.dueSoonCount = BigInt.fromI32(
        loanStatusCount.dueSoon.length
      );
      break;
    case BidStatus.Late:
      loanStatusCount.late = removeFromArray(loanStatusCount.late, bidId);
      loanStatusCount.lateCount = BigInt.fromI32(loanStatusCount.late.length);
      break;
    case BidStatus.Defaulted:
      loanStatusCount.defaulted = removeFromArray(
        loanStatusCount.defaulted,
        bidId
      );
      loanStatusCount.defaultedCount = BigInt.fromI32(
        loanStatusCount.defaulted.length
      );
      break;
    case BidStatus.Repaid:
      loanStatusCount.repaid = removeFromArray(loanStatusCount.repaid, bidId);
      loanStatusCount.repaidCount = BigInt.fromI32(
        loanStatusCount.repaid.length
      );
      break;
    case BidStatus.Liquidated:
      loanStatusCount.liquidated = removeFromArray(
        loanStatusCount.liquidated,
        bidId
      );
      loanStatusCount.liquidatedCount = BigInt.fromI32(
        loanStatusCount.liquidated.length
      );
      break;
    case BidStatus.None:
      return loanStatusCount;
    default:
      throw new Error(`Invalid bid status: ${status}`);
  }

  updateTotalLoanStatusCount(loanStatusCount);

  loanStatusCount.save();
  return loanStatusCount;
}

function updateTotalLoanStatusCount(loanStatusCount: LoanStatusCount): void {
  const allLoans = loanStatusCount.submitted
    .concat(loanStatusCount.accepted)
    .concat(loanStatusCount.dueSoon)
    .concat(loanStatusCount.late)
    .concat(loanStatusCount.defaulted)
    .concat(loanStatusCount.repaid)
    .concat(loanStatusCount.liquidated);
  loanStatusCount.all = allLoans;
  loanStatusCount.totalCount = BigInt.fromI32(allLoans.length);
}

export enum PaymentEventType {
  Repayment,
  Repaid,
  Liquidated
}

export function updateBidOnPayment(
  bid: Bid,
  event: ethereum.Event,
  paymentEventType: PaymentEventType
): void {
  if (bidStatusToEnum(bid.status) != BidStatus.Liquidated) {
    if (paymentEventType == PaymentEventType.Repayment) {
      updateBidStatus(bid, BidStatus.Accepted);
    } else if (paymentEventType == PaymentEventType.Repaid) {
      updateBidStatus(bid, BidStatus.Repaid);
    }
  }
  if (paymentEventType == PaymentEventType.Liquidated) {
    updateBidStatus(bid, BidStatus.Liquidated);
  }

  // NOTE: possible to have multiple payments in the same transaction
  const paymentId = event.transaction.hash.toHex();
  let payment = Payment.load(paymentId);
  if (!payment) {
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

    payment = createPaymentForBid(
      paymentId,
      bid,
      _lastPayment,
      _lastInterestPayment,
      paymentEventType,
      event.block.timestamp
    );

    updateBidTokenVolumesOnPayment(bid.id, payment);

    if (paymentEventType == PaymentEventType.Repayment) {
      bid.nextDueDate = tellerV2Instance.calculateNextDueDate(bid.bidId);
    } else {
      bid.nextDueDate = null;
    }

    bid.save();
  }
}

function createPaymentForBid(
  id: string,
  bid: Bid,
  principalAmount: BigInt,
  interestAmount: BigInt,
  eventType: PaymentEventType,
  timestamp: BigInt
): Payment {
  const payment = new Payment(id);
  payment.bid = bid.id;
  payment.principal = principalAmount;
  payment.interest = interestAmount;
  payment.paymentDate = timestamp;
  payment.outstandingCapital = bid.principal.minus(bid.totalRepaidPrincipal);
  if (eventType == PaymentEventType.Liquidated) {
    payment.status = "Liquidated";
  } else {
    if (isBidLate(bid, timestamp)) {
      payment.status = "Late";
    } else {
      payment.status = "On Time";
    }
  }
  payment.save();
  return payment;
}

function updateBidTokenVolumesOnPayment(
  bidId: string,
  lastPayment: Payment
): void {
  const bid = Bid.load(bidId);
  if (!bid) throw new Error(`Bid not found: ${bidId}`);

  const bidTokenVolumes = getTokenVolumesForBid(bid.id);
  for (let i = 0; i < bidTokenVolumes.length; i++) {
    const tokenVolume = bidTokenVolumes[i];
    tokenVolume.outstandingCapital = tokenVolume.outstandingCapital.minus(
      lastPayment.principal
    );
    // If the outstanding capital is less than 0, set it to 0
    if (tokenVolume.outstandingCapital.lt(BigInt.zero())) {
      tokenVolume.outstandingCapital = BigInt.zero();
    }

    tokenVolume.totalRepaidInterest = tokenVolume.totalRepaidInterest.plus(
      lastPayment.interest
    );

    tokenVolume.save();
  }
}

export function addBidToTokenVolume(tokenVolume: TokenVolume, bid: Bid): void {
  const loans = incrementLoanStatusCount(
    `tokenVolume-${tokenVolume.id}`,
    bid.id,
    bid.status
  );

  tokenVolume.outstandingCapital = tokenVolume.outstandingCapital.plus(
    bid.principal.minus(bid.totalRepaidPrincipal)
  );

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
  const loans = decrementLoanStatusCount(
    `tokenVolume-${tokenVolume.id}`,
    bid.id,
    bid.status
  );

  tokenVolume.outstandingCapital = tokenVolume.outstandingCapital.minus(
    bid.principal.minus(bid.totalRepaidPrincipal)
  );

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

export function replaceLender(bid: Bid, newLender: Lender): void {
  const oldLender = Lender.load(bid.lender!);
  if (!oldLender) throw new Error(`Lender not found for bid: ${bid.id}}`);
  const oldLenderVolume = loadLenderTokenVolume(
    Address.fromBytes(bid.lendingTokenAddress),
    oldLender
  );
  removeBidFromTokenVolume(oldLenderVolume, bid);
  decrementLoanStatusCount(`lender-${oldLender.id}`, bid.id, bid.status);

  bid.lender = newLender.id;
  bid.lenderAddress = newLender.lenderAddress;
  bid.save();

  const newLenderVolume = loadLenderTokenVolume(
    Address.fromBytes(bid.lendingTokenAddress),
    newLender
  );
  addBidToTokenVolume(newLenderVolume, bid);
  incrementLoanStatusCount(`lender-${newLender.id}`, bid.id, bid.status);
}
