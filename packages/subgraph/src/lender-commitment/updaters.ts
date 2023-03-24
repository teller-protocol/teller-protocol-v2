import { Address, BigInt } from "@graphprotocol/graph-ts";

import { LenderCommitmentForwarder } from "../../generated/LenderCommitmentForwarder/LenderCommitmentForwarder";
import { Commitment, Token, TokenVolume } from "../../generated/schema";
import {
  loadCommitmentTokenVolume,
  loadLenderByMarketId,
  loadLenderTokenVolume,
  loadProtocolTokenVolume,
  loadMarketTokenVolume,
  loadToken,
  TokenType,
  loadCollateralTokenVolume
} from "../helpers/loaders";

import { loadCommitment } from "./loaders";

enum CollateralTokenType {
  NONE,
  ERC20,
  ERC721,
  ERC1155,
  ERC721_ANY_ID,
  ERC1155_ANY_ID
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

  const lenderCommitmentForwarderInstance = LenderCommitmentForwarder.bind(
    eventAddress
  );
  const lenderCommitment = lenderCommitmentForwarderInstance.commitments(
    BigInt.fromString(commitmentId)
  );

  commitment.expirationTimestamp = lenderCommitment.value1;
  commitment.maxDuration = lenderCommitment.value2;
  commitment.minAPY = BigInt.fromI32(lenderCommitment.value3);

  commitment.principalToken = loadToken(
    lendingTokenAddress,
    TokenType.ERC20
  ).id;
  commitment.principalTokenAddress = lendingTokenAddress;

  let tokenType = TokenType.NONE;
  switch (lenderCommitment.value7) {
    case CollateralTokenType.ERC20:
      tokenType = TokenType.ERC20;
    case CollateralTokenType.ERC721:
    case CollateralTokenType.ERC721_ANY_ID:
      tokenType = TokenType.ERC721;
    case CollateralTokenType.ERC1155:
    case CollateralTokenType.ERC1155_ANY_ID:
      tokenType = TokenType.ERC1155;
  }
  if (tokenType != TokenType.NONE) {
    const collateralToken = loadToken(
      lenderCommitment.value4,
      tokenType,
      lenderCommitment.value5
    );
    commitment.collateralToken = collateralToken.id;
    commitment.maxPrincipalPerCollateralAmount = lenderCommitment.value6;
  }

  const volume = loadCommitmentTokenVolume(lendingTokenAddress, commitment);
  commitment.tokenVolume = volume.id;

  commitment.save();

  updateAvailableTokensFromCommitment(commitment, committedAmount);

  return commitment;
}

export function updateAvailableTokensFromCommitment(
  commitment: Commitment,
  committedAmount: BigInt
): void {
  const committedAmountDiff = committedAmount.minus(commitment.committedAmount);
  commitment.committedAmount = committedAmount;
  commitment.save();

  const tokenVolumes = getTokenVolumesFromCommitment(commitment);
  for (let i = 0; i < tokenVolumes.length; i++) {
    const tokenVolume = tokenVolumes[i];
    tokenVolume.totalAvailable = tokenVolume.totalAvailable.plus(
      committedAmountDiff
    );
    tokenVolume.save();
  }
}

function getTokenVolumesFromCommitment(commitment: Commitment): TokenVolume[] {
  const tokenVolumes = new Array<TokenVolume>();

  const protocolVolume = loadProtocolTokenVolume(
    commitment.principalTokenAddress
  );
  tokenVolumes.push(protocolVolume);

  const commitmentVolume = loadCommitmentTokenVolume(
    commitment.principalTokenAddress,
    commitment
  );
  tokenVolumes.push(commitmentVolume);

  const marketVolume = loadMarketTokenVolume(
    commitment.principalTokenAddress,
    commitment.marketplace
  );
  tokenVolumes.push(marketVolume);

  const lenderVolume = loadLenderTokenVolume(
    commitment.principalTokenAddress,
    loadLenderByMarketId(commitment.lenderAddress, commitment.marketplace)
  );
  tokenVolumes.push(lenderVolume);

  const collateralTokenId = commitment.collateralToken;
  if (collateralTokenId !== null) {
    const collateralToken = Token.load(collateralTokenId)!;
    const volumesCount = tokenVolumes.length;
    for (let i = 0; i < volumesCount; i++) {
      const tokenVolume = tokenVolumes[i];
      const collateralVolume = loadCollateralTokenVolume(
        tokenVolume,
        collateralToken
      );
      tokenVolumes.push(collateralVolume);
    }
  }

  return tokenVolumes;
}
