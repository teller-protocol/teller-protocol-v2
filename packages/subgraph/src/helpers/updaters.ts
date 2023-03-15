import {
  Address,
  BigInt,
  Entity,
  ethereum,
  Value
} from "@graphprotocol/graph-ts";

import { CollateralCommitted } from "../../generated/CollateralManager/CollateralManager";
import {
  Bid,
  Borrower,
  Collateral,
  Commitment,
  Lender,
  LoanStatusCount,
  MarketPlace,
  Payment,
  Protocol,
  TokenVolume
} from "../../generated/schema";
import { TellerV2 } from "../../generated/TellerV2/TellerV2";

import {
  BidStatus,
  bidStatusToEnum,
  bidStatusToString,
  BidStatusValues,
  isBidLate
} from "./bid";
import { initTokenVolume } from "./intializers";
import {
  getBid,
  loadBorrowerByMarketId,
  loadBorrowerTokenVolume,
  loadCommitmentTokenVolume,
  loadLenderByMarketId,
  loadLenderTokenVolume,
  loadProtocolTokenVolume,
  loadToken,
  loadTokenVolumeByMarketId
} from "./loaders";
import { addToArray, camelize, removeFromArray } from "./utils";

/**
 * Updates the status of a bid. Returns the previous status.
 * @param bid {Bid} - The bid to update
 * @param status {BidStatus} - The new status of the bid
 * @returns The previous status of the bid
 */
export function updateBidStatus(bid: Bid, status: BidStatus): BidStatus {
  const prevStatus = bid.isSet("status") ? bid.status : "";
  bid.status = bidStatusToString(status);
  bid.save();
  updateLoanStatusCountsFromBid(bid.id, prevStatus);
  return bidStatusToEnum(prevStatus);
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

  const commitmentId = bid.commitment;
  if (commitmentId) {
    const commitment = Commitment.load(commitmentId);
    if (!commitment)
      throw new Error(`Commitment ${commitmentId} does not exist`);

    const commitmentVolume = loadCommitmentTokenVolume(
      lendingTokenAddress,
      commitment
    );
    tokenVolumes.push(commitmentVolume);
  }

  return tokenVolumes;
}

function updateLoanStatusCountsFromBid(
  bidId: string,
  prevStatus: string
): void {
  const bid = Bid.load(bidId);
  if (!bid) throw new Error(`Bid ${bidId} does not exist`);

  const loanStatusCountIds = getLoanStatusCountIdsForBid(bidId);
  for (let i = 0; i < loanStatusCountIds.length; i++) {
    const countId = loanStatusCountIds[i];
    const loanStatusCount = LoanStatusCount.load(countId);
    if (!loanStatusCount)
      throw new Error(`Loan status count not found: ${countId}`);

    // Decrement the previous status count before incrementing the new status count
    // This is to prevent the count from being decremented if the status is the same
    updateLoanStatusCount(
      loanStatusCount,
      bid.id,
      prevStatus,
      ArrayUpdaterFn.DELETE
    );
    updateLoanStatusCount(
      loanStatusCount,
      bid.id,
      bid.status,
      ArrayUpdaterFn.ADD
    );
  }
}

