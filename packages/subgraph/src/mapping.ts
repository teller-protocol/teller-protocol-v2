import { Address, BigInt } from "@graphprotocol/graph-ts";

import {
  CollateralClaimed,
  CollateralCommitted,
  CollateralDeposited,
  CollateralEscrowDeployed,
  CollateralWithdrawn
} from "../generated/CollateralManager/CollateralManager";
import { Transfer } from "../generated/LenderManager/LenderManager";
import {
  Bid,
  BorrowerBid,
  FundedTx,
  Lender,
  LenderBid
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
  loadBorrowerTokenVolume,
  loadCollateral,
  loadLenderByMarketId,
  loadMarketById,
  loadProtocolTokenVolume,
  loadTokenVolumeByMarketId,
} from "./helpers/loaders";
import {
  decrementLenderStats,
  incrementLenderStats,
  updateBid,
  updateCollateral,
  updateBidTokenVolumesOnAccept
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
  const borrowerBid = new BorrowerBid(borrower.id.concat(bid.id));
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

  const requests = market.openRequests;
  if (requests) {
    market.openRequests = requests.plus(BigInt.fromI32(1));
  }

  if (!tellerV2Instance.try_bidExpirationTime(event.params.bidId).reverted) {
    bid.expiresAt = event.block.timestamp.plus(
      tellerV2Instance.bidExpirationTime(event.params.bidId)
    );
  } else {
    bid.expiresAt = BigInt.zero();
  }

  const marketPlace = loadMarketById(storedBid.value3.toString());

  const paymentDefaultDuration = marketPlace.paymentDefaultDuration;
  if (paymentDefaultDuration) {
    bid.paymentDefaultDuration = paymentDefaultDuration;
  } else {
    bid.paymentDefaultDuration = BigInt.zero();
  }

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

  // Update market entity
  const requests = marketPlace.openRequests;
  const marketFee = marketPlace.marketplaceFeePercent;
  const activeLoanCount = marketPlace.activeLoans;

  const _aprTotal = marketPlace._aprTotal;
  const _durationTotal = marketPlace._durationTotal;

  if (requests && marketFee && activeLoanCount && _durationTotal) {
    const updatedAPRTotal = _aprTotal.plus(bid.apr);
    const updatedActiveLoans = activeLoanCount.plus(BigInt.fromI32(1));
    marketPlace.openRequests = requests.minus(BigInt.fromI32(1));
    marketPlace.activeLoans = updatedActiveLoans;

    marketPlace._aprTotal = updatedAPRTotal;
    const totalLoans = updatedActiveLoans.plus(marketPlace.closedLoans);
    marketPlace.aprAverage = updatedAPRTotal.div(totalLoans);

    const updatedDurationTotal = _durationTotal.plus(bid.loanDuration);
    marketPlace._durationTotal = updatedDurationTotal;
    marketPlace.durationAverage = updatedDurationTotal.div(totalLoans);
    marketPlace.save();
  }

  // Update borrower entity
  const borrower = loadBorrowerByMarketId(
    Address.fromBytes(bid.borrowerAddress),
    marketPlace.id
  );
  if (borrower) {
    borrower.activeLoans = borrower.activeLoans.plus(BigInt.fromI32(1));
    borrower.bidsAccepted = borrower.bidsAccepted.plus(BigInt.fromI32(1));
    borrower.save();
  }

  updateBidTokenVolumesOnAccept(bid, borrower, lender);
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

  const marketPlace = loadMarketById(bid.marketplaceId.toString());
  const requests = marketPlace.openRequests;
  if (requests) {
    marketPlace.openRequests = requests.minus(BigInt.fromI32(1));
    marketPlace.save();
  }

  bid.save();
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
  updateBid(bid, event, "Repayment");
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

  updateBid(bid, event, "Repaid");
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

  updateBid(bid, event, "Liquidated");
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

export function handleCollateralEscrowDeployed(
  event: CollateralEscrowDeployed
): void {
  const bid: Bid = loadBidById(event.params._bidId);
  bid.collateralEscrow = event.params._collateralEscrow;
  bid.save();
}

export function handleCollateralEscrowDeployeds(
  events: CollateralEscrowDeployed[]
): void {
  events.forEach(event => {
    handleCollateralEscrowDeployed(event);
  });
}

export function handleCollateralCommitted(event: CollateralCommitted): void {
  // Load collateral by bidId and collateral address
  const collateral = loadCollateral(
    event.params._bidId.toString(),
    event.params._collateralAddress
  );
  updateCollateral(collateral, event);
  collateral.status = "Committed";
  collateral.save();
}

export function handleCollateralCommitteds(
  events: CollateralCommitted[]
): void {
  events.forEach(event => {
    handleCollateralCommitted(event);
  });
}

export function handleCollateralDeposited(event: CollateralDeposited): void {
  const collateral = loadCollateral(
    event.params._bidId.toString(),
    event.params._collateralAddress
  );
  updateCollateral(collateral, event);
  collateral.status = "Deposited";
  collateral.save();
}

export function handleCollateralDepositeds(
  events: CollateralDeposited[]
): void {
  events.forEach(event => {
    handleCollateralDeposited(event);
  });
}

export function handleCollateralWithdrawn(event: CollateralWithdrawn): void {
  const collateral = loadCollateral(
    event.params._bidId.toString(),
    event.params._collateralAddress
  );
  updateCollateral(collateral, event);
  collateral.receiver = event.params._recipient;
  collateral.status = "Withdrawn";
  collateral.save();
}

export function handleCollateralWithdrawns(
  events: CollateralWithdrawn[]
): void {
  events.forEach(event => {
    handleCollateralWithdrawn(event);
  });
}

/**
 * Sets the bid status to `Liquidated` when the collateral is claimed from a defaulted loan.
 * @param event
 */
export function handleCollateralClaimed(event: CollateralClaimed): void {
  const bid = loadBidById(event.params._bidId);
  bid.status = "Liquidated";
  bid.save();
}

export function handleCollateralClaimeds(events: CollateralClaimed[]): void {
  events.forEach(event => {
    handleCollateralClaimed(event);
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
  bid.lenderAddress = event.params.to;
  bid.save();

  const oldLender = loadLenderByMarketId(event.params.from, bid.marketplace);
  decrementLenderStats(oldLender, bid);

  const newLender = loadLenderByMarketId(
    event.params.to,
    bid.marketplace,
    event.block.timestamp
  );
  incrementLenderStats(newLender, bid);

  const lenderBid = new LenderBid(bid.id);
  lenderBid.lender = newLender.id;
  lenderBid.save();
}

export function handleNewLenderSets(events: Transfer[]): void {
  events.forEach(event => {
    handleNewLenderSet(event);
  });
}
