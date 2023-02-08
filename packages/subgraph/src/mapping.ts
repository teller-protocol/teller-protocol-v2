import { Address, BigInt } from "@graphprotocol/graph-ts";

import {
  CollateralEscrowDeployed,
  CollateralCommitted,
  CollateralDeposited,
  CollateralWithdrawn,
  CollateralClaimed
} from "../generated/CollateralManager/CollateralManager";
import {
  DeletedCommitment,
  ExercisedCommitment,
  LenderCommitmentForwarder,
  UpdatedCommitment
} from "../generated/LenderCommitmentForwarder/LenderCommitmentForwarder";
import {
  BorrowerAttestation,
  BorrowerExitMarket,
  LenderAttestation,
  LenderExitMarket,
  MarketClosed,
  MarketCreated,
  MarketRegistry,
  SetBidExpirationTime,
  SetMarketBorrowerAttestation,
  SetMarketFee,
  SetMarketFeeRecipient,
  SetMarketLenderAttestation,
  SetMarketOwner,
  SetMarketPaymentType,
  SetMarketURI,
  SetPaymentCycleDuration,
  SetPaymentDefaultDuration,
  Upgraded
} from "../generated/MarketRegistry/MarketRegistry";
import {
  Bid,
  Borrower,
  BorrowerBid,
  FundedTx,
  Lender,
  LenderBid,
  MarketPlace,
  TokenVolume
} from "../generated/schema";
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

import {
  createCommitmentByMarketId,
  getBid,
  loadBidById,
  loadBorrowerByMarketId,
  loadBorrowerTokenVolume,
  loadCollateral,
  loadCommitmentByMarketId,
  loadLenderByMarketId,
  loadLenderTokenVolume,
  loadMarketById,
  loadProtocolTokenVolume,
  loadTokenVolumeByMarketId
} from "./helpers/loaders";
import {
  updateBid,
  updateCollateral,
  updateTokenVolumeOnAccept
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
  const tellerV2Instance = TellerV2.bind(event.address);
  const storedBid = getBid(event.address, event.params.bidId);

  const marketPlace = loadMarketById(storedBid.value3.toString());

  const lender: Lender = loadLenderByMarketId(
    event.params.lender,
    marketPlace.id,
    event.block.timestamp
  );

  const bid = loadBidById(event.params.bidId.toString());
  const lenderBid = new LenderBid(lender.id.concat(bid.id));
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
  bid.acceptedTimestamp = storedBid.value5.acceptedTimestamp;
  bid.endDate = storedBid.value5.acceptedTimestamp.plus(
    storedBid.value5.loanDuration
  );
  bid.nextDueDate = tellerV2Instance.calculateNextDueDate(event.params.bidId);
  bid.lenderAddress = event.params.lender;

  // Update market entity
  const requests = marketPlace.openRequests;
  const marketFee = marketPlace.marketplaceFeePercent;
  const activeLoanCount = marketPlace.activeLoans;

  const _aprTotal = marketPlace._aprTotal;
  const _durationTotal = marketPlace._durationTotal;

  if (requests && marketFee && activeLoanCount && _durationTotal) {
    const updatedAPRTotal = _aprTotal.plus(
      BigInt.fromI32(storedBid.value6.APR)
    );
    const updatedActiveLoans = activeLoanCount.plus(BigInt.fromI32(1));
    marketPlace.openRequests = requests.minus(BigInt.fromI32(1));
    marketPlace.activeLoans = updatedActiveLoans;

    marketPlace._aprTotal = updatedAPRTotal;
    const totalLoans = updatedActiveLoans.plus(marketPlace.closedLoans);
    marketPlace.aprAverage = updatedAPRTotal.div(totalLoans);

    const updatedDurationTotal = _durationTotal.plus(
      storedBid.value5.loanDuration
    );
    marketPlace._durationTotal = updatedDurationTotal;
    marketPlace.durationAverage = updatedDurationTotal.div(totalLoans);
  }

  const loanCount = lender.activeLoans;
  const totalLoaned = lender.totalLoaned;
  // If this is the lenders first loan, increment the totalNumberOfLenders on the associated Market
  if (totalLoaned.isZero()) {
    const numLenders = marketPlace.totalNumberOfLenders;
    marketPlace.totalNumberOfLenders = numLenders.plus(BigInt.fromI32(1));
    marketPlace.save();
  }
  if (totalLoaned && loanCount) {
    lender.activeLoans = loanCount.plus(BigInt.fromI32(1));
    lender.totalLoaned = totalLoaned.plus(storedBid.value5.principal);
  }
  const lenderAcceptedBids = lender.bidsAccepted;
  if (lenderAcceptedBids) {
    lender.bidsAccepted = lenderAcceptedBids.plus(BigInt.fromI32(1));
  }

  // Update borrower entity
  const borrower: Borrower = loadBorrowerByMarketId(
    storedBid.value0,
    marketPlace.id,
    event.block.timestamp
  );
  const borrowerAcceptedBids = borrower.bidsAccepted;
  const borrowerActiveLoans = borrower.activeLoans;
  if (borrowerAcceptedBids && borrowerAcceptedBids) {
    borrower.activeLoans = borrowerActiveLoans.plus(BigInt.fromI32(1));
    borrower.bidsAccepted = borrowerAcceptedBids.plus(BigInt.fromI32(1));
  }

  // Load TokenVolume entity for the bid's associated lendingToken in the market
  const lendingTokenAddress = storedBid.value5.lendingToken;

  // Update the market's token volume
  const tokenVolume = loadTokenVolumeByMarketId(
    lendingTokenAddress,
    marketPlace.id
  );
  updateTokenVolumeOnAccept(tokenVolume, storedBid);

  // Update the protocol's overall token volume
  const protocolVolume = loadProtocolTokenVolume(storedBid.value5.lendingToken);
  updateTokenVolumeOnAccept(protocolVolume, storedBid);

  // Update the lender's token volume
  const lenderVolume = loadLenderTokenVolume(lendingTokenAddress, lender);
  updateTokenVolumeOnAccept(lenderVolume, storedBid);

  // Update the borrower's token volume
  const borrowerVolume = loadBorrowerTokenVolume(lendingTokenAddress, borrower);
  updateTokenVolumeOnAccept(borrowerVolume, storedBid);

  bid.save();
  marketPlace.save();
  lender.save();
  borrower.save();
}

