import { Address, BigInt, Value } from "@graphprotocol/graph-ts";

import { IERC20Metadata } from "../../generated/Blocks/IERC20Metadata";
import { LenderCommitmentForwarder } from "../../generated/LenderCommitmentForwarder/LenderCommitmentForwarder";
import {
  Bid,
  Borrower,
  Collateral,
  Commitment,
  Lender,
  LoanStatusCount,
  MarketPlace,
  MarketVolume,
  Protocol,
  Token,
  TokenVolume,
  User
} from "../../generated/schema";
import { TellerV0Storage } from "../../generated/TellerV2/TellerV0Storage";
import {
  TellerV2,
  TellerV2__bidsResult,
  TellerV2__bidsResultLoanDetailsStruct,
  TellerV2__bidsResultTermsStruct
} from "../../generated/TellerV2/TellerV2";

import { initTokenVolume } from "./intializers";

export function loadProtocol(): Protocol {
  let protocol = Protocol.load("v2");
  if (!protocol) {
    protocol = new Protocol("v2");
    loadLoanStatusCount("protocol", protocol.id);
    protocol.save();
  }
  return protocol;
}

export function loadToken(address: Address): Token {
  let token = Token.load(address.toHexString());
  if (!token) {
    token = new Token(address.toHex());

    const tokenContract = IERC20Metadata.bind(address);
    const name = tokenContract.try_name();
    if (!name.reverted) {
      token.name = tokenContract.name();
    }
    const symbol = tokenContract.try_symbol();
    if (!symbol.reverted) {
      token.symbol = symbol.value;
    }
    const decimals = tokenContract.try_decimals();
    if (!decimals.reverted) {
      token.decimals = BigInt.fromI32(decimals.value);
    }

    token.save();
  }
  return token;
}

export function loadBidById(id: BigInt): Bid {
  const bid: Bid | null = Bid.load(id.toString());

  if (!bid) throw new Error("unable to load bid");

  return bid;
}

export function loadLoanStatusCount(
  entityType: string,
  entityId: string
): LoanStatusCount {
  const id = `${entityType}-${entityId}`;
  let loans = LoanStatusCount.load(id);

  if (!loans) {
    loans = new LoanStatusCount(id);

    loans.set(`_${entityType}`, Value.fromString(entityId));

    loans.all = [];
    loans.totalCount = BigInt.zero();

    loans.submitted = [];
    loans.submittedCount = BigInt.zero();

    loans.expired = [];
    loans.expiredCount = BigInt.zero();

    loans.cancelled = [];
    loans.cancelledCount = BigInt.zero();

    loans.accepted = [];
    loans.acceptedCount = BigInt.zero();

    loans.dueSoon = [];
    loans.dueSoonCount = BigInt.zero();

    loans.late = [];
    loans.lateCount = BigInt.zero();

    loans.defaulted = [];
    loans.defaultedCount = BigInt.zero();

    loans.repaid = [];
    loans.repaidCount = BigInt.zero();

    loans.liquidated = [];
    loans.liquidatedCount = BigInt.zero();

    loans.save();
  }

  return loans;
}

export function loadMarketById(id: string): MarketPlace {
  let marketPlace: MarketPlace | null = MarketPlace.load(id);

  if (!marketPlace) {
    marketPlace = new MarketPlace(id);
    marketPlace.marketplaceId = BigInt.fromString(id);
    marketPlace.isMarketOpen = false;

    marketPlace.marketplaceFeePercent = BigInt.zero();
    marketPlace.paymentDefaultDuration = BigInt.zero();
    marketPlace.paymentCycleDuration = BigInt.zero();
    marketPlace.bidExpirationTime = BigInt.zero();
    marketPlace.borrowerAttestationRequired = false;
    marketPlace.lenderAttestationRequired = false;

    loadLoanStatusCount("market", id);

    marketPlace.totalNumberOfLenders = BigInt.zero();

    marketPlace.paymentType = "EMI";
    marketPlace.paymentCycleType = "Seconds";

    marketPlace.save();
  }
  return marketPlace;
}

export function loadLenderByMarketId(
  lenderAddress: Address,
  marketId: string,
  timestamp: BigInt = BigInt.zero()
): Lender {
  const market = loadMarketById(marketId);
  const idString = `${market.id}-${lenderAddress.toHexString()}`;
  let lender: Lender | null = Lender.load(idString);

  let user: User | null = User.load(lenderAddress.toHexString());
  if (!user) {
    user = new User(lenderAddress.toHexString());
    user.firstInteractionDate = timestamp;
    user.save();
  }

  if (!lender) {
    lender = new Lender(idString);
    lender.isAttested = false;

    loadLoanStatusCount("lender", idString);

    lender.firstInteractionDate = timestamp;
    lender.lenderAddress = lenderAddress;
    lender.user = user.id;
    lender.marketplace = market.id;
    lender.marketplaceId = market.marketplaceId;

    lender.save();

    // increment total number of lenders for market
    market.totalNumberOfLenders = market.totalNumberOfLenders.plus(
      BigInt.fromI32(1)
    );
    market.save();
  }

  return lender;
}

