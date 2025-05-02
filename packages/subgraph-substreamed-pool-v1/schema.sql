
DROP TABLE IF EXISTS factory_admin_changed CASCADE;
DROP TABLE IF EXISTS factory_beacon_upgraded CASCADE;
DROP TABLE IF EXISTS factory_deployed_lender_group_contract CASCADE;
DROP TABLE IF EXISTS factory_upgraded CASCADE;
DROP TABLE IF EXISTS group_borrower_accepted_funds CASCADE;
DROP TABLE IF EXISTS group_defaulted_loan_liquidated CASCADE;
DROP TABLE IF EXISTS group_earnings_withdrawn CASCADE;
DROP TABLE IF EXISTS group_initialized CASCADE;
DROP TABLE IF EXISTS group_lender_added_principal CASCADE;
DROP TABLE IF EXISTS group_loan_repaid CASCADE;
DROP TABLE IF EXISTS group_ownership_transferred CASCADE;
DROP TABLE IF EXISTS group_paused CASCADE;
DROP TABLE IF EXISTS group_pool_initialized CASCADE;
DROP TABLE IF EXISTS group_unpaused CASCADE;
DROP TABLE IF EXISTS group_pool_metric CASCADE;
DROP TABLE IF EXISTS group_pool_metric_data_point CASCADE;
DROP TABLE IF EXISTS group_pool_metric_data_point_daily CASCADE;
DROP TABLE IF EXISTS group_pool_metric_data_point_weekly CASCADE;
DROP TABLE IF EXISTS group_user_metric CASCADE;

CREATE TABLE IF NOT EXISTS factory_admin_changed (
     "id" VARCHAR PRIMARY KEY, 
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" DECIMAL,
    "new_admin" VARCHAR(40),
    "previous_admin" VARCHAR(40)
);
CREATE TABLE IF NOT EXISTS factory_beacon_upgraded (
     "id" VARCHAR PRIMARY KEY, 
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" DECIMAL,
    "beacon" VARCHAR(40)
);
CREATE TABLE IF NOT EXISTS factory_deployed_lender_group_contract (
     "id" VARCHAR PRIMARY KEY, 
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" DECIMAL,
    "group_contract" VARCHAR(40)
);
CREATE TABLE IF NOT EXISTS factory_upgraded (
     "id" VARCHAR PRIMARY KEY, 
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" DECIMAL,
    "implementation" VARCHAR(40)
);

CREATE TABLE IF NOT EXISTS group_borrower_accepted_funds (
      "id" VARCHAR PRIMARY KEY, 
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
    "principal_amount" DECIMAL
);
CREATE TABLE IF NOT EXISTS group_defaulted_loan_liquidated (
     "id" VARCHAR PRIMARY KEY, 
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" DECIMAL,
    "evt_address" VARCHAR(40),
    "amount_due" DECIMAL,
    "bid_id" DECIMAL,
    "liquidator" VARCHAR(40),
    "token_amount_difference" DECIMAL
);
CREATE TABLE IF NOT EXISTS group_earnings_withdrawn (
    "id" VARCHAR PRIMARY KEY, 
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" DECIMAL,
    "evt_address" VARCHAR(40),
    "amount_pool_shares_tokens" DECIMAL,
    "lender" VARCHAR(40),
    "principal_tokens_withdrawn" DECIMAL,
    "recipient" VARCHAR(40)
);
CREATE TABLE IF NOT EXISTS group_initialized (
     "id" VARCHAR PRIMARY KEY, 
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" DECIMAL,
    "evt_address" VARCHAR(40),
    "version" INT 
);
CREATE TABLE IF NOT EXISTS group_lender_added_principal (
     "id" VARCHAR PRIMARY KEY, 
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" DECIMAL,
    "evt_address" VARCHAR(40),
    "amount" DECIMAL,
    "lender" VARCHAR(40),
    "shares_amount" DECIMAL,
    "shares_recipient" VARCHAR(40) 
);
CREATE TABLE IF NOT EXISTS group_loan_repaid (
     "id" VARCHAR PRIMARY KEY, 
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
    "total_principal_repaid" DECIMAL
);
CREATE TABLE IF NOT EXISTS group_ownership_transferred (
     "id" VARCHAR PRIMARY KEY, 
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" DECIMAL,
    "evt_address" VARCHAR(40),
    "new_owner" VARCHAR(40),
    "previous_owner" VARCHAR(40)
   
);
CREATE TABLE IF NOT EXISTS group_paused (
     "id" VARCHAR PRIMARY KEY, 
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" DECIMAL,
    "evt_address" VARCHAR(40),
    "account" VARCHAR(40)
   
);
CREATE TABLE IF NOT EXISTS group_pool_initialized (
     "id" VARCHAR PRIMARY KEY, 
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
    "uniswap_pool_fee" INT
   
);
CREATE TABLE IF NOT EXISTS group_unpaused (
     "id" VARCHAR PRIMARY KEY, 
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" DECIMAL,
    "evt_address" VARCHAR(40),
    "account" VARCHAR(40)
    
);
CREATE TABLE IF NOT EXISTS group_pool_metric (
     "id" VARCHAR PRIMARY KEY, 
    "created_at" TIMESTAMP,
    "group_pool_address" VARCHAR(40)  ,
    "principal_token_address" VARCHAR(40),
    "collateral_token_address" VARCHAR(40),
    "shares_token_address" VARCHAR(40),
    "teller_v2_address" VARCHAR(40),
    "smart_commitment_forwarder_address" VARCHAR(40),
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
     "id" VARCHAR PRIMARY KEY, 
    "group_pool_address" VARCHAR(40),
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
     "id" VARCHAR PRIMARY KEY, 
    "group_pool_address" VARCHAR(40),
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

CREATE TABLE IF NOT EXISTS group_pool_metric_data_point_weekly (
     "id" VARCHAR PRIMARY KEY, 
    "group_pool_address" VARCHAR(40),
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


CREATE TABLE IF NOT EXISTS group_user_metric (
     "id" VARCHAR PRIMARY KEY, 
    "group_pool_address" VARCHAR(40),
    "user_address" VARCHAR(40),
    "block_number" NUMERIC,
    "block_time" NUMERIC,
    "total_principal_tokens_committed" NUMERIC,
    "total_collateral_tokens_escrowed" NUMERIC,
   
    "total_principal_tokens_withdrawn" NUMERIC,
    "total_principal_tokens_borrowed" NUMERIC
);