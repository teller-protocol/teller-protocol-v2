CREATE TABLE IF NOT EXISTS factory_admin_changed (
      "id" VARCHAR(255) PRIMARY KEY,
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" DECIMAL,
    "new_admin" VARCHAR(42),
    "previous_admin" VARCHAR(42) 
);
CREATE TABLE IF NOT EXISTS factory_beacon_upgraded (
      "id" VARCHAR(255) PRIMARY KEY,
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" DECIMAL,
    "beacon" VARCHAR(42)
    );
CREATE TABLE IF NOT EXISTS factory_deployed_lender_group_contract (
      "id" VARCHAR(255) PRIMARY KEY,
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" DECIMAL,
    "group_contract" VARCHAR(42) 
);
CREATE TABLE IF NOT EXISTS factory_upgraded (
      "id" VARCHAR(255) PRIMARY KEY,
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" DECIMAL,
    "implementation" VARCHAR(42) 
);

CREATE TABLE IF NOT EXISTS group_borrower_accepted_funds (
      "id" VARCHAR(255) PRIMARY KEY,
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" DECIMAL,
    "evt_address" VARCHAR(42),
    "bid_id" DECIMAL,
    "borrower" VARCHAR(42),
    "collateral_amount" DECIMAL,
    "interest_rate" INT,
    "loan_duration" INT,
    "principal_amount" DECIMAL 
);
CREATE TABLE IF NOT EXISTS group_defaulted_loan_liquidated (
      "id" VARCHAR(255) PRIMARY KEY,
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" DECIMAL,
    "evt_address" VARCHAR(42),
    "amount_due" DECIMAL,
    "bid_id" DECIMAL,
    "liquidator" VARCHAR(42),
    "token_amount_difference" DECIMAL 
);
CREATE TABLE IF NOT EXISTS group_earnings_withdrawn (
      "id" VARCHAR(255) PRIMARY KEY,
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" DECIMAL,
    "evt_address" VARCHAR(42),
    "amount_pool_shares_tokens" DECIMAL,
    "lender" VARCHAR(42),
    "principal_tokens_withdrawn" DECIMAL,
    "recipient" VARCHAR(42) 
);
CREATE TABLE IF NOT EXISTS group_initialized (
      "id" VARCHAR(255) PRIMARY KEY,
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" DECIMAL,
    "group_pool_address" VARCHAR(42),
    "version" INT 
);
CREATE TABLE IF NOT EXISTS group_lender_added_principal (
      "id" VARCHAR(255) PRIMARY KEY,
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" DECIMAL,
    "evt_address" VARCHAR(42),
    "amount" DECIMAL,
    "lender" VARCHAR(42),
    "shares_amount" DECIMAL,
    "shares_recipient" VARCHAR(42) 
);
CREATE TABLE IF NOT EXISTS group_loan_repaid (
      "id" VARCHAR(255) PRIMARY KEY,
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" DECIMAL,
    "evt_address" VARCHAR(42),
    "bid_id" DECIMAL,
    "interest_amount" DECIMAL,
    "principal_amount" DECIMAL,
    "repayer" VARCHAR(42),
    "total_interest_collected" DECIMAL,
    "total_principal_repaid" DECIMAL 
);
CREATE TABLE IF NOT EXISTS group_ownership_transferred (
      "id" VARCHAR(255) PRIMARY KEY,
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" DECIMAL,
    "evt_address" VARCHAR(42),
    "new_owner" VARCHAR(42),
    "previous_owner" VARCHAR(42) 
);
CREATE TABLE IF NOT EXISTS group_paused (
      "id" VARCHAR(255) PRIMARY KEY,
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" DECIMAL,
    "evt_address" VARCHAR(42),
    "account" VARCHAR(42) 
);
CREATE TABLE IF NOT EXISTS group_pool_initialized (
      "id" VARCHAR(255) PRIMARY KEY,
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" DECIMAL,
    "group_pool_address" VARCHAR(42),
    "collateral_token_address" VARCHAR(42),
    "interest_rate_lower_bound" INT,
    "interest_rate_upper_bound" INT,
    "liquidity_threshold_percent" INT,
    "loan_to_value_percent" INT,
    "market_id" DECIMAL,
    "max_loan_duration" INT,
    "pool_shares_token" VARCHAR(42),
    "principal_token_address" VARCHAR(42),
    "twap_interval" INT,
    "uniswap_pool_fee" INT 
);
CREATE TABLE IF NOT EXISTS group_unpaused (
      "id" VARCHAR(255) PRIMARY KEY,
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" DECIMAL,
    "evt_address" VARCHAR(42),
    "account" VARCHAR(42) 
);

