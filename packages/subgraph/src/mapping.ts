import { Address, BigInt } from "@graphprotocol/graph-ts";

import { Transfer } from "../generated/LenderManager/LenderManager";
import {
  Bid,
  BorrowerBid,
  FundedTx,
  Lender,
  LenderBid,
  LoanCounts
} from "../generated/schema";
import {
  AcceptedBid,
  CancelledBid,
  FeePaid,
  LoanLiquidated,
  LoanRepaid,
  LoanRepayment,
  SubmittedBid,
  TellerV2,
  Upgraded
} from "../generated/TellerV2/TellerV2";

import {
  getBid,
  loadBidById,
  loadBorrowerByMarketId,
  loadBorrowerFromBidId,
  loadBorrowerTokenVolume,
  loadLenderByMarketId,
  loadMarketById,
  loadProtocolTokenVolume,
  loadTokenVolumeByMarketId
} from "./helpers/loaders";
import {
  decrementLenderStats,
  incrementLenderStats,
  updateBidOnPayment,
  updateBidTokenVolumesOnAccept,
  updateLoanCountsFromBid
} from "./helpers/updaters";

export function handleSubmittedBid(event: SubmittedBid): void {
  const tellerV2Instance = TellerV2.bind(event.address);
  const storedBid = getBid(event.address, event.params.bidId);

  const market = loadMarketById(storedBid.value3.toString());

  // Creates User + Borrower entity if it doesn't exist
  const borrower = loadBorrowerByMarketId(
    event.params.borrower,
    market.id,
    event.block.timestamp
  );

  const bid = new Bid(event.params.bidId.toString());

  const borrowerBid = new BorrowerBid(bid.id);
  borrowerBid.bid = bid.id;
  borrowerBid.borrower = borrower.id;
  borrowerBid.save();

  bid.bidId = event.params.bidId;
  bid.createdAt = event.block.timestamp;
  bid.updatedAt = event.block.timestamp;
  bid.transactionHash = event.transaction.hash.toHex();
  bid.borrowerAddress = event.params.borrower;
  bid.status = "Submitted";

  if (tellerV2Instance.try_getMetadataURI(event.params.bidId).reverted) {
    bid.metadataURI = event.params.metadataURI.toHexString();
  } else {
    bid.metadataURI = tellerV2Instance.getMetadataURI(event.params.bidId);
  }

  const lendingTokenAddress = storedBid.value5.lendingToken;
  bid.receiverAddress = storedBid.value1;
  bid.lendingTokenAddress = lendingTokenAddress;
  bid.principal = storedBid.value5.principal;
  bid.loanDuration = storedBid.value5.loanDuration;
  bid.paymentCycle = storedBid.value6.paymentCycle;
  bid.paymentCycleAmount = storedBid.value6.paymentCycleAmount;
  bid._lastTotalRepaidAmount = BigInt.zero();
  bid._lastTotalRepaidInterestAmount = BigInt.zero();
  bid.apr = BigInt.fromI32(storedBid.value6.APR);
  bid.totalRepaidInterest = BigInt.zero();
  bid.totalRepaidPrincipal = BigInt.zero();
  bid.endDate = BigInt.zero();
  bid.acceptedTimestamp = BigInt.zero();
  bid.lastRepaidTimestamp = BigInt.zero();
  bid.nextDueDate = BigInt.zero();

  bid.marketplace = market.id;
  bid.marketplaceId = BigInt.fromString(market.id);

  loadBorrowerTokenVolume(lendingTokenAddress, borrower);

  if (!tellerV2Instance.try_bidExpirationTime(event.params.bidId).reverted) {
    bid.expiresAt = event.block.timestamp.plus(
      tellerV2Instance.bidExpirationTime(event.params.bidId)
    );
  } else {
    bid.expiresAt = BigInt.zero();
  }

  const paymentDefaultDuration = market.paymentDefaultDuration;
  if (paymentDefaultDuration) {
    bid.paymentDefaultDuration = paymentDefaultDuration;
  } else {
    bid.paymentDefaultDuration = BigInt.zero();
  }

  bid.save();
  market.save();

  updateLoanCountsFromBid(bid, "");
}

export function handleSubmittedBids(events: SubmittedBid[]): void {
  events.forEach(event => {
    handleSubmittedBid(event);
  });
}

export function handleAcceptedBid(event: AcceptedBid): void {
  const bid = loadBidById(event.params.bidId);
  const borrower = loadBorrowerFromBidId(bid.id);

  const tellerV2Instance = TellerV2.bind(event.address);

  const marketPlace = loadMarketById(bid.marketplace);

  const lender: Lender = loadLenderByMarketId(
    event.params.lender,
    marketPlace.id,
    event.block.timestamp
  );

  const lenderBid = new LenderBid(bid.id);
  lenderBid.bid = bid.id;
  lenderBid.lender = lender.id;
  lenderBid.save();

  const fundedTx = new FundedTx(event.transaction.hash.toHex());
  fundedTx.bid = bid.id;
  fundedTx.timestamp = event.block.timestamp;
  fundedTx.save();

  bid.updatedAt = event.block.timestamp;
  bid.transactionHash = event.transaction.hash.toHex();
  bid.status = "Accepted";
  bid.acceptedTimestamp = event.block.timestamp;
  bid.endDate = bid.acceptedTimestamp.plus(bid.loanDuration);
  bid.nextDueDate = tellerV2Instance.calculateNextDueDate(event.params.bidId);
  bid.lenderAddress = event.params.lender;
  bid.save();
  updateLoanCountsFromBid(bid, "Submitted");

  // Update market entity
  const marketLoanStats = LoanCounts.load(marketPlace.loanCounts);
  if (marketLoanStats) {
    marketPlace._aprTotal = marketPlace._aprTotal.plus(bid.apr);
    marketPlace.aprAverage = marketPlace._aprTotal.div(marketLoanStats.total);

    marketPlace._durationTotal = marketPlace._durationTotal.plus(
      bid.loanDuration
    );
    marketPlace.durationAverage = marketPlace._durationTotal.div(
      marketLoanStats.total
    );

    marketPlace.save();
  }

  updateBidTokenVolumesOnAccept(bid);
}

