import { Address, BigInt } from "@graphprotocol/graph-ts";

import { TokenVolume } from "../../generated/schema";

export function initTokenVolume(
  token: TokenVolume,
  tokenAddress: Address
): void {
  token.lendingTokenAddress = tokenAddress;
  token.bids = [];
  token.activeLoans = BigInt.zero();
  token.closedLoans = BigInt.zero();

  token.outstandingCapital = BigInt.zero();
  token.totalLoaned = BigInt.zero();
  token.loanAverage = BigInt.zero();

  token.commissionEarned = BigInt.zero();
  token.totalRepaidInterest = BigInt.zero();

  token._aprTotal = BigInt.zero();
  token.aprAverage = BigInt.zero();

  token._durationTotal = BigInt.zero();
  token.durationAverage = BigInt.zero();
}
