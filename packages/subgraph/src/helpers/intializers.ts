import { Address, BigInt } from "@graphprotocol/graph-ts";

import { Token, TokenVolume } from "../../generated/schema";

import { loadLoanStatusCount } from "./loaders";

export function initTokenVolume(tokenVolume: TokenVolume, token: Token): void {
  tokenVolume.token = token.id;
  tokenVolume.lendingTokenAddress = Address.fromBytes(token.address);

  loadLoanStatusCount("tokenVolume", tokenVolume.id);

  tokenVolume.outstandingCapital = BigInt.zero();
  tokenVolume.totalAvailable = BigInt.zero();
  tokenVolume.totalLoaned = BigInt.zero();
  tokenVolume.totalActive = BigInt.zero();
  tokenVolume.totalDueSoon = BigInt.zero();
  tokenVolume.totalLate = BigInt.zero();
  tokenVolume.totalDefaulted = BigInt.zero();
  tokenVolume.totalRepaid = BigInt.zero();
  tokenVolume.totalLiquidated = BigInt.zero();

  tokenVolume._loanAcceptedCount = BigInt.zero();
  tokenVolume.loanAverage = BigInt.zero();

  tokenVolume.commissionEarned = BigInt.zero();
  tokenVolume.totalRepaidInterest = BigInt.zero();

  tokenVolume._aprWeightedTotal = BigInt.zero();
  tokenVolume.aprAverage = BigInt.zero();
  tokenVolume._aprActiveWeightedTotal = BigInt.zero();
  tokenVolume.aprActiveAverage = BigInt.zero();

  tokenVolume._durationTotal = BigInt.zero();
  tokenVolume.durationAverage = BigInt.zero();
}
