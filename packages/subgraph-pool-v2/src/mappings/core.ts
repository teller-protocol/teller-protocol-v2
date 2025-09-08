import {
  BorrowerAcceptedFunds,
  Withdraw,
  Deposit,
  LoanRepaid,
  DefaultedLoanLiquidated,
  PoolInitialized
} from "../../generated/templates/Pool/Pool"
import {
  group_borrower_accepted_funds,
  group_earnings_withdrawn,
  group_lender_added_principal,
  group_loan_repaid,
  group_defaulted_loan_liquidated,
  group_pool_metric,
  group_user_metric,
  group_pool_bid,
  group_pool_metric_data_point_daily,
  group_pool_metric_data_point_weekly
} from "../../generated/schema"
import { BigInt, Address, BigDecimal } from "@graphprotocol/graph-ts"

// Constants for time calculations
const SECONDS_IN_DAY = BigInt.fromI32(86400)  // 24 * 60 * 60
const SECONDS_IN_WEEK = BigInt.fromI32(604800)  // 7 * 24 * 60 * 60

function getDayIndex(timestamp: BigInt): BigInt {
  return timestamp.div(SECONDS_IN_DAY)
}

function getWeekIndex(timestamp: BigInt): BigInt {
  return timestamp.div(SECONDS_IN_WEEK)
}

function updateOrCreateDailyDataPoint(poolAddress: Address, blockNumber: BigInt, timestamp: BigInt): void {
  let dayIndex = getDayIndex(timestamp)
  let dailyId = poolAddress.toHexString() + "-" + dayIndex.toString()
  
  let dailyDataPoint = group_pool_metric_data_point_daily.load(dailyId)
  if (dailyDataPoint == null) {
    dailyDataPoint = new group_pool_metric_data_point_daily(dailyId)
    dailyDataPoint.group_pool_address = poolAddress
    dailyDataPoint.total_principal_tokens_committed = BigInt.fromI32(0)
    dailyDataPoint.total_principal_tokens_withdrawn = BigInt.fromI32(0)
    dailyDataPoint.total_collateral_tokens_escrowed = BigInt.fromI32(0)
    dailyDataPoint.total_collateral_tokens_withdrawn = BigInt.fromI32(0)
    dailyDataPoint.total_principal_tokens_borrowed = BigInt.fromI32(0)
    dailyDataPoint.total_principal_tokens_repaid = BigInt.fromI32(0)
    dailyDataPoint.total_interest_collected = BigInt.fromI32(0)
    dailyDataPoint.token_difference_from_liquidations = BigInt.fromI32(0)
  }
  
  // Update with latest block info and current pool metric values
  dailyDataPoint.block_number = blockNumber
  dailyDataPoint.block_time = timestamp
  
  // Load current pool metric to get latest values
  let poolMetric = group_pool_metric.load(poolAddress.toHexString())
  if (poolMetric != null) {
    dailyDataPoint.total_principal_tokens_committed = poolMetric.total_principal_tokens_committed
    dailyDataPoint.total_principal_tokens_withdrawn = poolMetric.total_principal_tokens_withdrawn
    dailyDataPoint.total_collateral_tokens_escrowed = poolMetric.total_collateral_tokens_escrowed
    dailyDataPoint.total_collateral_tokens_withdrawn = poolMetric.total_collateral_withdrawn
    dailyDataPoint.total_principal_tokens_borrowed = poolMetric.total_principal_tokens_borrowed
    dailyDataPoint.total_principal_tokens_repaid = poolMetric.total_principal_tokens_repaid
    dailyDataPoint.total_interest_collected = poolMetric.total_interest_collected
    dailyDataPoint.token_difference_from_liquidations = poolMetric.token_difference_from_liquidations
  }
  
  dailyDataPoint.save()
}

function updateOrCreateWeeklyDataPoint(poolAddress: Address, blockNumber: BigInt, timestamp: BigInt): void {
  let weekIndex = getWeekIndex(timestamp)
  let weeklyId = poolAddress.toHexString() + "-" + weekIndex.toString()
  
  let weeklyDataPoint = group_pool_metric_data_point_weekly.load(weeklyId)
  if (weeklyDataPoint == null) {
    weeklyDataPoint = new group_pool_metric_data_point_weekly(weeklyId)
    weeklyDataPoint.group_pool_address = poolAddress
    weeklyDataPoint.total_principal_tokens_committed = BigInt.fromI32(0)
    weeklyDataPoint.total_principal_tokens_withdrawn = BigInt.fromI32(0)
    weeklyDataPoint.total_collateral_tokens_escrowed = BigInt.fromI32(0)
    weeklyDataPoint.total_collateral_tokens_withdrawn = BigInt.fromI32(0)
    weeklyDataPoint.total_principal_tokens_borrowed = BigInt.fromI32(0)
    weeklyDataPoint.total_principal_tokens_repaid = BigInt.fromI32(0)
    weeklyDataPoint.total_interest_collected = BigInt.fromI32(0)
    weeklyDataPoint.token_difference_from_liquidations = BigInt.fromI32(0)
  }
  
  // Update with latest block info and current pool metric values
  weeklyDataPoint.block_number = blockNumber
  weeklyDataPoint.block_time = timestamp
  
  // Load current pool metric to get latest values
  let poolMetric = group_pool_metric.load(poolAddress.toHexString())
  if (poolMetric != null) {
    weeklyDataPoint.total_principal_tokens_committed = poolMetric.total_principal_tokens_committed
    weeklyDataPoint.total_principal_tokens_withdrawn = poolMetric.total_principal_tokens_withdrawn
    weeklyDataPoint.total_collateral_tokens_escrowed = poolMetric.total_collateral_tokens_escrowed
    weeklyDataPoint.total_collateral_tokens_withdrawn = poolMetric.total_collateral_withdrawn
    weeklyDataPoint.total_principal_tokens_borrowed = poolMetric.total_principal_tokens_borrowed
    weeklyDataPoint.total_principal_tokens_repaid = poolMetric.total_principal_tokens_repaid
    weeklyDataPoint.total_interest_collected = poolMetric.total_interest_collected
    weeklyDataPoint.token_difference_from_liquidations = poolMetric.token_difference_from_liquidations
  }
  
  weeklyDataPoint.save()
}

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

  // Update daily and weekly data points
  updateOrCreateDailyDataPoint(poolAddress, event.block.number, event.block.timestamp)
  updateOrCreateWeeklyDataPoint(poolAddress, event.block.number, event.block.timestamp)
}

