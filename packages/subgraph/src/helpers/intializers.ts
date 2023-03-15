import { Address, BigInt } from "@graphprotocol/graph-ts";

import { Token, TokenVolume } from "../../generated/schema";

import { loadLoanStatusCount } from "./loaders";

export function initTokenVolume(tokenVolume: TokenVolume, token: Token): void {
  tokenVolume.token = token.id;
  tokenVolume.lendingTokenAddress = Address.fromString(token.id);

  loadLoanStatusCount("tokenVolume", tokenVolume.id);

  tokenVolume.outstandingCapital = BigInt.zero();
  tokenVolume.totalLoaned = BigInt.zero();
  tokenVolume._loanAcceptedCount = BigInt.zero();
  tokenVolume.loanAverage = BigInt.zero();

  tokenVolume.commissionEarned = BigInt.zero();
  tokenVolume.totalRepaidInterest = BigInt.zero();

  tokenVolume._aprWeightedTotal = BigInt.zero();
  tokenVolume.aprAverage = BigInt.zero();

  tokenVolume._durationWeightedTotal = BigInt.zero();
  tokenVolume.durationAverage = BigInt.zero();
}
