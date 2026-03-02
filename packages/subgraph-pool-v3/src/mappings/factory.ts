import { DeployedLenderGroupContract } from "../../generated/Factory/Factory"
import { Pool as PoolTemplate } from "../../generated/templates"
import { group_pool_metric, factory_deployed_lender_group_contract } from "../../generated/schema"
import { BigInt, Address } from "@graphprotocol/graph-ts"

export function handleLenderGroupDeployed(event: DeployedLenderGroupContract): void {
  let groupContract = event.params.groupContract

  // Create the factory event entity
  let factoryEvent = new factory_deployed_lender_group_contract(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  )
  factoryEvent.evt_tx_hash = event.transaction.hash
  factoryEvent.evt_index = event.logIndex
  factoryEvent.evt_block_time = event.block.timestamp
  factoryEvent.evt_block_number = event.block.number
  factoryEvent.group_contract = groupContract
  factoryEvent.save()

  // Create the pool metric entity for this new group
  let poolMetric = new group_pool_metric(groupContract.toHexString())
  poolMetric.group_pool_address = groupContract
  poolMetric.created_at = event.block.timestamp

  // Initialize all numeric fields to zero
  poolMetric.market_id = BigInt.fromI32(0)
  poolMetric.max_loan_duration = BigInt.fromI32(0)
  poolMetric.interest_rate_upper_bound = BigInt.fromI32(0)
  poolMetric.interest_rate_lower_bound = BigInt.fromI32(0)
  poolMetric.current_min_interest_rate = BigInt.fromI32(0)
  poolMetric.liquidity_threshold_percent = BigInt.fromI32(0)
  poolMetric.collateral_ratio = BigInt.fromI32(0)
  poolMetric.total_principal_tokens_committed = BigInt.fromI32(0)
  poolMetric.total_principal_tokens_withdrawn = BigInt.fromI32(0)
  poolMetric.total_principal_tokens_borrowed = BigInt.fromI32(0)
  poolMetric.total_collateral_tokens_deposited = BigInt.fromI32(0)
  poolMetric.total_collateral_tokens_withdrawn = BigInt.fromI32(0)
  poolMetric.total_principal_tokens_repaid = BigInt.fromI32(0)
  poolMetric.total_principal_tokens_repaid_by_liquidation_auction = BigInt.fromI32(0)
  poolMetric.total_interest_collected = BigInt.fromI32(0)
  poolMetric.token_difference_from_liquidations = BigInt.fromI32(0)


  // Initialize address fields to zero address (will be populated by pool events)
  poolMetric.principal_token_address = Address.zero()
  poolMetric.collateral_token_address = Address.zero()
  poolMetric.shares_token_address = Address.zero()
  poolMetric.teller_v2_address = Address.zero()
  poolMetric.smart_commitment_forwarder_address = Address.zero()

  poolMetric.save()

  // Create the dynamic data source template to start indexing this pool
  PoolTemplate.create(groupContract)
}