export function handleAcceptedBids(events: AcceptedBid[]): void {
  events.forEach(event => {
    handleAcceptedBid(event);
  });
}

export function handleCancelledBid(event: CancelledBid): void {
  const bid: Bid = loadBidById(event.params.bidId.toString());

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
  const bid: Bid = loadBidById(event.params.bidId.toString());
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
  const bid: Bid = loadBidById(event.params.bidId.toString());

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
  const bid: Bid = loadBidById(event.params.bidId.toString());

  bid.updatedAt = event.block.timestamp;
  bid.transactionHash = event.transaction.hash.toHex();

  updateBid(bid, event, "Liquidated");
}

export function handleLoanLiquidateds(events: LoanLiquidated[]): void {
  events.forEach(event => {
    handleLoanLiquidated(event);
  });
}

export function handleMarketCreated(event: MarketCreated): void {
  const marketPlace: MarketPlace = loadMarketById(
    event.params.marketId.toString()
  );
  marketPlace.owner = event.params.owner;
  // market owner is the default fee recipient
  marketPlace.feeRecipient = event.params.owner;

  const marketPlaceInstance = MarketRegistry.bind(event.address);
  if (
    !marketPlaceInstance.try_isVerifiedBorrower(
      event.params.marketId,
      Address.zero()
    ).reverted
  ) {
    marketPlace.borrowerAttestationRequired = !marketPlaceInstance.isVerifiedBorrower(
      event.params.marketId,
      Address.zero()
    ).value0;
  }
  if (
    !marketPlaceInstance.try_isVerifiedLender(
      event.params.marketId,
      Address.zero()
    ).reverted
  ) {
    marketPlace.lenderAttestationRequired = !marketPlaceInstance.isVerifiedLender(
      event.params.marketId,
      Address.zero()
    ).value0;
  }
  marketPlace.isMarketOpen = true;
  marketPlace.save();
}