enum ArrayUpdaterFn {
  ADD,
  DELETE
}
function updateLoanStatusCount(
  loanStatusCount: LoanStatusCount,
  bidId: string,
  statusStr: string,
  fnNameType: ArrayUpdaterFn
): void {
  const status = bidStatusToEnum(statusStr);
  if (status === BidStatus.None) return;

  const arrayName = camelize(statusStr);
  const countName = `${arrayName}Count`;
  const arrayValue = loanStatusCount.get(arrayName);
  if (arrayValue) {
    const arrayOrig = arrayValue.toStringArray();
    const arrayUpdated =
      fnNameType == ArrayUpdaterFn.ADD
        ? addToArray(arrayOrig, bidId)
        : removeFromArray(arrayOrig, bidId);

    if (arrayOrig.length != arrayUpdated.length) {
      loanStatusCount.set(arrayName, Value.fromStringArray(arrayUpdated));
      loanStatusCount.set(
        countName,
        Value.fromBigInt(BigInt.fromI32(arrayUpdated.length))
      );

      let allLoans: string[] = [];
      // Skip the first element because it is the "None" status
      for (let i = 1; i < BidStatusValues.length; i++) {
        const loanStatusArray = loanStatusCount.mustGet(
          camelize(BidStatusValues[i])
        );
        allLoans = allLoans.concat(loanStatusArray.toStringArray());
      }
      loanStatusCount.all = allLoans;
      loanStatusCount.totalCount = BigInt.fromI32(allLoans.length);
      loanStatusCount.save();

      const acceptedLoanStatuses = [
        BidStatus.Accepted,
        BidStatus.DueSoon,
        BidStatus.Late,
        BidStatus.Defaulted,
        BidStatus.Repaid,
        BidStatus.Liquidated
      ];
      if (acceptedLoanStatuses.includes(status)) {
        switch (fnNameType) {
          case ArrayUpdaterFn.ADD:
            addBidToTokenVolumeFromStatusCount(loanStatusCount, bidId);
            break;
          case ArrayUpdaterFn.DELETE:
            removeBidFromTokenVolumeFromStatusCount(loanStatusCount, bidId);
            break;
        }
      }
    }

    loanStatusCount.save();
  }
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

function addBidToTokenVolumeFromStatusCount(
  loanStatusCount: LoanStatusCount,
  bidId: string
): void {
  const tokenVolumeId = loanStatusCount._tokenVolume;
  if (!tokenVolumeId) return;
  const tokenVolume = TokenVolume.load(tokenVolumeId ? tokenVolumeId : "");
  if (!tokenVolume) throw new Error("TokenVolume not found");

  const bid = Bid.load(bidId);
  if (!bid) throw new Error(`Bid not found: ${bidId}`);

  tokenVolume._loanAcceptedCount = tokenVolume._loanAcceptedCount.plus(
    BigInt.fromI32(1)
  );
  tokenVolume.outstandingCapital = tokenVolume.outstandingCapital.plus(
    bid.principal.minus(bid.totalRepaidPrincipal)
  );
  tokenVolume.totalLoaned = tokenVolume.totalLoaned.plus(bid.principal);
  tokenVolume.loanAverage = tokenVolume.totalLoaned.div(
    tokenVolume._loanAcceptedCount
  );

  tokenVolume._aprWeightedTotal = tokenVolume._aprWeightedTotal.plus(
    bid.apr.times(bid.principal)
  );
  tokenVolume.aprAverage = tokenVolume._aprWeightedTotal.div(
    tokenVolume.totalLoaned
  );

  updateDurationAverageFromStatusCount(
    UpdateDurationAverage.Add,
    loanStatusCount,
    bid
  );

  tokenVolume.save();
}

function removeBidFromTokenVolumeFromStatusCount(
  loanStatusCount: LoanStatusCount,
  bidId: string
): void {
  const tokenVolumeId = loanStatusCount._tokenVolume;
  if (!tokenVolumeId) return;
  const tokenVolume = TokenVolume.load(tokenVolumeId ? tokenVolumeId : "");
  if (!tokenVolume) throw new Error("TokenVolume not found");

  const bid = Bid.load(bidId);
  if (!bid) throw new Error(`Bid not found: ${bidId}`);

  tokenVolume._loanAcceptedCount = tokenVolume._loanAcceptedCount.minus(
    BigInt.fromI32(1)
  );
  if (tokenVolume._loanAcceptedCount.isZero()) {
    initTokenVolume(tokenVolume, loadToken(bid.lendingTokenAddress));
  } else {
    tokenVolume.outstandingCapital = tokenVolume.outstandingCapital.minus(
      bid.principal.minus(bid.totalRepaidPrincipal)
    );
    tokenVolume.totalLoaned = tokenVolume.totalLoaned.minus(bid.principal);
    tokenVolume.loanAverage = tokenVolume.totalLoaned.div(
      tokenVolume._loanAcceptedCount
    );

    tokenVolume._aprWeightedTotal = tokenVolume._aprWeightedTotal.minus(
      bid.apr.times(bid.principal)
    );
    tokenVolume.aprAverage = tokenVolume._aprWeightedTotal.div(
      tokenVolume._loanAcceptedCount
    );

    updateDurationAverageFromStatusCount(
      UpdateDurationAverage.Remove,
      loanStatusCount,
      bid
    );
  }

  tokenVolume.save();
}

enum UpdateDurationAverage {
  Add,
  Remove
}
function updateDurationAverageFromStatusCount(
  type: UpdateDurationAverage,
  loanStatusCount: LoanStatusCount,
  bid: Bid
): void {
  const tokenVolumeId = loanStatusCount._tokenVolume;
  if (tokenVolumeId) {
    const tokenVolume = TokenVolume.load(tokenVolumeId);
    if (!tokenVolume)
      throw new Error(`TokenVolume not found: ${tokenVolumeId}`);

    setEntityDurationAverage(
      type,
      tokenVolume,
      bid,
      loanStatusCount.totalCount
    );
    tokenVolume.save();
  }

  const protocolId = loanStatusCount._protocol;
  if (protocolId) {
    const protocol = Protocol.load(protocolId);
    if (!protocol) throw new Error(`Protocol not found: ${protocolId}`);

    setEntityDurationAverage(type, protocol, bid, loanStatusCount.totalCount);
    protocol.save();
  }

  const marketId = loanStatusCount._market;
  if (marketId) {
    const market = MarketPlace.load(marketId);
    if (!market) throw new Error(`Market not found: ${marketId}`);

    setEntityDurationAverage(type, market, bid, loanStatusCount.totalCount);
    market.save();
  }

  const lenderId = loanStatusCount._lender;
  if (lenderId) {
    const lender = Lender.load(lenderId);
    if (!lender) throw new Error(`Lender not found: ${lenderId}`);

    setEntityDurationAverage(type, lender, bid, loanStatusCount.totalCount);
    lender.save();
  }

  const borrowerId = loanStatusCount._borrower;
  if (borrowerId) {
    const borrower = Borrower.load(borrowerId);
    if (!borrower) throw new Error(`Borrower not found: ${borrowerId}`);

    setEntityDurationAverage(type, borrower, bid, loanStatusCount.totalCount);
    borrower.save();
  }
}

function setEntityDurationAverage(
  type: UpdateDurationAverage,
  entity: Entity,
  bid: Bid,
  totalLoanCount: BigInt
): void {
  let durationTotal = entity.mustGet("_durationTotal").toBigInt();

  const updateAmount = bid.loanDuration.times(bid.principal);
  durationTotal =
    type == UpdateDurationAverage.Add
      ? durationTotal.plus(updateAmount)
      : durationTotal.minus(updateAmount);
  entity.set("_durationTotal", Value.fromBigInt(durationTotal));
  entity.set(
    "durationAverage",
    Value.fromBigInt(durationTotal.div(totalLoanCount))
  );
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
  const oldLenderCount = LoanStatusCount.load(`lender-${bid.lender!}`);
  if (!oldLenderCount)
    throw new Error(`LoanStatusCount not found: ${bid.lender!}`);
  updateLoanStatusCount(
    oldLenderCount,
    bid.id,
    bid.status,
    ArrayUpdaterFn.DELETE
  );

  bid.lender = newLender.id;
  bid.lenderAddress = newLender.lenderAddress;
  bid.save();

  const newLenderCount = LoanStatusCount.load(`lender-${newLender.id}`);
  if (!newLenderCount)
    throw new Error(`LoanStatusCount not found: ${newLender.id}`);
  updateLoanStatusCount(newLenderCount, bid.id, bid.status, ArrayUpdaterFn.ADD);
}
