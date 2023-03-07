import { Address, BigInt, ethereum } from "@graphprotocol/graph-ts";

import { CollateralCommitted } from "../../generated/CollateralManager/CollateralManager";
import {
  Bid,
  Borrower,
  Collateral,
  Commitment,
  Lender,
  LoanCount,
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
  loadBorrowerTokenVolume,
  loadLenderByMarketId,
  loadLenderTokenVolume,
  loadMarketById,
  loadProtocolTokenVolume,
  loadTokenVolumeByMarketId
} from "./loaders";
import { addToArray, removeFromArray } from "./utils";

export function updateTokenVolumeOnPayment(
  lastPayment: BigInt,
  lastInterestPayment: BigInt,
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

export function getLoanCountIdsForBid(bid: Bid): string[] {
  const loanCountIds = [
    "protocol-v2",
    `market-${bid.marketplace}`,
    `borrower-${bid.borrower}`
  ];

  const lenderId = bid.lender;
  if (lenderId) loanCountIds.push(`lender-${lenderId}`);

  const tokenVolumes = getTokenVolumesForBid(bid);
  for (let i = 0; i < tokenVolumes.length; i++) {
    loanCountIds.push(`tokenVolume-${tokenVolumes[i].id}`);
  }

  return loanCountIds;
}

export function getTokenVolumesForBid(bid: Bid): TokenVolume[] {
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

export function updateLoanCountsFromBid(bid: Bid, prevStatus: string): void {
  const loanCountIds = getLoanCountIdsForBid(bid);
  for (let i = 0; i < loanCountIds.length; i++) {
    incrementLoanCount(loanCountIds[i], bid.id, bid.status);
    decrementLoanCount(loanCountIds[i], bid.id, prevStatus);
  }
}

export function incrementLoanCount(
  loanCountId: string,
  bidId: string,
  status: string
): LoanCount {
  const loanCount = LoanCount.load(loanCountId);
  if (!loanCount) throw new Error(`Loan count not found: ${loanCountId}`);

  const bidStatus = bidStatusToEnum(status);
  switch (bidStatus) {
    case BidStatus.Submitted:
      loanCount.submitted = addToArray(loanCount.submitted, bidId);
      loanCount.submittedCount = BigInt.fromI32(loanCount.submitted.length);
      break;
    case BidStatus.Cancelled:
      loanCount.cancelled = addToArray(loanCount.cancelled, bidId);
      loanCount.cancelledCount = BigInt.fromI32(loanCount.cancelled.length);
      break;
    case BidStatus.Accepted:
      loanCount.accepted = addToArray(loanCount.accepted, bidId);
      loanCount.acceptedCount = BigInt.fromI32(loanCount.accepted.length);
      break;
    case BidStatus.Repaid:
      loanCount.repaid = addToArray(loanCount.repaid, bidId);
      loanCount.repaidCount = BigInt.fromI32(loanCount.repaid.length);
      break;
    case BidStatus.Late:
      loanCount.late = addToArray(loanCount.late, bidId);
      loanCount.lateCount = BigInt.fromI32(loanCount.late.length);
      break;
    case BidStatus.Defaulted:
      loanCount.defaulted = addToArray(loanCount.defaulted, bidId);
      loanCount.defaultedCount = BigInt.fromI32(loanCount.defaulted.length);
      break;
    case BidStatus.Liquidated:
      loanCount.liquidated = addToArray(loanCount.liquidated, bidId);
      loanCount.liquidatedCount = BigInt.fromI32(loanCount.liquidated.length);
      break;
    case BidStatus.None:
      return loanCount;
    default:
      throw new Error(`Invalid bid status: ${status}`);
  }

  updateTotalLoanCount(loanCount);

  loanCount.save();
  return loanCount;
}

export function decrementLoanCount(
  loanCountId: string,
  bidId: string,
  status: string
): LoanCount {
  const loanCount = LoanCount.load(loanCountId);
  if (!loanCount) throw new Error(`Loan count not found: ${loanCountId}`);

  const bidStatus = bidStatusToEnum(status);
  switch (bidStatus) {
    case BidStatus.Submitted:
      loanCount.submitted = removeFromArray(loanCount.submitted, bidId);
      loanCount.submittedCount = BigInt.fromI32(loanCount.submitted.length);
      break;
    case BidStatus.Cancelled:
      loanCount.cancelled = removeFromArray(loanCount.cancelled, bidId);
      loanCount.cancelledCount = BigInt.fromI32(loanCount.cancelled.length);
      break;
    case BidStatus.Accepted:
      loanCount.accepted = removeFromArray(loanCount.accepted, bidId);
      loanCount.acceptedCount = BigInt.fromI32(loanCount.accepted.length);
      break;
    case BidStatus.Repaid:
      loanCount.repaid = removeFromArray(loanCount.repaid, bidId);
      loanCount.repaidCount = BigInt.fromI32(loanCount.repaid.length);
      break;
    case BidStatus.Late:
      loanCount.late = removeFromArray(loanCount.late, bidId);
      loanCount.lateCount = BigInt.fromI32(loanCount.late.length);
      break;
    case BidStatus.Defaulted:
      loanCount.defaulted = removeFromArray(loanCount.defaulted, bidId);
      loanCount.defaultedCount = BigInt.fromI32(loanCount.defaulted.length);
      break;
    case BidStatus.Liquidated:
      loanCount.liquidated = removeFromArray(loanCount.liquidated, bidId);
      loanCount.liquidatedCount = BigInt.fromI32(loanCount.liquidated.length);
      break;
    case BidStatus.None:
      return loanCount;
    default:
      throw new Error(`Invalid bid status: ${status}`);
  }

  updateTotalLoanCount(loanCount);

  loanCount.save();
  return loanCount;
}

function updateTotalLoanCount(loanCount: LoanCount): void {
  const allLoans = loanCount.submitted
    .concat(loanCount.accepted)
    .concat(loanCount.repaid)
    .concat(loanCount.late)
    .concat(loanCount.defaulted)
    .concat(loanCount.liquidated);
  loanCount.all = allLoans;
  loanCount.totalCount = BigInt.fromI32(allLoans.length);
}

export enum PaymentEventType {
  Repayment,
  Repaid,
  Liquidated
}

export function updateBidOnPayment(
  bid: Bid,
  event: ethereum.Event,
  paymentEventType: PaymentEventType,
  prevStatus: string
): void {
  // If a loan is liquidated, a repaid event is also emitted from the contract.
  // When this happens, we want to ignore the repaid event and only handle the liquidated event.
  // Liquidation events should be handled first via subgraph.template.yaml
  if (
    bidStatusToEnum(bid.status) == BidStatus.Liquidated &&
    paymentEventType != PaymentEventType.Liquidated
  )
    return;

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

  updateOutstandingCapital(bid, storedBid, _lastPayment, _lastInterestPayment);

  const payment = new Payment(event.transaction.hash.toHex());
  payment.bid = bid.id;
  payment.principal = _lastPayment;
  payment.interest = _lastInterestPayment;
  payment.paymentDate = event.block.timestamp;
  payment.outstandingCapital = bid.principal.minus(bid.totalRepaidPrincipal);
  if (paymentEventType == PaymentEventType.Liquidated) {
    payment.status = "Liquidated";
  } else {
    if (isBidLate(bid, event.block)) {
      payment.status = "Late";
    } else {
      payment.status = "On Time";
    }
  }
  payment.save();

  if (paymentEventType == PaymentEventType.Repayment) {
    bid.nextDueDate = tellerV2Instance.calculateNextDueDate(bid.bidId);
  } else {
    bid.nextDueDate = null;
  }

  bid.save();

  updateLoanCountsFromBid(bid, prevStatus);
}

export function addBidToTokenVolume(tokenVolume: TokenVolume, bid: Bid): void {
  const loans = incrementLoanCount(
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
  const loans = decrementLoanCount(
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

export function updateOutstandingCapital(
  bid: Bid,
  storedBid: TellerV2__bidsResult,
  _lastPayment: BigInt,
  _lastInterestPayment: BigInt
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
  updateTokenVolumeOnPayment(_lastPayment, _lastInterestPayment, tokenVolume);

  // Update protocol's overall token volume
  const protocolVolume = loadProtocolTokenVolume(storedBid.value5.lendingToken);
  updateTokenVolumeOnPayment(
    _lastPayment,
    _lastInterestPayment,
    protocolVolume
  );

  // Update lender's token volume
  const lenderVolume = loadLenderTokenVolume(
    storedBid.value5.lendingToken,
    lender
  );
  updateTokenVolumeOnPayment(_lastPayment, _lastInterestPayment, lenderVolume);
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

export function replaceLender(bid: Bid, newLender: Lender): void {
  const oldLender = Lender.load(bid.lender!);
  if (!oldLender) throw new Error(`Lender not found for bid: ${bid.id}}`);
  const oldLenderVolume = loadLenderTokenVolume(
    Address.fromBytes(bid.lendingTokenAddress),
    oldLender
  );
  removeBidFromTokenVolume(oldLenderVolume, bid);
  decrementLoanCount(`lender-${oldLender.id}`, bid.id, bid.status);

  bid.lender = newLender.id;
  bid.lenderAddress = newLender.lenderAddress;
  bid.save();

  const newLenderVolume = loadLenderTokenVolume(
    Address.fromBytes(bid.lendingTokenAddress),
    newLender
  );
  addBidToTokenVolume(newLenderVolume, bid);
  incrementLoanCount(`lender-${newLender.id}`, bid.id, bid.status);
}
