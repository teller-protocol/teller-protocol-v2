CREATE TABLE IF NOT EXISTS tellerv2_accepted_bid (
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" UInt64,
    "bid_id" UInt256,
    "lender" VARCHAR(40)
) ENGINE = MergeTree PRIMARY KEY ("evt_tx_hash","evt_index");
CREATE TABLE IF NOT EXISTS tellerv2_admin_changed (
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" UInt64,
    "new_admin" VARCHAR(40),
    "previous_admin" VARCHAR(40)
) ENGINE = MergeTree PRIMARY KEY ("evt_tx_hash","evt_index");
CREATE TABLE IF NOT EXISTS tellerv2_cancelled_bid (
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" UInt64,
    "bid_id" UInt256
) ENGINE = MergeTree PRIMARY KEY ("evt_tx_hash","evt_index");
CREATE TABLE IF NOT EXISTS tellerv2_fee_paid (
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" UInt64,
    "amount" UInt256,
    "bid_id" UInt256,
    "fee_type" TEXT
) ENGINE = MergeTree PRIMARY KEY ("evt_tx_hash","evt_index");
CREATE TABLE IF NOT EXISTS tellerv2_initialized (
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" UInt64,
    "version" UInt8
) ENGINE = MergeTree PRIMARY KEY ("evt_tx_hash","evt_index");
CREATE TABLE IF NOT EXISTS tellerv2_loan_liquidated (
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" UInt64,
    "bid_id" UInt256,
    "liquidator" VARCHAR(40)
) ENGINE = MergeTree PRIMARY KEY ("evt_tx_hash","evt_index");
CREATE TABLE IF NOT EXISTS tellerv2_loan_repaid (
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" UInt64,
    "bid_id" UInt256
) ENGINE = MergeTree PRIMARY KEY ("evt_tx_hash","evt_index");
CREATE TABLE IF NOT EXISTS tellerv2_loan_repayment (
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" UInt64,
    "bid_id" UInt256
) ENGINE = MergeTree PRIMARY KEY ("evt_tx_hash","evt_index");
CREATE TABLE IF NOT EXISTS tellerv2_market_forwarder_approved (
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" UInt64,
    "forwarder" VARCHAR(40),
    "market_id" UInt256,
    "sender" VARCHAR(40)
) ENGINE = MergeTree PRIMARY KEY ("evt_tx_hash","evt_index");
CREATE TABLE IF NOT EXISTS tellerv2_market_forwarder_renounced (
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" UInt64,
    "forwarder" VARCHAR(40),
    "market_id" UInt256,
    "sender" VARCHAR(40)
) ENGINE = MergeTree PRIMARY KEY ("evt_tx_hash","evt_index");
CREATE TABLE IF NOT EXISTS tellerv2_market_owner_cancelled_bid (
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" UInt64,
    "bid_id" UInt256
) ENGINE = MergeTree PRIMARY KEY ("evt_tx_hash","evt_index");
CREATE TABLE IF NOT EXISTS tellerv2_ownership_transferred (
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" UInt64,
    "new_owner" VARCHAR(40),
    "previous_owner" VARCHAR(40)
) ENGINE = MergeTree PRIMARY KEY ("evt_tx_hash","evt_index");
CREATE TABLE IF NOT EXISTS tellerv2_paused (
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" UInt64,
    "account" VARCHAR(40)
) ENGINE = MergeTree PRIMARY KEY ("evt_tx_hash","evt_index");
CREATE TABLE IF NOT EXISTS tellerv2_protocol_fee_set (
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" UInt64,
    "new_fee" UInt16,
    "old_fee" UInt16
) ENGINE = MergeTree PRIMARY KEY ("evt_tx_hash","evt_index");
CREATE TABLE IF NOT EXISTS tellerv2_submitted_bid (
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" UInt64,
    "bid_id" UInt256,
    "borrower" VARCHAR(40),
    "metadata_uri" TEXT,
    "receiver" VARCHAR(40)
) ENGINE = MergeTree PRIMARY KEY ("evt_tx_hash","evt_index");
CREATE TABLE IF NOT EXISTS tellerv2_trusted_market_forwarder_set (
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" UInt64,
    "forwarder" VARCHAR(40),
    "market_id" UInt256,
    "sender" VARCHAR(40)
) ENGINE = MergeTree PRIMARY KEY ("evt_tx_hash","evt_index");
CREATE TABLE IF NOT EXISTS tellerv2_unpaused (
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" UInt64,
    "account" VARCHAR(40)
) ENGINE = MergeTree PRIMARY KEY ("evt_tx_hash","evt_index");
CREATE TABLE IF NOT EXISTS tellerv2_upgraded (
    "evt_tx_hash" VARCHAR(64),
    "evt_index" INT,
    "evt_block_time" TIMESTAMP,
    "evt_block_number" UInt64,
    "implementation" VARCHAR(40)
) ENGINE = MergeTree PRIMARY KEY ("evt_tx_hash","evt_index");

