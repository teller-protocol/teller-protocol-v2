import { Address, BigInt } from "@graphprotocol/graph-ts";

import { TokenVolume } from '../../generated/schema'

export function initTokenVolume(token: TokenVolume, tokenAddress: Address): void {
  token.lendingTokenAddress = tokenAddress;
  token.totalLoaned = BigInt.zero();
  token.aprAverage = BigInt.zero();
  token._aprTotal = BigInt.zero();
  token.loanAverage = BigInt.zero();
  token.highestLoan = BigInt.zero();
  token.lowestLoan = BigInt.zero();
  token.durationAverage = BigInt.zero();
  token._durationTotal = BigInt.zero();
  token.activeLoans = BigInt.zero();
  token.closedLoans = BigInt.zero();
  token.commissionEarned = BigInt.zero();
  token.outstandingCapital = BigInt.zero();
}
