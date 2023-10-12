import {
    Address,
    BigInt,
    Entity,
    ethereum,
    Value
  } from "@graphprotocol/graph-ts";
  
  import { CollateralCommitted } from "../../generated/CollateralManager/CollateralManager";
  import {
    Bid,
    BidCollateral,
    Borrower,
    Commitment,
    Lender,
    LoanStatusCount,
    MarketPlace,
    Payment,
    Protocol,
    Token,
    TokenVolume
  } from "../../generated/schema";
  
  export function updateCollateral(
    collateral: BidCollateral,
    event: ethereum.Event
  ): void {
    const evt = changetype<CollateralCommitted>(event);
    collateral.amount = evt.params._amount;
    collateral.tokenId = evt.params._tokenId;
    collateral.collateralAddress = evt.params._collateralAddress;
  }
  