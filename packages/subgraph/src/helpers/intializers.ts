import { Address, BigInt } from "@graphprotocol/graph-ts";

import { Token, TokenVolume } from "../../generated/schema";

import { loadLoanCount } from "./loaders";

export function initTokenVolume(tokenVolume: TokenVolume, token: Token): void {
  tokenVolume.token = token.id;
  tokenVolume.lendingTokenAddress = Address.fromString(token.id);

  loadLoanCount("tokenVolume", tokenVolume.id);

  tokenVolume.outstandingCapital = BigInt.zero();
  tokenVolume.totalLoaned = BigInt.zero();
  tokenVolume.loanAverage = BigInt.zero();

  tokenVolume.commissionEarned = BigInt.zero();
  tokenVolume.totalRepaidInterest = BigInt.zero();

  tokenVolume._aprTotal = BigInt.zero();
  tokenVolume.aprAverage = BigInt.zero();

  tokenVolume._durationTotal = BigInt.zero();
  tokenVolume.durationAverage = BigInt.zero();
}