export function handleAcceptedBids(events: AcceptedBid[]): void {
  events.forEach(event => {
    handleAcceptedBid(event);
  });
}

export function handleCancelledBid(event: CancelledBid): void {
  const bid: Bid = loadBidById(event.params.bidId);

  bid.updatedAt = event.block.timestamp;
  bid.transactionHash = event.transaction.hash.toHex();
  bid.status = "Cancelled";
  bid.save();

  updateLoanCountsFromBid(bid, "Submitted");
}

export function handleCancelledBids(events: CancelledBid[]): void {
  events.forEach(event => {
    handleCancelledBid(event);
  });
}

export function handleLoanRepayment(event: LoanRepayment): void {
  const bid: Bid = loadBidById(event.params.bidId);
  bid.updatedAt = event.block.timestamp;
  bid.transactionHash = event.transaction.hash.toHex();
  updateBidOnPayment(bid, event, "Repayment");
}

export function handleLoanRepayments(events: LoanRepayment[]): void {
  events.forEach(event => {
    handleLoanRepayment(event);
  });
}

export function handleLoanRepaid(event: LoanRepaid): void {
  const bid: Bid = loadBidById(event.params.bidId);

  bid.updatedAt = event.block.timestamp;
  bid.transactionHash = event.transaction.hash.toHex();

  const prevStatus = bid.status;
  updateBidOnPayment(bid, event, "Repaid");
  updateLoanCountsFromBid(bid, prevStatus);
}

export function handleLoanRepaids(events: LoanRepaid[]): void {
  events.forEach(event => {
    handleLoanRepaid(event);
  });
}

export function handleLoanLiquidated(event: LoanLiquidated): void {
  const bid: Bid = loadBidById(event.params.bidId);

  bid.updatedAt = event.block.timestamp;
  bid.transactionHash = event.transaction.hash.toHex();

  const prevStatus = bid.status;
  updateBidOnPayment(bid, event, "Liquidated");
  updateLoanCountsFromBid(bid, prevStatus);
}

export function handleLoanLiquidateds(events: LoanLiquidated[]): void {
  events.forEach(event => {
    handleLoanLiquidated(event);
  });
}

export function handleFeePaid(event: FeePaid): void {
  const bid: Bid = loadBidById(event.params.bidId);
  const lendingTokenAddress = Address.fromBytes(bid.lendingTokenAddress);

  // If indexed fee type is `marketplace`
  if (
    event.params.feeType.toHexString() ==
    "0xcef6e888ca344077e889d6d961447b180a6f2c1f8a3a4b954e2385449143c6c8" // bytes value of "marketplace"
  ) {
    const tokenVolume = loadTokenVolumeByMarketId(
      lendingTokenAddress,
      bid.marketplaceId.toString()
    );
    const marketCommissionEarned = tokenVolume.commissionEarned;
    tokenVolume.commissionEarned = marketCommissionEarned.plus(
      event.params.amount
    );
    tokenVolume.save();
    const protocolVolume = loadProtocolTokenVolume(lendingTokenAddress);
    if (protocolVolume) {
      const protocolCommissionEarned = protocolVolume.commissionEarned;
      protocolVolume.commissionEarned = protocolCommissionEarned.plus(
        event.params.amount
      );
      protocolVolume.save();
    }
  }
}

export function handleFeePaids(events: FeePaid[]): void {
  events.forEach(event => {
    handleFeePaid(event);
  });
}

export function handleTellerV2Upgraded(event: Upgraded): void {
  if (
    event.params.implementation.equals(
      Address.fromString("0xf39674f4d3878a732cb4c70b377c013affb89c1f")
    )
  ) {
    for (let i = 62; i < 66; i++) {
      const storedBid = getBid(event.address, BigInt.fromI32(i));
      const bid = loadBidById(BigInt.fromI32(i));
      if (bid.bidId) {
        bid.paymentCycleAmount = storedBid.value6.paymentCycleAmount;
        bid.save();
      }
    }
  }
}

/**
 * Sets a new lender when a bid is accepted or the ownership of a loan is transferred.
 * @param event NewLenderSet
 */
export function handleNewLenderSet(event: Transfer): void {
  // Ignore the mint event as it is not a transfer of ownership
  if (event.params.from == Address.zero()) return;

  const bid = loadBidById(event.params.tokenId);
  bid.lenderAddress = event.params.to;
  bid.save();

  const oldLender = loadLenderByMarketId(event.params.from, bid.marketplace);
  decrementLenderStats(oldLender, bid);

  const newLender = loadLenderByMarketId(
    event.params.to,
    bid.marketplace,
    event.block.timestamp
  );
  const lenderBid = new LenderBid(bid.id);
  lenderBid.lender = newLender.id;
  lenderBid.save();
  incrementLenderStats(newLender, bid);
}

export function handleNewLenderSets(events: Transfer[]): void {
  events.forEach(event => {
    handleNewLenderSet(event);
  });
}