export function loadBorrowerByMarketId(
  borrowerAddress: Address,
  marketId: string,
  timestamp: BigInt = BigInt.zero()
): Borrower {
  const market = loadMarketById(marketId);
  const idString = `${market.id}-${borrowerAddress.toHexString()}`;
  let borrower: Borrower | null = Borrower.load(idString);

  let user: User | null = User.load(borrowerAddress.toHexString());
  if (!user) {
    user = new User(borrowerAddress.toHexString());
    user.firstInteractionDate = timestamp;
    user.save();
  }

  if (!borrower) {
    borrower = new Borrower(idString);
    borrower.isAttested = false;

    loadLoanStatusCount("borrower", idString);

    borrower.firstInteractionDate = timestamp;
    borrower.borrowerAddress = borrowerAddress;
    borrower.user = user.id;
    borrower.marketplace = market.id;
    borrower.marketplaceId = market.marketplaceId;

    borrower.save();
  }

  return borrower;
}

/**
 * Loads a token volume entity from the store or creates a new one if it does not exist. Default values
 * can be set if the entity did not previously exist.
 * @param prefixes An array of prefixes to use to find the token volume.
 * @param tokenAddress The address of the token.
 * @param keys An array of keys to set on the token volume.
 * @param values An array of values to set on the token volume.
 */
function loadTokenVolumeWithValues(
  prefixes: string[],
  tokenAddress: Address,
  keys: string[] = [],
  values: Value[] = []
): TokenVolume {
  prefixes.push(tokenAddress.toHexString());
  const id = prefixes.join("-");
  let tokenVolume = TokenVolume.load(id);

  if (!tokenVolume) {
    tokenVolume = new TokenVolume(id);
    initTokenVolume(tokenVolume, loadToken(tokenAddress));

    for (let i = 0; i < keys.length; i++) {
      tokenVolume.set(keys[i], values[i]);
    }
    tokenVolume.save();
  }

  return tokenVolume;
}

export function loadProtocolTokenVolume(tokenAddress: Address): TokenVolume {
  const protocol = loadProtocol();
  return loadTokenVolumeWithValues(
    ["protocol", protocol.id],
    tokenAddress,
    ["protocol"],
    [Value.fromString(protocol.id)]
  );
}

/**
 * @param {Address} lendingTokenAddress - The address of the token that is being lent
 * @param {string} marketId - MarketId
 * @returns {TokenVolume} The TokenVolume entity for the given market's corresponding asset
 */
export function loadTokenVolumeByMarketId(
  lendingTokenAddress: Address,
  marketId: string
): TokenVolume {
  const tokenVolume = loadTokenVolumeWithValues(
    ["market", marketId],
    lendingTokenAddress,
    ["marketplace"],
    [Value.fromString(marketId)]
  );

  const marketVolumeId = `${marketId}-${tokenVolume.id}`;
  let marketVolume = MarketVolume.load(marketVolumeId);
  if (!marketVolume) {
    marketVolume = new MarketVolume(marketVolumeId);
    marketVolume.market = marketId;
    marketVolume.volume = tokenVolume.id;
    marketVolume.save();
  }

  return tokenVolume;
}

/**
 * @param {Address} lendingTokenAddress - Address of the token being lent
 * @param {Lender} lender - Lender entity
 * @returns {TokenVolume} The TokenVolume entity for the given market's corresponding asset
 */
export function loadLenderTokenVolume(
  lendingTokenAddress: Address,
  lender: Lender
): TokenVolume {
  return loadTokenVolumeWithValues(
    ["lender", lender.id, lender.marketplace],
    lendingTokenAddress,
    ["marketplace", "lender"],
    [Value.fromString(lender.marketplace), Value.fromString(lender.id)]
  );
}

/**
 * @param {Address} lendingTokenAddress - Address of the token being lent
 * @param {Borrower} borrower - Borrower entity
 * @returns {TokenVolume} The TokenVolume entity for the given market's corresponding asset
 */
export function loadBorrowerTokenVolume(
  lendingTokenAddress: Address,
  borrower: Borrower
): TokenVolume {
  return loadTokenVolumeWithValues(
    ["borrower", borrower.id, borrower.marketplace],
    lendingTokenAddress,
    ["marketplace", "borrower"],
    [Value.fromString(borrower.marketplace), Value.fromString(borrower.id)]
  );
}

