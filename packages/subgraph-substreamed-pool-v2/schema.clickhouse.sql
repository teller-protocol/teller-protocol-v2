CREATE TABLE IF NOT EXISTS factory_admin_changed (
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" UInt64,
    "new_admin" VARCHAR(42),
    "previous_admin" VARCHAR(42)
) ENGINE = MergeTree PRIMARY KEY ("evt_tx_hash","evt_index");
CREATE TABLE IF NOT EXISTS factory_beacon_upgraded (
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" UInt64,
    "beacon" VARCHAR(42)
) ENGINE = MergeTree PRIMARY KEY ("evt_tx_hash","evt_index");
CREATE TABLE IF NOT EXISTS factory_deployed_lender_group_contract (
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" UInt64,
    "group_contract" VARCHAR(42)
) ENGINE = MergeTree PRIMARY KEY ("evt_tx_hash","evt_index");
CREATE TABLE IF NOT EXISTS factory_upgraded (
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" UInt64,
    "implementation" VARCHAR(42)
) ENGINE = MergeTree PRIMARY KEY ("evt_tx_hash","evt_index");

CREATE TABLE IF NOT EXISTS lendergroup_borrower_accepted_funds (
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" UInt64,
    "evt_address" VARCHAR(42),
    "bid_id" UInt256,
    "borrower" VARCHAR(42),
    "collateral_amount" UInt256,
    "interest_rate" UInt16,
    "loan_duration" UInt32,
    "principal_amount" UInt256
) ENGINE = MergeTree PRIMARY KEY ("evt_tx_hash","evt_index");
CREATE TABLE IF NOT EXISTS lendergroup_defaulted_loan_liquidated (
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" UInt64,
    "evt_address" VARCHAR(42),
    "amount_due" UInt256,
    "bid_id" UInt256,
    "liquidator" VARCHAR(42),
    "token_amount_difference" Int256
) ENGINE = MergeTree PRIMARY KEY ("evt_tx_hash","evt_index");
CREATE TABLE IF NOT EXISTS lendergroup_earnings_withdrawn (
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" UInt64,
    "evt_address" VARCHAR(42),
    "amount_pool_shares_tokens" UInt256,
    "lender" VARCHAR(42),
    "principal_tokens_withdrawn" UInt256,
    "recipient" VARCHAR(42)
) ENGINE = MergeTree PRIMARY KEY ("evt_tx_hash","evt_index");
CREATE TABLE IF NOT EXISTS lendergroup_initialized (
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" UInt64,
    "evt_address" VARCHAR(42),
    "version" UInt8
) ENGINE = MergeTree PRIMARY KEY ("evt_tx_hash","evt_index");
CREATE TABLE IF NOT EXISTS lendergroup_lender_added_principal (
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" UInt64,
    "evt_address" VARCHAR(42),
    "amount" UInt256,
    "lender" VARCHAR(42),
    "shares_amount" UInt256,
    "shares_recipient" VARCHAR(42)
) ENGINE = MergeTree PRIMARY KEY ("evt_tx_hash","evt_index");
CREATE TABLE IF NOT EXISTS lendergroup_loan_repaid (
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" UInt64,
    "evt_address" VARCHAR(42),
    "bid_id" UInt256,
    "interest_amount" UInt256,
    "principal_amount" UInt256,
    "repayer" VARCHAR(42),
    "total_interest_collected" UInt256,
    "total_principal_repaid" UInt256
) ENGINE = MergeTree PRIMARY KEY ("evt_tx_hash","evt_index");
CREATE TABLE IF NOT EXISTS lendergroup_ownership_transferred (
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" UInt64,
    "evt_address" VARCHAR(42),
    "new_owner" VARCHAR(42),
    "previous_owner" VARCHAR(42)
) ENGINE = MergeTree PRIMARY KEY ("evt_tx_hash","evt_index");
CREATE TABLE IF NOT EXISTS lendergroup_paused (
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" UInt64,
    "evt_address" VARCHAR(42),
    "account" VARCHAR(42)
) ENGINE = MergeTree PRIMARY KEY ("evt_tx_hash","evt_index");
CREATE TABLE IF NOT EXISTS lendergroup_pool_initialized (
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" UInt64,
    "evt_address" VARCHAR(42),
    "collateral_token_address" VARCHAR(42),
    "interest_rate_lower_bound" UInt16,
    "interest_rate_upper_bound" UInt16,
    "liquidity_threshold_percent" UInt16,
    "loan_to_value_percent" UInt16,
    "market_id" UInt256,
    "max_loan_duration" UInt32,
    "pool_shares_token" VARCHAR(42),
    "principal_token_address" VARCHAR(42),
    "twap_interval" UInt32,
    "uniswap_pool_fee" UInt32
) ENGINE = MergeTree PRIMARY KEY ("evt_tx_hash","evt_index");
CREATE TABLE IF NOT EXISTS lendergroup_unpaused (
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" UInt64,
    "evt_address" VARCHAR(42),
    "account" VARCHAR(42)
) ENGINE = MergeTree PRIMARY KEY ("evt_tx_hash","evt_index");
