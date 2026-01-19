import {
  CollateralClaimed,
  CollateralCommitted,
  CollateralDeposited,
  CollateralEscrowDeployed,
  CollateralManager,
  CollateralWithdrawn
} from "../../generated/CollateralManager/CollateralManager";
import { TellerV2 } from "../../generated/CollateralManager/TellerV2";
import { Bid, CollateralDeposit, CollateralWithdrawal } from "../../generated/schema";
import { updateCollateral } from "../collateral-manager/updaters";
import { BidStatus, bidStatusToEnum, isBidDefaulted } from "../helpers/bid";
import { loadBidById, loadCollateral } from "../helpers/loaders";
import { updateBidStatus } from "../helpers/updaters";

export function handleCollateralEscrowDeployed(
  event: CollateralEscrowDeployed
): void {
  const bid: Bid = loadBidById(event.params._bidId);
  bid.collateralEscrow = event.params._collateralEscrow;
  bid.save();
}

export function handleCollateralEscrowDeployeds(
  events: CollateralEscrowDeployed[]
): void {
  events.forEach(event => {
    handleCollateralEscrowDeployed(event);
  });
}

export function handleCollateralCommitted(event: CollateralCommitted): void {
  // Load collateral by bidId and collateral address
  const collateral = loadCollateral(
    event.params._bidId.toString(),
    event.params._collateralAddress,
    collateralTypeToTokenType(event.params._type),
    event.params._tokenId
  );
  updateCollateral(collateral, event);
  collateral.status = "Committed";
  collateral.save();
}

export function handleCollateralCommitteds(
  events: CollateralCommitted[]
): void {
  events.forEach(event => {
    handleCollateralCommitted(event);
  });
}

export function handleCollateralDeposited(event: CollateralDeposited): void {
  const collateral = loadCollateral(
    event.params._bidId.toString(),
    event.params._collateralAddress,
    collateralTypeToTokenType(event.params._type),
    event.params._tokenId
  );
  updateCollateral(collateral, event);
  collateral.status = "Deposited";
  collateral.save();

  // Create CollateralDeposit entity
  const depositId = event.transaction.hash.toHex() + "-" + event.logIndex.toString();
  const deposit = new CollateralDeposit(depositId);
  deposit.bid = event.params._bidId.toString();
  deposit.collateralAddress = event.params._collateralAddress;
  deposit.amount = event.params._amount;
  deposit.tokenId = event.params._tokenId;
  deposit.collateralType = collateralTypeToString(event.params._type);
  deposit.timestamp = event.block.timestamp;
  deposit.transactionHash = event.transaction.hash.toHex();
  deposit.save();
}

export function handleCollateralDepositeds(
  events: CollateralDeposited[]
): void {
  events.forEach(event => {
    handleCollateralDeposited(event);
  });
}

export function handleCollateralWithdrawn(event: CollateralWithdrawn): void {
  const collateral = loadCollateral(
    event.params._bidId.toString(),
    event.params._collateralAddress,
    collateralTypeToTokenType(event.params._type),
    event.params._tokenId
  );
  updateCollateral(collateral, event);
  collateral.receiver = event.params._recipient;
  collateral.status = "Withdrawn";
  collateral.save();

  // Create CollateralWithdrawal entity
  const withdrawalId = event.transaction.hash.toHex() + "-" + event.logIndex.toString();
  const withdrawal = new CollateralWithdrawal(withdrawalId);
  withdrawal.bid = event.params._bidId.toString();
  withdrawal.collateralAddress = event.params._collateralAddress;
  withdrawal.amount = event.params._amount;
  withdrawal.tokenId = event.params._tokenId;
  withdrawal.collateralType = collateralTypeToString(event.params._type);
  withdrawal.recipient = event.params._recipient;
  withdrawal.timestamp = event.block.timestamp;
  withdrawal.transactionHash = event.transaction.hash.toHex();
  withdrawal.save();
}

/**
 * Converts the collateral type to the token type. Collateral type enum on the contract is:
 * enum CollateralType {
 *   ERC20,
 *   ERC721,
 *   ERC1155
 * }
 * and the token type enum for Subgraph has 1 extra value for UNKNOWN
 *
 * @param type
 */
function collateralTypeToTokenType(type: i32): i32 {
  return i32.add(type, 1);
}

/**
 * Converts the collateral type enum to a string representation.
 * @param type
 */
function collateralTypeToString(type: i32): string {
  if (type == 0) return "ERC20";
  if (type == 1) return "ERC721";
  if (type == 2) return "ERC1155";
  return "UNKNOWN";
}

export function handleCollateralWithdrawns(
  events: CollateralWithdrawn[]
): void {
  events.forEach(event => {
    handleCollateralWithdrawn(event);
  });
}

/**
 * Sets the bid status to `Claimed` when the collateral is claimed from a defaulted loan.
 * @param event
 */
export function handleCollateralClaimed(event: CollateralClaimed): void {
  const bid = loadBidById(event.params._bidId);

  const collateralManager = CollateralManager.bind(event.address);
  const tellerV2 = TellerV2.bind(collateralManager.tellerV2());

  // If the bid is not Repaid, then it means the lender has claimed collateral
  // without making a payment. In this case, we set the bid status to `Claimed`.
  if (tellerV2.getBidState(bid.bidId) !== BidStatus.Repaid) {
    updateBidStatus(bid, BidStatus.Claimed);
  }
}

export function handleCollateralClaimeds(events: CollateralClaimed[]): void {
  events.forEach(event => {
    handleCollateralClaimed(event);
  });
}