CREATE TABLE IF NOT EXISTS group_pool_bid (
      "id" VARCHAR(255) PRIMARY KEY,
    "created_at" TIMESTAMP,
    "group_pool_address" VARCHAR(42)  ,
     "borrower" VARCHAR(42) ,
       "principal_amount" NUMERIC,
         "collateral_amount" NUMERIC
);


CREATE TABLE IF NOT EXISTS group_pool_metric (
      "id" VARCHAR(255) PRIMARY KEY,
    "created_at" TIMESTAMP,
    "group_pool_address" VARCHAR(42)  ,
    "principal_token_address" VARCHAR(42),
    "collateral_token_address" VARCHAR(42),
    "shares_token_address" VARCHAR(42),
    "teller_v2_address" VARCHAR(42),
    "smart_commitment_forwarder_address" VARCHAR(42),
    "market_id" NUMERIC,
    "max_loan_duration" NUMERIC,
    "interest_rate_upper_bound" NUMERIC,
    "interest_rate_lower_bound" NUMERIC,
    "liquidity_threshold_percent" NUMERIC,
    "collateral_ratio" NUMERIC,
    "current_min_interest_rate" NUMERIC,
    "total_principal_tokens_committed" NUMERIC,
    "total_collateral_tokens_escrowed" NUMERIC,
    "total_principal_tokens_withdrawn" NUMERIC,
    "total_principal_tokens_borrowed" NUMERIC,
    "total_principal_tokens_repaid" NUMERIC,
    "total_interest_collected" NUMERIC,
    "token_difference_from_liquidations" NUMERIC,
    "total_collateral_withdrawn" NUMERIC
);

CREATE TABLE IF NOT EXISTS group_pool_metric_data_point (
      "id" VARCHAR(255) PRIMARY KEY,
    "group_pool_address" VARCHAR(42),
    "block_number" NUMERIC,
    "block_time" NUMERIC,
    "total_principal_tokens_committed" NUMERIC,
    "total_collateral_tokens_escrowed" NUMERIC,
    "total_collateral_tokens_withdrawn" NUMERIC,
    "total_principal_tokens_withdrawn" NUMERIC,
    "total_principal_tokens_borrowed" NUMERIC,
    "total_principal_tokens_repaid" NUMERIC,
    "total_interest_collected" NUMERIC,
    "token_difference_from_liquidations" NUMERIC 
);

CREATE TABLE IF NOT EXISTS group_pool_metric_data_point_daily (
      "id" VARCHAR(255) PRIMARY KEY,
    "group_pool_address" VARCHAR(42),
    "block_number" NUMERIC,
    "block_time" NUMERIC,

    "day_index" NUMERIC,
    "total_principal_tokens_committed" NUMERIC,
    "total_collateral_tokens_escrowed" NUMERIC,
    "total_collateral_tokens_withdrawn" NUMERIC,
    "total_principal_tokens_withdrawn" NUMERIC,
    "total_principal_tokens_borrowed" NUMERIC,
    "total_principal_tokens_repaid" NUMERIC,
    "total_interest_collected" NUMERIC,
    "token_difference_from_liquidations" NUMERIC 
);

CREATE TABLE IF NOT EXISTS group_pool_metric_data_point_weekly (
      "id" VARCHAR(255) PRIMARY KEY,
    "group_pool_address" VARCHAR(42),
    "block_number" NUMERIC,
    "block_time" NUMERIC,
    "week_index" NUMERIC,
    "total_principal_tokens_committed" NUMERIC,
    "total_collateral_tokens_escrowed" NUMERIC,
    "total_collateral_tokens_withdrawn" NUMERIC,
    "total_principal_tokens_withdrawn" NUMERIC,
    "total_principal_tokens_borrowed" NUMERIC,
    "total_principal_tokens_repaid" NUMERIC,
    "total_interest_collected" NUMERIC,
    "token_difference_from_liquidations" NUMERIC 
);


CREATE TABLE IF NOT EXISTS group_user_metric (
      "id" VARCHAR(255) PRIMARY KEY, 
    "group_pool_address" VARCHAR(42),
    "user_address" VARCHAR(42),
    "block_number" NUMERIC,
    "block_time" NUMERIC,
    "total_principal_tokens_committed" NUMERIC,
    "total_collateral_tokens_escrowed" NUMERIC,

    "total_interest_collected" NUMERIC,
        "total_principal_tokens_repaid" NUMERIC,

    
   
    "total_principal_tokens_withdrawn" NUMERIC,
    "total_principal_tokens_borrowed" NUMERIC
);
