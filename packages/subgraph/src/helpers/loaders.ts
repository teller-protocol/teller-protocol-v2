import { Address, BigInt, Bytes, Value } from "@graphprotocol/graph-ts";

import {
  Bid,
  Borrower,
  BidCollateral,
  Commitment,
  Lender,
  LoanStatusCount,
  MarketPlace,
  Protocol,
  ProtocolCollateral,
  Token,
  TokenVolume,
  User
} from "../../generated/schema";
import { ERC165 } from "../../generated/TellerV2/ERC165";
import { IERC20Metadata } from "../../generated/TellerV2/IERC20Metadata";
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

    protocol.activeCommitments = [];
    protocol.activeRewards = [];

    protocol._durationTotal = BigInt.zero();
    protocol.durationAverage = BigInt.zero();

    protocol.save();
  }
  return protocol;
}

export enum TokenType {
  UNKNOWN,
  ERC20,
  ERC721,
  ERC1155
}

export function getTokenTypeString(type: TokenType): string | null {
  switch (type) {
    case TokenType.UNKNOWN:
      return "UNKNOWN";
    case TokenType.ERC20:
      return "ERC20";
    case TokenType.ERC721:
      return "ERC721";
    case TokenType.ERC1155:
      return "ERC1155";
    default:
      return null;
  }
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
  type: TokenType = TokenType.UNKNOWN,
  nftId: BigInt | null = null
): Token {
  const address = Address.fromBytes(_address);
  let token: Token | null = null;

  if (type == TokenType.UNKNOWN) {
    // check if token is already loaded by the address
    token = Token.load(address.toHex());

    if (!token) {
      if (nftId) {
        if (supportsInterface(address, "0x80ac58cd")) {
          // ERC721Metadata
          type = TokenType.ERC721;
        } else if (supportsInterface(address, "0x0e89341c")) {
          // ERC1155Metadata
          type = TokenType.ERC1155;
        }
      } else {
        if (supportsInterface(address, "0x06fdde03")) {
          // ERC20Metadata
          type = TokenType.ERC20;
        }
      }
    }
  }

  if (type == TokenType.ERC20 && nftId) nftId = null;

  const id = `${address.toHex()}${nftId ? "-" + nftId.toString() : ""}`;
  token = Token.load(id);

  if (!token) {
    token = new Token(id);
    token.address = address;

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
      type = TokenType.ERC20;
    }

    token.type = getTokenTypeString(type);
    token.nftId = nftId;

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
 * @param tokenId The entity ID of the token.
 * @param keys An array of keys to set on the token volume.
 * @param values An array of values to set on the token volume.
 */
function loadTokenVolumeWithValues(
  prefixes: string[],
  tokenId: string,
  keys: string[] = [],
  values: Array<Value | null> = []
): TokenVolume {
  prefixes.push(tokenId);
  const id = prefixes.join("-");
  let tokenVolume = TokenVolume.load(id);

  if (!tokenVolume) {
    tokenVolume = new TokenVolume(id);
    initTokenVolume(tokenVolume, Token.load(tokenId)!);

    for (let i = 0; i < keys.length; i++) {
      const val = values[i];
      if (val) {
        tokenVolume.set(keys[i], val);
      }
    }
    tokenVolume.save();
  }

  return tokenVolume;
}

export function loadProtocolTokenVolume(tokenId: string): TokenVolume {
  const protocol = loadProtocol();
  return loadTokenVolumeWithValues(
    ["protocol", protocol.id],
    tokenId,
    ["protocol"],
    [Value.fromString(protocol.id)]
  );
}

/**
 * @param {string} lendingTokenId - Token entity ID that is being lent
 * @param {string} marketId - MarketId
 * @returns {TokenVolume} The TokenVolume entity for the given market's corresponding asset
 */
export function loadMarketTokenVolume(
  lendingTokenId: string,
  marketId: string
): TokenVolume {
  const tokenVolume = loadTokenVolumeWithValues(
    ["market", marketId],
    lendingTokenId,
    ["market"],
    [Value.fromString(marketId)]
  );

  return tokenVolume;
}

/**
 * @param {string} lendingTokenId - Token entity ID being lent
 * @param {Lender} lender - Lender entity
 * @returns {TokenVolume} The TokenVolume entity for the given market's corresponding asset
 */
export function loadLenderTokenVolume(
  lendingTokenId: string,
  lender: Lender
): TokenVolume {
  return loadTokenVolumeWithValues(
    ["lender", lender.id, lender.marketplace],
    lendingTokenId,
    ["marketplace", "lender"],
    [Value.fromString(lender.marketplace), Value.fromString(lender.id)]
  );
}

/**
 * @param {string} lendingTokenId - Token entity ID being lent
 * @param {Borrower} borrower - Borrower entity
 * @returns {TokenVolume} The TokenVolume entity for the given market's corresponding asset
 */
export function loadBorrowerTokenVolume(
  lendingTokenId: string,
  borrower: Borrower
): TokenVolume {
  return loadTokenVolumeWithValues(
    ["borrower", borrower.id, borrower.marketplace],
    lendingTokenId,
    ["marketplace", "borrower"],
    [Value.fromString(borrower.marketplace), Value.fromString(borrower.id)]
  );
}

/**
 * @param {string} lendingTokenId - Token entity ID being lent
 * @param {Commitment} commitment - Commitment entity
 * @returns {TokenVolume} The TokenVolume entity for the given commitment
 */
export function loadCommitmentTokenVolume(
  lendingTokenId: string,
  commitment: Commitment
): TokenVolume {
  return loadTokenVolumeWithValues(
    ["commitment", commitment.id],
    lendingTokenId
  );
}

export function loadCollateralTokenVolume(
  tokenVolume: TokenVolume,
  collateralToken: Token | null
): TokenVolume {
  let collateralTokenId: string | null = null;
  if (collateralToken) {
    if (collateralToken.nftId === null) {
      collateralTokenId = collateralToken.id;
    } else {
      // If the collateral token is an NFT, we want to make sure a token entity
      // for the NFT's address so that we can track the volume of all NFTs of
      // the same collection.

      const nftToken = Token.load(collateralToken.id)!;
      nftToken.id = collateralToken.address.toHex();
      nftToken.nftId = null;
      nftToken.save();

      collateralTokenId = nftToken.id;
    }
  }

  let protocolCollateralId: string | null = null;
  if (tokenVolume.protocol) {
    protocolCollateralId = collateralTokenId
      ? collateralTokenId
      : "no-collateral";
    const protocolCollateral = new ProtocolCollateral(protocolCollateralId);
    protocolCollateral.collateralToken = collateralTokenId;
    protocolCollateral.save();
  }

  const collateralTokenVolume = loadTokenVolumeWithValues(
    [
      "collateral",
      tokenVolume.id,
      collateralTokenId ? collateralTokenId : "null"
    ],
    tokenVolume.token,
    ["_linkedParentTokenVolume", "_protocolCollateral", "collateralToken"],
    [
      Value.fromString(tokenVolume.id),
      protocolCollateralId ? Value.fromString(protocolCollateralId) : null,
      collateralTokenId ? Value.fromString(collateralTokenId) : null
    ]
  );

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
  nftId: BigInt
): BidCollateral {
  const token = loadToken(collateralAddress, type, nftId);
  const idString = ["bid", bidId, token.id].join("-");
  let collateral = BidCollateral.load(idString);
  if (!collateral) {
    collateral = new BidCollateral(idString);
    collateral.amount = BigInt.zero();
    collateral.tokenId = nftId;
    collateral.collateralAddress = collateralAddress;
    collateral.type = getTokenTypeString(type);
    collateral.token = token.id;
    collateral.status = "";
    collateral.receiver = Address.zero();
    collateral.bid = bidId;
    collateral.save();

    const bid = Bid.load(bidId)!;
    let bidCollaterals = bid.collateral;
    if (!bidCollaterals) {
      bidCollaterals = [collateral.id];
    } else {
      bidCollaterals.push(collateral.id);
    }
    bid.collateral = bidCollaterals;
    bid.save();
  }
  return collateral;
}
