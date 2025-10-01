import { CollateralWithdrawn } from "../../generated/CollateralManager/CollateralManager"
import { group_pool_metric, teller_bid } from "../../generated/schema"
import { BigInt, Address, log } from "@graphprotocol/graph-ts"

export function handleCollateralWithdrawn(event: CollateralWithdrawn): void {
  let bidId = event.params._bidId
  let collateralType = event.params._type
  let collateralAddress = event.params._collateralAddress
  let amount = event.params._amount
  let tokenId = event.params._tokenId
  let recipient = event.params._recipient

  log.info("CollateralWithdrawn: bidId={}, type={}, collateralAddress={}, amount={}, tokenId={}, recipient={}", [
    bidId.toString(),
    collateralType.toString(),
    collateralAddress.toHexString(),
    amount.toString(),
    tokenId.toString(),
    recipient.toHexString()
  ])

  // Load the teller_bid entity to find which pool this bid belongs to
  let tellerBid = teller_bid.load(bidId.toString())

  if (tellerBid == null) {
    log.warning("CollateralWithdrawn: Could not find teller_bid for bidId={}", [bidId.toString()])
    return
  }

  // Get the pool address from the teller_bid
  let poolAddress = tellerBid.group_pool_address

  // Load the pool metric
  let poolMetric = group_pool_metric.load(poolAddress.toHexString())

  if (poolMetric == null) {
    log.warning("CollateralWithdrawn: Could not find pool metric for pool={}", [poolAddress.toHexString()])
    return
  }

  // Update the total collateral withdrawn for this pool
  poolMetric.total_collateral_tokens_withdrawn = poolMetric.total_collateral_tokens_withdrawn.plus(amount)

  // Also reduce the total collateral escrowed since it's being withdrawn
  //poolMetric.total_collateral_tokens_escrowed = poolMetric.total_collateral_tokens_escrowed.minus(amount)

  poolMetric.save()

  log.info("Updated pool {} - total_collateral_withdrawn: {}", [
    poolAddress.toHexString(),
    poolMetric.total_collateral_tokens_withdrawn.toString()
  ])
}
