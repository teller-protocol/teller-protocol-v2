CREATE TABLE IF NOT EXISTS factory_admin_changed (
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" DECIMAL,
    "new_admin" VARCHAR(40),
    "previous_admin" VARCHAR(40),
    PRIMARY KEY(evt_tx_hash,evt_index)
);
CREATE TABLE IF NOT EXISTS factory_beacon_upgraded (
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" DECIMAL,
    "beacon" VARCHAR(40),
    PRIMARY KEY(evt_tx_hash,evt_index)
);
CREATE TABLE IF NOT EXISTS factory_deployed_lender_group_contract (
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" DECIMAL,
    "group_contract" VARCHAR(40),
    PRIMARY KEY(evt_tx_hash,evt_index)
);
CREATE TABLE IF NOT EXISTS factory_upgraded (
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" DECIMAL,
    "implementation" VARCHAR(40),
    PRIMARY KEY(evt_tx_hash,evt_index)
);

CREATE TABLE IF NOT EXISTS lendergroup_borrower_accepted_funds (
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" DECIMAL,
    "evt_address" VARCHAR(40),
    "bid_id" DECIMAL,
    "borrower" VARCHAR(40),
    "collateral_amount" DECIMAL,
    "interest_rate" INT,
    "loan_duration" INT,
    "principal_amount" DECIMAL,
    PRIMARY KEY(evt_tx_hash,evt_index)
);
CREATE TABLE IF NOT EXISTS lendergroup_defaulted_loan_liquidated (
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" DECIMAL,
    "evt_address" VARCHAR(40),
    "amount_due" DECIMAL,
    "bid_id" DECIMAL,
    "liquidator" VARCHAR(40),
    "token_amount_difference" DECIMAL,
    PRIMARY KEY(evt_tx_hash,evt_index)
);
CREATE TABLE IF NOT EXISTS lendergroup_earnings_withdrawn (
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" DECIMAL,
    "evt_address" VARCHAR(40),
    "amount_pool_shares_tokens" DECIMAL,
    "lender" VARCHAR(40),
    "principal_tokens_withdrawn" DECIMAL,
    "recipient" VARCHAR(40),
    PRIMARY KEY(evt_tx_hash,evt_index)
);
CREATE TABLE IF NOT EXISTS lendergroup_initialized (
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" DECIMAL,
    "evt_address" VARCHAR(40),
    "version" INT,
    PRIMARY KEY(evt_tx_hash,evt_index)
);
CREATE TABLE IF NOT EXISTS lendergroup_lender_added_principal (
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" DECIMAL,
    "evt_address" VARCHAR(40),
    "amount" DECIMAL,
    "lender" VARCHAR(40),
    "shares_amount" DECIMAL,
    "shares_recipient" VARCHAR(40),
    PRIMARY KEY(evt_tx_hash,evt_index)
);
CREATE TABLE IF NOT EXISTS lendergroup_loan_repaid (
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" DECIMAL,
    "evt_address" VARCHAR(40),
    "bid_id" DECIMAL,
    "interest_amount" DECIMAL,
    "principal_amount" DECIMAL,
    "repayer" VARCHAR(40),
    "total_interest_collected" DECIMAL,
    "total_principal_repaid" DECIMAL,
    PRIMARY KEY(evt_tx_hash,evt_index)
);
CREATE TABLE IF NOT EXISTS lendergroup_ownership_transferred (
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" DECIMAL,
    "evt_address" VARCHAR(40),
    "new_owner" VARCHAR(40),
    "previous_owner" VARCHAR(40),
    PRIMARY KEY(evt_tx_hash,evt_index)
);
CREATE TABLE IF NOT EXISTS lendergroup_paused (
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" DECIMAL,
    "evt_address" VARCHAR(40),
    "account" VARCHAR(40),
    PRIMARY KEY(evt_tx_hash,evt_index)
);
CREATE TABLE IF NOT EXISTS lendergroup_pool_initialized (
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" DECIMAL,
    "evt_address" VARCHAR(40),
    "collateral_token_address" VARCHAR(40),
    "interest_rate_lower_bound" INT,
    "interest_rate_upper_bound" INT,
    "liquidity_threshold_percent" INT,
    "loan_to_value_percent" INT,
    "market_id" DECIMAL,
    "max_loan_duration" INT,
    "pool_shares_token" VARCHAR(40),
    "principal_token_address" VARCHAR(40),
    "twap_interval" INT,
    "uniswap_pool_fee" INT,
    PRIMARY KEY(evt_tx_hash,evt_index)
);
CREATE TABLE IF NOT EXISTS lendergroup_unpaused (
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" DECIMAL,
    "evt_address" VARCHAR(40),
    "account" VARCHAR(40),
    PRIMARY KEY(evt_tx_hash,evt_index)
);
CREATE TABLE IF NOT EXISTS group_pool_metric (
    "group_pool_address" VARCHAR(40),
    PRIMARY KEY(group_pool_address)
);
CREATE TABLE IF NOT EXISTS group_lender_metric (
    
    "user_lender_address" VARCHAR(40),
    PRIMARY KEY(user_lender_address)
);
CREATE TABLE IF NOT EXISTS group_pool_metric_data_point (
    "group_pool_address" VARCHAR(40),
    "block_number" DECIMAL,
    PRIMARY KEY(group_pool_address,block_number)
);