export function handleWithdraw(event: Withdraw): void {
  let poolAddress = event.address
  let lender = event.params.caller 
  let recipient = event.params.receiver 
  let owner = event.params.owner 
  let amountPoolSharesTokens = event.params.shares
  let principalTokensWithdrawn = event.params.assets
 

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

  // Update daily and weekly data points
  updateOrCreateDailyDataPoint(poolAddress, event.block.number, event.block.timestamp)
  updateOrCreateWeeklyDataPoint(poolAddress, event.block.number, event.block.timestamp)
}

export function handleDeposit(event: Deposit): void {
  let poolAddress = event.address
  let lender = event.params.caller
  let owner = event.params.owner   //not used for now 
  let amount = event.params.assets
  let sharesAmount = event.params.shares
  let sharesRecipient = event.params.caller

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

  // Update daily and weekly data points
  updateOrCreateDailyDataPoint(poolAddress, event.block.number, event.block.timestamp)
  updateOrCreateWeeklyDataPoint(poolAddress, event.block.number, event.block.timestamp)
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

  // Update daily and weekly data points
  updateOrCreateDailyDataPoint(poolAddress, event.block.number, event.block.timestamp)
  updateOrCreateWeeklyDataPoint(poolAddress, event.block.number, event.block.timestamp)
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

  // Update daily and weekly data points
  updateOrCreateDailyDataPoint(poolAddress, event.block.number, event.block.timestamp)
  updateOrCreateWeeklyDataPoint(poolAddress, event.block.number, event.block.timestamp)
}

export function handlePoolInitialized(event: PoolInitialized): void {
  let poolAddress = event.address
  let principalTokenAddress = event.params.principalTokenAddress
  let collateralTokenAddress = event.params.collateralTokenAddress
  let marketId = event.params.marketId
  let maxLoanDuration = event.params.maxLoanDuration
  let interestRateLowerBound = event.params.interestRateLowerBound
  let interestRateUpperBound = event.params.interestRateUpperBound
  let liquidityThresholdPercent = event.params.liquidityThresholdPercent
  let loanToValuePercent = event.params.loanToValuePercent
  let poolSharesToken = event.address

  // Create or update pool metric with all initialization parameters
  let poolMetric = group_pool_metric.load(poolAddress.toHexString())
  if (poolMetric == null) {
    poolMetric = new group_pool_metric(poolAddress.toHexString())
    poolMetric.group_pool_address = poolAddress
    poolMetric.created_at = event.block.timestamp
    
    // Initialize counters to zero
    poolMetric.total_principal_tokens_committed = BigInt.fromI32(0)
    poolMetric.total_principal_tokens_withdrawn = BigInt.fromI32(0)
    poolMetric.total_principal_tokens_borrowed = BigInt.fromI32(0)
    poolMetric.total_collateral_tokens_escrowed = BigInt.fromI32(0)
    poolMetric.total_principal_tokens_repaid = BigInt.fromI32(0)
    poolMetric.total_interest_collected = BigInt.fromI32(0)
    poolMetric.token_difference_from_liquidations = BigInt.fromI32(0)
    poolMetric.total_collateral_withdrawn = BigInt.fromI32(0)
    
    // Set placeholder values for RPC fields - these will need to be filled from contract calls
    poolMetric.teller_v2_address = Address.zero()
    poolMetric.smart_commitment_forwarder_address = Address.zero()
    poolMetric.current_min_interest_rate = BigInt.fromI32(0)
  }
  
  // Set all parameters from PoolInitialized event
  poolMetric.principal_token_address = principalTokenAddress
  poolMetric.collateral_token_address = collateralTokenAddress
  poolMetric.shares_token_address = poolSharesToken
  poolMetric.market_id = marketId
  poolMetric.max_loan_duration = maxLoanDuration
  poolMetric.interest_rate_lower_bound = BigInt.fromI32(interestRateLowerBound)
  poolMetric.interest_rate_upper_bound = BigInt.fromI32(interestRateUpperBound)
  poolMetric.liquidity_threshold_percent = BigInt.fromI32(liquidityThresholdPercent)
  poolMetric.collateral_ratio = BigInt.fromI32(loanToValuePercent)
  poolMetric.save()

  // Update daily and weekly data points
  updateOrCreateDailyDataPoint(poolAddress, event.block.number, event.block.timestamp)
  updateOrCreateWeeklyDataPoint(poolAddress, event.block.number, event.block.timestamp)
}