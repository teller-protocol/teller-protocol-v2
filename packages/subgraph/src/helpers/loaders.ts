import { ethereum, Address, BigInt, Bytes, Value } from "@graphprotocol/graph-ts";

import { IERC20Metadata } from "../../generated/Blocks/IERC20Metadata";
import { IERC721Upgradeable } from "../../generated/CollateralManager/IERC721Upgradeable";
import {
  Bid,
  Borrower,
  BidCollateral,
  CollateralPairTokenVolume,
  Commitment,
  Lender,
  LoanStatusCount,
  MarketPlace,
  Protocol,
  Token,
  TokenVolume,
  User
} from "../../generated/schema";
import { ERC165 } from "../../generated/TellerV2/ERC165";
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

    protocol._durationTotal = BigInt.zero();
    protocol.durationAverage = BigInt.zero();

    protocol.save();
  }
  return protocol;
}

export enum TokenType {
  NONE,
  ERC20,
  ERC721,
  ERC1155
}
export function getTokenTypeString(type: TokenType): string {
  switch (type) {
    case TokenType.ERC20:
      return "ERC20";
    case TokenType.ERC721:
      return "ERC721";
    case TokenType.ERC1155:
      return "ERC1155";
  }
  return "";
}
function supportsInterface(address: Address, interfaceId: string): boolean {
  const erc165Instance = ERC165.bind(address);
  const result = erc165Instance.try_supportsInterface(
    Bytes.fromHexString(interfaceId)
  );
  return !result.reverted && result.value;
}
export function loadToken(
  _address: Bytes,
  type: TokenType = TokenType.NONE,
  nftId: BigInt | null = null
): Token {
  const address = Address.fromBytes(_address);
  const id = `${address.toHex()}${nftId ? "-" + nftId.toString() : ""}`;
  let token = Token.load(id);
  if (!token) {
    token = new Token(id);
    token.address = address;

    if (type == TokenType.NONE) {
      if (supportsInterface(address, "0x06fdde03")) {
        // ERC20Metadata
        type = TokenType.ERC20;
      } else if (supportsInterface(address, "0x80ac58cd")) {
        // ERC721Metadata
        type = TokenType.ERC721;
      } else if (supportsInterface(address, "0x0e89341c")) {
        // ERC1155Metadata
        type = TokenType.ERC1155;
      }
    }

    token.type = getTokenTypeString(type);
    token.nftId = nftId;

    const tokenContract = IERC20Metadata.bind(address);
    const name = tokenContract.try_name();
    if (!name.reverted) {
      token.name = name.value;
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

    marketPlace._durationTotal = BigInt.zero();
    marketPlace.durationAverage = BigInt.zero();

    marketPlace.totalNumberOfLenders = BigInt.zero();

    marketPlace.paymentType = "EMI";
    marketPlace.paymentCycleType = "Seconds";

    marketPlace.save();
  }
  return marketPlace;
}

export function loadLenderByMarketId(
  lenderAddress: Bytes,
  marketId: string,
  timestamp: BigInt = BigInt.zero()
): Lender {
  const market = loadMarketById(marketId);
  const idString = `lender-${market.id}-${lenderAddress.toHexString()}`;
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

    lender._durationTotal = BigInt.zero();
    lender.durationAverage = BigInt.zero();

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
  borrowerAddress: Bytes,
  marketId: string,
  timestamp: BigInt = BigInt.zero()
): Borrower {
  const market = loadMarketById(marketId);
  const idString = `borrower-${market.id}-${borrowerAddress.toHexString()}`;
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

    borrower._durationTotal = BigInt.zero();
    borrower.durationAverage = BigInt.zero();

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
  tokenAddress: Bytes,
  keys: string[] = [],
  values: Value[] = []
): TokenVolume {
  prefixes.push(tokenAddress.toHexString());
  const id = prefixes.join("-");
  let tokenVolume = TokenVolume.load(id);

  if (!tokenVolume) {
    tokenVolume = new TokenVolume(id);
    // NOTE: We only track ERC20 token volume loaned on TellerV2
    initTokenVolume(tokenVolume, loadToken(tokenAddress, TokenType.ERC20));

    for (let i = 0; i < keys.length; i++) {
      tokenVolume.set(keys[i], values[i]);
    }
    tokenVolume.save();
  }

  return tokenVolume;
}

export function loadProtocolTokenVolume(tokenAddress: Bytes): TokenVolume {
  const protocol = loadProtocol();
  return loadTokenVolumeWithValues(
    ["protocol", protocol.id],
    tokenAddress,
    ["protocol"],
    [Value.fromString(protocol.id)]
  );
}

/**
 * @param {Bytes} lendingTokenAddress - The address of the token that is being lent
 * @param {string} marketId - MarketId
 * @returns {TokenVolume} The TokenVolume entity for the given market's corresponding asset
 */
export function loadMarketTokenVolume(
  lendingTokenAddress: Bytes,
  marketId: string
): TokenVolume {
  const tokenVolume = loadTokenVolumeWithValues(
    ["market", marketId],
    lendingTokenAddress,
    ["market"],
    [Value.fromString(marketId)]
  );

  return tokenVolume;
}

/**
 * @param {Bytes} lendingTokenAddress - Address of the token being lent
 * @param {Lender} lender - Lender entity
 * @returns {TokenVolume} The TokenVolume entity for the given market's corresponding asset
 */
export function loadLenderTokenVolume(
  lendingTokenAddress: Bytes,
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
 * @param {Bytes} lendingTokenAddress - Address of the token being lent
 * @param {Borrower} borrower - Borrower entity
 * @returns {TokenVolume} The TokenVolume entity for the given market's corresponding asset
 */
export function loadBorrowerTokenVolume(
  lendingTokenAddress: Bytes,
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
 * @param {Bytes} lendingTokenAddress - Address of the token being lent
 * @param {Commitment} commitment - Commitment entity
 * @returns {TokenVolume} The TokenVolume entity for the given commitment
 */
export function loadCommitmentTokenVolume(
  lendingTokenAddress: Bytes,
  commitment: Commitment
): TokenVolume {
  return loadTokenVolumeWithValues(
    ["commitment", commitment.id],
    lendingTokenAddress
  );
}

export function loadCollateralTokenVolume(
  tokenVolume: TokenVolume,
  collateralTokenAddress: Bytes
): TokenVolume {
  const collateralTokenVolume = loadTokenVolumeWithValues(
    ["collateral", collateralTokenAddress.toHex()],
    tokenVolume.lendingTokenAddress
  );

  const pairVolume = new CollateralPairTokenVolume(
    `${tokenVolume.id}--${collateralTokenVolume.id}`
  );
  pairVolume.lendingToken = loadToken(
    tokenVolume.lendingTokenAddress,
    TokenType.ERC20
  ).id;
  pairVolume.collateralToken = loadToken(collateralTokenAddress).id;
  pairVolume.tokenVolume = collateralTokenVolume.id;
  pairVolume._totalTokenVolume = tokenVolume.id;
  pairVolume.save();

  return collateralTokenVolume;
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
 * @param {TokenType} type - Type of token
 * @param {BigInt} [nftId] - ID of the NFT if the token is an NFT
 */
export function loadCollateral(
  bidId: string,
  collateralAddress: Address,
  type: TokenType,
  nftId: BigInt | null = null
): BidCollateral {
  const idString = bidId.concat(collateralAddress.toHexString());
  let collateral = BidCollateral.load(idString);
  if (!collateral) {
    collateral = new BidCollateral(idString);
    collateral.amount = BigInt.zero();
    collateral.tokenId = nftId;
    collateral.collateralAddress = Address.zero();
    collateral.type = getTokenTypeString(type);
    collateral.token = loadToken(collateralAddress, type, nftId).id;
    collateral.status = "";
    collateral.receiver = Address.zero();
    collateral.bid = bidId;
    collateral.save();
  }
  return collateral;
}
