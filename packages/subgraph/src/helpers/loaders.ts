import { Address, BigInt, Value } from "@graphprotocol/graph-ts";

import {
  Bid,
  Borrower,
  Collateral,
  Commitment,
  Lender,
  MarketPlace,
  MarketVolume,
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

export function loadBidById(id: string): Bid {
  const bid: Bid | null = Bid.load(id);

  if (!bid) throw new Error("unable to load bid");

  return bid;
}

export function loadMarketById(id: string): MarketPlace {
  let marketPlace: MarketPlace | null = MarketPlace.load(id);

  if (!marketPlace) {
    marketPlace = new MarketPlace(id);
    marketPlace.marketplaceId = BigInt.fromString(id);
    marketPlace.marketplaceFeePercent = BigInt.zero();
    marketPlace.openRequests = BigInt.zero();
    marketPlace.paymentDefaultDuration = BigInt.zero();
    marketPlace.paymentCycleDuration = BigInt.zero();
    marketPlace.bidExpirationTime = BigInt.zero();
    marketPlace.borrowerAttestationRequired = false;
    marketPlace.lenderAttestationRequired = false;
    marketPlace.activeLoans = BigInt.zero();
    marketPlace.closedLoans = BigInt.zero();
    marketPlace.aprAverage = BigInt.zero();
    marketPlace._aprTotal = BigInt.zero();
    marketPlace.durationAverage = BigInt.zero();
    marketPlace._durationTotal = BigInt.zero();
    marketPlace.totalNumberOfLenders = BigInt.zero();
    marketPlace.paymentType = "EMI";
  }
  marketPlace.save();
  return marketPlace;
}

export function loadLenderByMarketId(
  lenderAddress: Address,
  marketId: string,
  timestamp: BigInt = BigInt.zero()
): Lender {
  const market = loadMarketById(marketId);
  const idString = market.id.concat(lenderAddress.toHexString());
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
    lender.activeLoans = BigInt.zero();
    lender.closedLoans = BigInt.zero();
    lender.totalLoaned = BigInt.zero();
    lender.bidsAccepted = BigInt.zero();
    lender.firstInteractionDate = timestamp;
    lender.lenderAddress = lenderAddress;
    lender.user = user.id;
    lender.marketplace = market.id;
    lender.marketplaceId = market.marketplaceId;
  }

  lender.save();
  return lender;
}

export function loadBorrowerByMarketId(
  borrowerAddress: Address,
  marketId: string,
  timestamp: BigInt = BigInt.zero()
): Borrower {
  const market = loadMarketById(marketId);
  const idString = market.id.concat(borrowerAddress.toHexString());
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
    borrower.activeLoans = BigInt.zero();
    borrower.closedLoans = BigInt.zero();
    borrower.bidsAccepted = BigInt.zero();
    borrower.firstInteractionDate = timestamp;
    borrower.borrowerAddress = borrowerAddress;
    borrower.user = user.id;
    borrower.marketplace = market.id;
    borrower.marketplaceId = market.marketplaceId;
  }

  borrower.save();
  return borrower;
}

/**
 * Loads a token volume entity from the store or creates a new one if it does not exist.
 * @param prefixes An array of prefixes to use to find the token volume.
 * @param tokenAddress The address of the token.
 */
function loadTokenVolume(
  prefixes: string[],
  tokenAddress: Address
): TokenVolume {
  return loadTokenVolumeWithValues(prefixes, tokenAddress);
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
  let token = TokenVolume.load(id);

  if (!token) {
    token = new TokenVolume(id);
    initTokenVolume(token, tokenAddress);

    for (let i = 0; i < keys.length; i++) {
      token.set(keys[i], values[i]);
    }
    token.save();
  }

  return token;
}

export function loadProtocolTokenVolume(tokenAddress: Address): TokenVolume {
  return loadTokenVolume(["protocol"], tokenAddress);
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
 * @param {Address} lenderAddress - Address of the lender
 * @param {string} marketId - Market id
 * @param {Address} lendingTokenAddress - Address of the token being lent
 * @returns {Commitment} The Commitment entity for the lender
 */
export function loadCommitmentByMarketId(
  lenderAddress: Address,
  marketId: string,
  lendingTokenAddress: Address
): Commitment {
  const idString = marketId
    .concat(lendingTokenAddress.toHexString())
    .concat(lenderAddress.toHexString());
  let commitment = Commitment.load(idString);

  if (!commitment) {
    commitment = new Commitment(idString);

    const stats = new TokenVolume(`commitment-stats-${commitment.id}`);
    initTokenVolume(stats, lendingTokenAddress);
    stats.save();

    const lender = loadLenderByMarketId(lenderAddress, marketId);

    commitment.committedAmount = BigInt.zero();
    commitment.expirationTimestamp = BigInt.zero();
    commitment.maxDuration = BigInt.zero();
    commitment.minAPY = BigInt.zero();
    commitment.lender = lender.id;
    commitment.lenderAddress = lender.lenderAddress;
    commitment.marketplace = marketId;
    commitment.marketplaceId = BigInt.fromString(marketId);
    commitment.stats = stats.id;
    commitment.save();
  }
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