export function handleMarketsCreated(events: MarketCreated[]): void {
  events.forEach(event => {
    handleMarketCreated(event);
  });
}

export function handleMarketClosed(event: MarketClosed): void {
  const marketPlace: MarketPlace = loadMarketById(
    event.params.marketId.toString()
  );
  marketPlace.isMarketOpen = false;
  marketPlace.save();
}

export function handleMarketsClosed(events: MarketClosed[]): void {
  events.forEach(event => {
    handleMarketClosed(event);
  });
}

export function handleSetMarketOwner(event: SetMarketOwner): void {
  const marketPlace: MarketPlace = loadMarketById(
    event.params.marketId.toString()
  );
  marketPlace.owner = event.params.newOwner;

  marketPlace.save();
}

export function handleSetMarketFeeRecipient(
  event: SetMarketFeeRecipient
): void {
  const marketPlace: MarketPlace = loadMarketById(
    event.params.marketId.toString()
  );
  marketPlace.feeRecipient = event.params.newRecipient;

  marketPlace.save();
}

export function handleSetMarketURI(event: SetMarketURI): void {
  const marketPlace = loadMarketById(event.params.marketId.toString());
  marketPlace.metadataURI = event.params.uri;

  marketPlace.save();
}

export function handleSetMarketURIs(events: SetMarketURI[]): void {
  events.forEach(event => {
    handleSetMarketURI(event);
  });
}

export function handleSetPaymentCycleDuration(
  event: SetPaymentCycleDuration
): void {
  const marketPlace: MarketPlace = loadMarketById(
    event.params.marketId.toString()
  );
  marketPlace.paymentCycleDuration = event.params.duration;

  marketPlace.save();
}

export function handleSetPaymentCycleDurations(
  events: SetPaymentCycleDuration[]
): void {
  events.forEach(event => {
    handleSetPaymentCycleDuration(event);
  });
}

export function handleSetPaymentDefaultDuration(
  event: SetPaymentDefaultDuration
): void {
  const marketPlace: MarketPlace = loadMarketById(
    event.params.marketId.toString()
  );
  marketPlace.paymentDefaultDuration = event.params.duration;

  marketPlace.save();
}

export function handleSetPaymentDefaultDurations(
  events: SetPaymentDefaultDuration[]
): void {
  events.forEach(event => {
    handleSetPaymentDefaultDuration(event);
  });
}

export function handleSetBidExpirationTime(event: SetBidExpirationTime): void {
  const marketPlace: MarketPlace = loadMarketById(
    event.params.marketId.toString()
  );
  marketPlace.bidExpirationTime = event.params.duration;

  marketPlace.save();
}

export function handleSetBidExpirationTimes(
  events: SetBidExpirationTime[]
): void {
  events.forEach(event => {
    handleSetBidExpirationTime(event);
  });
}

export function handleSetMarketFee(event: SetMarketFee): void {
  const marketPlace: MarketPlace = loadMarketById(
    event.params.marketId.toString()
  );

  marketPlace.marketplaceFeePercent = BigInt.fromI32(event.params.feePct);

  marketPlace.save();
}

export function handleSetMarketFees(events: SetMarketFee[]): void {
  events.forEach(event => {
    handleSetMarketFee(event);
  });
}

export function handleSetLenderAttestationRequired(
  event: SetMarketLenderAttestation
): void {
  const marketPlace: MarketPlace = loadMarketById(
    event.params.marketId.toString()
  );
  marketPlace.lenderAttestationRequired = event.params.required;

  marketPlace.save();
}

export function handleSetBorrowerAttestationRequired(
  event: SetMarketBorrowerAttestation
): void {
  const marketPlace: MarketPlace = loadMarketById(
    event.params.marketId.toString()
  );
  marketPlace.borrowerAttestationRequired = event.params.required;

  marketPlace.save();
}