/**
 * @param {string} commitmentId - ID of the commitment
 * @returns {Commitment} The Commitment entity for the lender
 */
export function loadCommitment(commitmentId: string): Commitment {
  const idString = commitmentId;
  let commitment = Commitment.load(idString);

  if (!commitment) {
    commitment = new Commitment(idString);

    commitment.committedAmount = BigInt.zero();
    commitment.expirationTimestamp = BigInt.zero();
    commitment.maxDuration = BigInt.zero();
    commitment.minAPY = BigInt.zero();
    commitment.lender = "";
    commitment.lenderAddress = Address.zero();
    commitment.marketplace = "";
    commitment.marketplaceId = BigInt.zero();
    commitment.stats = "";
    commitment.createdAt = BigInt.zero();

    commitment.principalTokenAddress = Address.zero();
    commitment.collateralTokenAddress = Address.zero();
    commitment.collateralTokenId = BigInt.zero();
    commitment.collateralTokenType = "";
    commitment.maxPrincipalPerCollateralAmount = BigInt.zero();
    commitment.commitmentBorrowers = [];

    commitment.save();
  }
  return commitment;
}

/**
 * @param {string} commitmentId - ID of the commitment
 * @param {Address} lenderAddress - Address of the lender
 * @param {string} marketId - Market id
 * @param {Address} lendingTokenAddress - Address of the token being lent
 * @param {BigInt} committedAmount - The maximum that can be loaned
 * @param {Address} eventAddress - Address of the emitted event
 */

export function updateLenderCommitment(
  commitmentId: string,
  lenderAddress: Address,
  marketId: string,
  lendingTokenAddress: Address,
  committedAmount: BigInt,
  eventAddress: Address
): Commitment {
  const commitment = loadCommitment(commitmentId);

  const lender = loadLenderByMarketId(lenderAddress, marketId);

  commitment.lender = lender.id;
  commitment.lenderAddress = lender.lenderAddress;
  commitment.marketplace = marketId;
  commitment.marketplaceId = BigInt.fromString(marketId);
  commitment.committedAmount = committedAmount;

  const lenderCommitmentForwarderInstance = LenderCommitmentForwarder.bind(
    eventAddress
  );
  const lenderCommitment = lenderCommitmentForwarderInstance.commitments(
    BigInt.fromString(commitmentId)
  );

  commitment.expirationTimestamp = lenderCommitment.value1;
  commitment.maxDuration = lenderCommitment.value2;
  commitment.minAPY = BigInt.fromI32(lenderCommitment.value3);
  commitment.collateralTokenAddress = lenderCommitment.value4;
  commitment.collateralTokenId = lenderCommitment.value5;
  commitment.maxPrincipalPerCollateralAmount = lenderCommitment.value6;
  commitment.collateralTokenType = lenderCommitment.value7.toString();
  commitment.principalTokenAddress = lenderCommitment.value10;
  commitment.save();
  return commitment;
}

export function getBid(
  eventAddress: Address,
  bidId: BigInt
): TellerV2__bidsResult {
  const tellerV2Instance = TellerV2.bind(eventAddress);
  const tellerV0Storage = TellerV0Storage.bind(eventAddress);

  let storedBid: TellerV2__bidsResult;
  if (tellerV2Instance.try_bids(bidId).reverted) {
    const storedV0Bid = tellerV0Storage.bids(bidId);
    storedBid = new TellerV2__bidsResult(
      storedV0Bid.value0,
      storedV0Bid.value1,
      storedV0Bid.value2,
      storedV0Bid.value3,
      storedV0Bid.value4,
      changetype<TellerV2__bidsResultLoanDetailsStruct>(storedV0Bid.value5),
      changetype<TellerV2__bidsResultTermsStruct>(storedV0Bid.value6),
      storedV0Bid.value7,
      0
    );
  } else {
    storedBid = tellerV2Instance.bids(bidId);
  }
  return storedBid;
}

/**
 * @param {string} bidId - ID of the bid linked to committed collateral
 * @param {Address} collateralAddress - Address of the collateral contract
 */
export function loadCollateral(
  bidId: string,
  collateralAddress: Address
): Collateral {
  const idString = bidId.concat(collateralAddress.toHexString());
  let collateral = Collateral.load(idString);
  if (!collateral) {
    collateral = new Collateral(idString);
    collateral.amount = BigInt.zero();
    collateral.tokenId = BigInt.zero();
    collateral.collateralAddress = Address.zero();
    collateral.type = "";
    collateral.status = "";
    collateral.receiver = Address.zero();
    collateral.bid = bidId;
    collateral.save();
  }
  return collateral;
}
