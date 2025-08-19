import {
  BorrowerAcceptedFunds,
  EarningsWithdrawn,
  LenderAddedPrincipal,
  LoanRepaid,
  DefaultedLoanLiquidated
} from "../../generated/templates/Pool/Pool"
import {
  group_borrower_accepted_funds,
  group_earnings_withdrawn,
  group_lender_added_principal,
  group_loan_repaid,
  group_defaulted_loan_liquidated,
  group_pool_metric,
  group_user_metric,
  group_pool_bid
} from "../../generated/schema"
import { BigInt, Address, BigDecimal } from "@graphprotocol/graph-ts"

function getOrCreateUserMetric(userAddress: Address, poolAddress: Address): group_user_metric {
  let id = poolAddress.toHexString() + "-" + userAddress.toHexString()
  let userMetric = group_user_metric.load(id)
  
  if (userMetric == null) {
    userMetric = new group_user_metric(id)
    userMetric.user_address = userAddress
    userMetric.group_pool_address = poolAddress
    userMetric.total_principal_tokens_committed = BigInt.fromI32(0)
    userMetric.total_principal_tokens_withdrawn = BigInt.fromI32(0)
    userMetric.total_principal_tokens_borrowed = BigInt.fromI32(0)
    userMetric.total_collateral_tokens_escrowed = BigInt.fromI32(0)
    userMetric.save()
  }
  
  return userMetric
}

export function handleBorrowerAcceptedFunds(event: BorrowerAcceptedFunds): void {
  let poolAddress = event.address
  let borrower = event.params.borrower
  let bidId = event.params.bidId
  let principalAmount = event.params.principalAmount
  let collateralAmount = event.params.collateralAmount
  let interestRate = event.params.interestRate
  let loanDuration = event.params.loanDuration

  // Create borrower accepted funds event entity
  let eventEntity = new group_borrower_accepted_funds(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  )
  eventEntity.evt_tx_hash = event.transaction.hash
  eventEntity.evt_index = event.logIndex
  eventEntity.evt_block_time = event.block.timestamp
  eventEntity.evt_block_number = event.block.number
  eventEntity.group_pool_address = poolAddress
  eventEntity.bid_id = bidId.toBigDecimal()
  eventEntity.borrower = borrower
  eventEntity.collateral_amount = collateralAmount.toBigDecimal()
  eventEntity.interest_rate = BigInt.fromI32(interestRate)
  eventEntity.loan_duration = loanDuration
  eventEntity.principal_amount = principalAmount.toBigDecimal()
  eventEntity.save()

  // Create or update pool bid entity
  let bidEntity = new group_pool_bid(poolAddress.toHexString() + "-" + bidId.toString())
  bidEntity.group_pool_address = poolAddress
  bidEntity.bid_id = bidId.toBigDecimal()
  bidEntity.borrower = borrower
  bidEntity.collateral_amount = collateralAmount.toBigDecimal()
  bidEntity.principal_amount = principalAmount.toBigDecimal()
  bidEntity.save()

  // Update pool metrics
  let poolMetric = group_pool_metric.load(poolAddress.toHexString())
  if (poolMetric != null) {
    poolMetric.total_principal_tokens_borrowed = poolMetric.total_principal_tokens_borrowed.plus(principalAmount)
    poolMetric.total_collateral_tokens_escrowed = poolMetric.total_collateral_tokens_escrowed.plus(collateralAmount)
    poolMetric.save()
  }

  // Update user metrics
  let userMetric = getOrCreateUserMetric(borrower, poolAddress)
  userMetric.total_principal_tokens_borrowed = userMetric.total_principal_tokens_borrowed.plus(principalAmount)
  userMetric.total_collateral_tokens_escrowed = userMetric.total_collateral_tokens_escrowed.plus(collateralAmount)
  userMetric.save()
}

export function handleEarningsWithdrawn(event: EarningsWithdrawn): void {
  let poolAddress = event.address
  let lender = event.params.lender
  let amountPoolSharesTokens = event.params.amountPoolSharesTokens
  let principalTokensWithdrawn = event.params.principalTokensWithdrawn
  let recipient = event.params.recipient

  // Create earnings withdrawn event entity
  let eventEntity = new group_earnings_withdrawn(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  )
  eventEntity.evt_tx_hash = event.transaction.hash
  eventEntity.evt_index = event.logIndex
  eventEntity.evt_block_time = event.block.timestamp
  eventEntity.evt_block_number = event.block.number
  eventEntity.group_pool_address = poolAddress
  eventEntity.amount_pool_shares_tokens = amountPoolSharesTokens.toBigDecimal()
  eventEntity.lender = lender
  eventEntity.principal_tokens_withdrawn = principalTokensWithdrawn.toBigDecimal()
  eventEntity.recipient = recipient
  eventEntity.save()

  // Update pool metrics
  let poolMetric = group_pool_metric.load(poolAddress.toHexString())
  if (poolMetric != null) {
    poolMetric.total_principal_tokens_withdrawn = poolMetric.total_principal_tokens_withdrawn.plus(principalTokensWithdrawn)
    poolMetric.save()
  }

  // Update user metrics
  let userMetric = getOrCreateUserMetric(lender, poolAddress)
  userMetric.total_principal_tokens_withdrawn = userMetric.total_principal_tokens_withdrawn.plus(principalTokensWithdrawn)
  userMetric.save()
}

