import { Address, BigInt } from "@graphprotocol/graph-ts";

import { Transfer } from "../generated/LenderManager/LenderManager";
import { Bid, FundedTx, Lender } from "../generated/schema";
import {
  AcceptedBid,
  CancelledBid,
  FeePaid,
  LoanLiquidated,
  LoanRepaid,
  LoanRepayment,
  SubmittedBid,
  TellerV2
} from "../generated/TellerV2/TellerV2";

import { BidStatus } from "./helpers/bid";
import {
  getBid,
  loadBidById,
  loadBorrowerByMarketId,
  loadBorrowerTokenVolume,
  loadLenderByMarketId,
  loadMarketById,
  loadMarketTokenVolume,
  loadProtocolTokenVolume,
  loadToken
} from "./helpers/loaders";
import {
  PaymentEventType,
  replaceLender,
  updateBidOnPayment,
  updateBidStatus
} from "./helpers/updaters";
import { linkBidToRewards } from "./liquidity-rewards/updaters";

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
  bid.bidId = event.params.bidId;
  bid.borrower = borrower.id;
  bid.createdAt = event.block.timestamp;
  bid.updatedAt = event.block.timestamp;
  bid.transactionHash = event.transaction.hash.toHex();
  bid.borrowerAddress = event.params.borrower;

  bid.metadataURI = event.params.metadataURI.toHexString();
  
  /*if (tellerV2Instance.try_getMetadataURI(event.params.bidId).reverted) {
    
  } else {
    bid.metadataURI = tellerV2Instance.getMetadataURI(event.params.bidId);
  }*/

  const lendingToken = loadToken(storedBid.value5.lendingToken);
  bid.lendingToken = lendingToken.id;
  bid.lendingTokenAddress = lendingToken.address;
  bid.receiverAddress = storedBid.value1;
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

  loadBorrowerTokenVolume(lendingToken.id, borrower);

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

  updateBidStatus(bid, BidStatus.Submitted);

  bid.save();
  market.save();
}

export function handleSubmittedBids(events: SubmittedBid[]): void {
  events.forEach(event => {
    handleSubmittedBid(event);
  });
}

export function handleAcceptedBid(event: AcceptedBid): void {
  const bid = loadBidById(event.params.bidId);

  const tellerV2Instance = TellerV2.bind(event.address);

  const marketPlace = loadMarketById(bid.marketplace);

  const lender: Lender = loadLenderByMarketId(
    event.params.lender,
    marketPlace.id,
    event.block.timestamp
  );
  bid.lender = lender.id;

  const fundedTx = new FundedTx(event.transaction.hash.toHex());
  fundedTx.bid = bid.id;
  fundedTx.timestamp = event.block.timestamp;
  fundedTx.save();

  bid.updatedAt = event.block.timestamp;
  bid.transactionHash = event.transaction.hash.toHex();
  bid.acceptedTimestamp = event.block.timestamp;
  bid.endDate = bid.acceptedTimestamp.plus(bid.loanDuration);
  bid.nextDueDate = tellerV2Instance.calculateNextDueDate(event.params.bidId);
  bid.lenderAddress = event.params.lender;
  bid.save();

  updateBidStatus(bid, BidStatus.Accepted);

  linkBidToRewards(bid);
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

  updateBidStatus(bid, BidStatus.Cancelled);
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
  bid.save();

  updateBidOnPayment(bid, event, PaymentEventType.Repayment);
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
  bid.save();

  updateBidOnPayment(bid, event, PaymentEventType.Repaid);

  linkBidToRewards(bid);
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
  bid.liquidatorAddress = event.params.liquidator;
  bid.save();

  updateBidOnPayment(bid, event, PaymentEventType.Liquidated);
}

export function handleLoanLiquidateds(events: LoanLiquidated[]): void {
  events.forEach(event => {
    handleLoanLiquidated(event);
  });
}

export function handleFeePaid(event: FeePaid): void {
  const bid: Bid = loadBidById(event.params.bidId);

  if (
    event.params.feeType.toHexString() ==
    "0xfb342fa999fea16067b1f01baf96673f31a25f2b1443e6754d93fc40b57e8df2" // bytes value of "protocol"
  ) {
    const protocolVolume = loadProtocolTokenVolume(bid.lendingToken);
    protocolVolume.commissionEarned = protocolVolume.commissionEarned.plus(
      event.params.amount
    );
    protocolVolume.save();
  }

  if (
    event.params.feeType.toHexString() ==
    "0xcef6e888ca344077e889d6d961447b180a6f2c1f8a3a4b954e2385449143c6c8" // bytes value of "marketplace"
  ) {
    const marketVolume = loadMarketTokenVolume(
      bid.lendingToken,
      bid.marketplaceId.toString()
    );
    marketVolume.commissionEarned = marketVolume.commissionEarned.plus(
      event.params.amount
    );
    marketVolume.save();
  }
}

export function handleFeePaids(events: FeePaid[]): void {
  events.forEach(event => {
    handleFeePaid(event);
  });
}

/**
 * Sets a new lender when a bid is accepted or the ownership of a loan is transferred.
 * @param event NewLenderSet
 */
export function handleNewLenderSet(event: Transfer): void {
  // Ignore the mint event as it is not a transfer of ownership
  if (event.params.from == Address.zero()) return;

  const bid = loadBidById(event.params.tokenId);

  const newLender = loadLenderByMarketId(
    event.params.to,
    bid.marketplace,
    event.block.timestamp
  );
  replaceLender(bid, newLender);
}

export function handleNewLenderSets(events: Transfer[]): void {
  events.forEach(event => {
    handleNewLenderSet(event);
  });
}