export function handleFeePaid(event: FeePaid): void {
  const bid: Bid = loadBidById(event.params.bidId.toString());
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

export function handleLenderAttestation(event: LenderAttestation): void {
  const market = loadMarketById(event.params.marketId.toString());
  const lender: Lender = loadLenderByMarketId(
    event.params.lender,
    market.id,
    event.block.timestamp
  );
  lender.attestedTimestamp = event.block.timestamp;
  lender.isAttested = true;

  lender.save();
}

export function handleLenderAttestations(events: LenderAttestation[]): void {
  events.forEach(event => {
    handleLenderAttestation(event);
  });
}

export function handleBorrowerAttestation(event: BorrowerAttestation): void {
  const borrower: Borrower = loadBorrowerByMarketId(
    event.params.borrower,
    event.params.marketId.toString(),
    event.block.timestamp
  );
  borrower.attestedTimestamp = event.block.timestamp;
  borrower.isAttested = true;

  borrower.save();
}

export function handleBorrowerAttestations(
  events: BorrowerAttestation[]
): void {
  events.forEach(event => {
    handleBorrowerAttestation(event);
  });
}

export function handleLenderExitMarket(event: LenderExitMarket): void {
  const market = loadMarketById(event.params.marketId.toString());
  const lender = loadLenderByMarketId(
    event.params.lender,
    market.id,
    event.block.timestamp
  );

  lender.isAttested = false;
  lender.save();
}

export function handleLenderExitMarkets(events: LenderExitMarket[]): void {
  events.forEach(event => {
    handleLenderExitMarket(event);
  });
}

export function handleBorrowerExitMarket(event: BorrowerExitMarket): void {
  const borrower = loadBorrowerByMarketId(
    event.params.borrower,
    event.params.marketId.toString(),
    event.block.timestamp
  );

  borrower.isAttested = false;
  borrower.save();
}

export function handleBorrowerExitMarkets(events: BorrowerExitMarket[]): void {
  events.forEach(event => {
    handleBorrowerExitMarket(event);
  });
}

export function handleMarketRegistryUpgraded(event: Upgraded): void {
  const marketPlaceInstance = MarketRegistry.bind(event.address);
  if (
    event.params.implementation.equals(
      Address.fromString("0xb43707f26D6356ae753E9C92d3C94D23c70c4057")
    ) // Polygon
  ) {
    const marketCount = marketPlaceInstance.marketCount();
    for (let i = 1; i <= marketCount.toI32(); i++) {
      if (
        !marketPlaceInstance.try_getMarketAttestationRequirements(
          BigInt.fromI32(i)
        ).reverted
      ) {
        const attestationsRequired = marketPlaceInstance.getMarketAttestationRequirements(
          BigInt.fromI32(i)
        );
        const market = loadMarketById(i.toString());
        if (market) {
          market.lenderAttestationRequired = attestationsRequired.value0;
          market.borrowerAttestationRequired = attestationsRequired.value1;
          market.save();
        }
      }
    }
  }

  if (
    event.params.implementation.equals(
      Address.fromString("0xb8bFfcC58d97581b85d67C80556A4e2e05d36bEc")
    ) || // Polygon
    event.params.implementation.equals(
      Address.fromString("0x54B1b79531c80DA391638D040B58ABDB193326F3")
    ) || // Mainnet
    event.params.implementation.equals(
      Address.fromString("0xC149E7081F08EA3310FC4AAca8c31fD972f7B06c")
    ) // Goerli
  ) {
    const marketCount = marketPlaceInstance.marketCount();
    for (let i = 1; i <= marketCount.toI32(); i++) {
      const marketId = BigInt.fromI32(i);
      const market = loadMarketById(marketId.toString());
      if (market) {
        const requirements = marketPlaceInstance.getMarketAttestationRequirements(
          marketId
        );
        market.lenderAttestationRequired = requirements.value0;
        market.borrowerAttestationRequired = requirements.value1;
        market.save();
      }
    }
  }
}

export function handleTellerV2Upgraded(event: Upgraded): void {
  if (
    event.params.implementation.equals(
      Address.fromString("0xf39674f4d3878a732cb4c70b377c013affb89c1f")
    )
  ) {
    for (let i = 62; i < 66; i++) {
      const storedBid = getBid(event.address, BigInt.fromI32(i));
      const bid = loadBidById(i.toString());
      if (bid.bidId) {
        bid.paymentCycleAmount = storedBid.value6.paymentCycleAmount;
        bid.save();
      }
    }
  }
}

export function handleUpdatedCommitment(event: UpdatedCommitment): void {
  const commitment = createCommitmentByMarketId(
    event.params.lender,
    event.params.marketId.toString(),
    event.params.lendingToken,
    event.block.timestamp
  );
  commitment.committedAmount = event.params.tokenAmount;
  const lenderCommitmentForwarderInstance = LenderCommitmentForwarder.bind(
    event.address
  );
  const lenderCommitment = lenderCommitmentForwarderInstance.lenderMarketCommitments(
    event.params.lender,
    event.params.marketId,
    event.params.lendingToken
  );
  commitment.expirationTimestamp = lenderCommitment.value1;
  commitment.maxDuration = lenderCommitment.value2;
  commitment.minAPY = BigInt.fromI32(lenderCommitment.value3);
  commitment.save();
}

export function handleUpdatedCommitments(events: UpdatedCommitment[]): void {
  events.forEach(event => {
    handleUpdatedCommitment(event);
  });
}

export function handleDeletedCommitment(event: DeletedCommitment): void {
  const commitment = loadCommitmentByMarketId(
    event.params.lender,
    event.params.marketId.toString(),
    event.params.lendingToken
  );
  if (!commitment) return;
  commitment.committedAmount = BigInt.zero();
  commitment.expirationTimestamp = BigInt.zero();
  commitment.maxDuration = BigInt.zero();
  commitment.minAPY = BigInt.zero();
  commitment.save();
}

export function handleDeletedCommitments(events: DeletedCommitment[]): void {
  events.forEach(event => {
    handleDeletedCommitment(event);
  });
}

export function handleExercisedCommitment(event: ExercisedCommitment): void {
  const commitment = loadCommitmentByMarketId(
    event.params.lender,
    event.params.marketId.toString(),
    event.params.lendingToken
  );
  if (!commitment) return;
  const committedAmount = commitment.committedAmount;
  // Updated stored committed amount
  if (committedAmount) {
    commitment.committedAmount = committedAmount.minus(
      event.params.tokenAmount
    );
  }
  // Link commitment to bid
  const bid: Bid = loadBidById(event.params.bidId.toString());
  bid.commitment = commitment.id;
  bid.commitmentId = commitment.id;

  bid.save();
  commitment.save();

  const stats = TokenVolume.load(commitment.stats);
  if (stats) {
    stats.activeLoans = stats.activeLoans.plus(BigInt.fromI32(1));

    stats.totalLoaned = stats.totalLoaned.plus(bid.principal);
    stats.outstandingCapital = stats.outstandingCapital.plus(bid.principal);

    const totalLoans = stats.activeLoans.plus(stats.closedLoans);
    stats._aprTotal = stats._aprTotal.plus(bid.apr);
    stats.aprAverage = stats._aprTotal.div(totalLoans);
    stats.loanAverage = stats.totalLoaned.div(totalLoans);
    stats.durationAverage = stats._durationTotal.div(totalLoans);
    stats.save();
  }
}

export function handleExercisedCommitments(
  events: ExercisedCommitment[]
): void {
  events.forEach(event => {
    handleExercisedCommitment(event);
  });
}

export function handleSetMarketPaymentType(event: SetMarketPaymentType): void {
  const marketPlace: MarketPlace = loadMarketById(
    event.params.marketId.toString()
  );
  if (event.params.paymentType == i32(0)) {
    marketPlace.paymentType = "EMI";
  } else if (event.params.paymentType == i32(1)) {
    marketPlace.paymentType = "Bullet";
  }

  marketPlace.save();
}

export function handleSetMarketPaymentTypes(
  events: SetMarketPaymentType[]
): void {
  events.forEach(event => {
    handleSetMarketPaymentType(event);
  });
}

export function handleCollateralEscrowDeployed(
  event: CollateralEscrowDeployed
): void {
  const bid: Bid = loadBidById(event.params._bidId.toString());
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
  const bid = loadBidById(event.params._bidId.toString());
  bid.status = "Liquidated";
  bid.save();
}

export function handleCollateralClaimeds(events: CollateralClaimed[]): void {
  events.forEach(event => {
    handleCollateralClaimed(event);
  });
}