export function handleLenderAddedPrincipal(event: LenderAddedPrincipal): void {
  let poolAddress = event.address
  let lender = event.params.lender
  let amount = event.params.amount
  let sharesAmount = event.params.sharesAmount
  let sharesRecipient = event.params.sharesRecipient

  // Create lender added principal event entity
  let eventEntity = new group_lender_added_principal(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  )
  eventEntity.evt_tx_hash = event.transaction.hash
  eventEntity.evt_index = event.logIndex
  eventEntity.evt_block_time = event.block.timestamp
  eventEntity.evt_block_number = event.block.number
  eventEntity.group_pool_address = poolAddress
  eventEntity.amount = amount.toBigDecimal()
  eventEntity.lender = lender
  eventEntity.shares_amount = sharesAmount.toBigDecimal()
  eventEntity.shares_recipient = sharesRecipient
  eventEntity.save()

  // Update pool metrics
  let poolMetric = group_pool_metric.load(poolAddress.toHexString())
  if (poolMetric != null) {
    poolMetric.total_principal_tokens_committed = poolMetric.total_principal_tokens_committed.plus(amount)
    poolMetric.save()
  }

  // Update user metrics
  let userMetric = getOrCreateUserMetric(lender, poolAddress)
  userMetric.total_principal_tokens_committed = userMetric.total_principal_tokens_committed.plus(amount)
  userMetric.save()
}

export function handleLoanRepaid(event: LoanRepaid): void {
  let poolAddress = event.address
  let bidId = event.params.bidId
  let repayer = event.params.repayer
  let principalAmount = event.params.principalAmount
  let interestAmount = event.params.interestAmount
  let totalPrincipalRepaid = event.params.totalPrincipalRepaid
  let totalInterestCollected = event.params.totalInterestCollected

  // Create loan repaid event entity
  let eventEntity = new group_loan_repaid(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  )
  eventEntity.evt_tx_hash = event.transaction.hash
  eventEntity.evt_index = event.logIndex
  eventEntity.evt_block_time = event.block.timestamp
  eventEntity.evt_block_number = event.block.number
  eventEntity.group_pool_address = poolAddress
  eventEntity.bid_id = bidId.toBigDecimal()
  eventEntity.interest_amount = interestAmount.toBigDecimal()
  eventEntity.principal_amount = principalAmount.toBigDecimal()
  eventEntity.repayer = repayer
  eventEntity.total_interest_collected = totalInterestCollected.toBigDecimal()
  eventEntity.total_principal_repaid = totalPrincipalRepaid.toBigDecimal()
  eventEntity.save()

  // Update pool metrics
  let poolMetric = group_pool_metric.load(poolAddress.toHexString())
  if (poolMetric != null) {
    poolMetric.total_principal_tokens_repaid = poolMetric.total_principal_tokens_repaid.plus(principalAmount)
    poolMetric.total_interest_collected = poolMetric.total_interest_collected.plus(interestAmount)
    poolMetric.save()
  }
}

export function handleLoanLiquidated(event: DefaultedLoanLiquidated): void {
  let poolAddress = event.address
  let bidId = event.params.bidId
  let liquidator = event.params.liquidator
  let amountDue = event.params.amountDue
  let tokenAmountDifference = event.params.tokenAmountDifference

  // Create defaulted loan liquidated event entity
  let eventEntity = new group_defaulted_loan_liquidated(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  )
  eventEntity.evt_tx_hash = event.transaction.hash
  eventEntity.evt_index = event.logIndex
  eventEntity.evt_block_time = event.block.timestamp
  eventEntity.evt_block_number = event.block.number
  eventEntity.group_pool_address = poolAddress
  eventEntity.amount_due = amountDue.toBigDecimal()
  eventEntity.bid_id = bidId.toBigDecimal()
  eventEntity.liquidator = liquidator
  eventEntity.token_amount_difference = tokenAmountDifference.toBigDecimal()
  eventEntity.save()

  // Update pool metrics
  let poolMetric = group_pool_metric.load(poolAddress.toHexString())
  if (poolMetric != null) {
    poolMetric.token_difference_from_liquidations = poolMetric.token_difference_from_liquidations.plus(tokenAmountDifference)
    poolMetric.save()
  }
}