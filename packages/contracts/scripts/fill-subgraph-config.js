#!/usr/bin/env node
/**
 * Fill the subgraph configs for a network from its hardhat-deploy artifacts.
 *
 *   node scripts/fill-subgraph-config.js robinhood
 *
 * Reads deployments/<network>/ and rewrites the PLACEHOLDER addresses and start
 * blocks in packages/subgraph/config/<network>.json and
 * packages/subgraph-pool-v2/config/<network>.json in place.
 *
 * This exists so deployed addresses are never copied by hand. A subgraph that
 * indexes the wrong address looks healthy and returns nothing, which is a slow
 * and confusing failure; and a start block of 0 on a fast chain costs days of
 * backfill.
 */

const fs = require('fs')
const path = require('path')

const network = process.argv[2]
if (!network) {
  console.error('usage: node scripts/fill-subgraph-config.js <network>')
  process.exit(1)
}

const deploymentsDir = path.resolve(__dirname, '..', 'deployments', network)
if (!fs.existsSync(deploymentsDir)) {
  console.error(`No deployments found at ${deploymentsDir}. Deploy first.`)
  process.exit(1)
}

const addressOf = (contract) => {
  const file = path.join(deploymentsDir, `${contract}.json`)
  if (!fs.existsSync(file)) return undefined
  return JSON.parse(fs.readFileSync(file, 'utf-8')).address
}

const blockFile = path.join(deploymentsDir, '.latestDeploymentBlock')
if (!fs.existsSync(blockFile)) {
  console.error(`Missing ${blockFile} — cannot determine the start block.`)
  process.exit(1)
}
const deployBlock = fs.readFileSync(blockFile, 'utf-8').trim()
if (!/^\d+$/.test(deployBlock) || deployBlock === '0') {
  console.error(`Refusing to use start block "${deployBlock}".`)
  process.exit(1)
}

// placeholder -> deployment artifact name
const SUBSTITUTIONS = {
  TELLER_V2_ADDRESS: 'TellerV2',
  MARKET_REGISTRY_ADDRESS: 'MarketRegistry',
  LENDER_COMMITMENT_FORWARDER_ALPHA_ADDRESS: 'LenderCommitmentForwarderAlpha',
  COLLATERAL_MANAGER_ADDRESS: 'CollateralManager',
  LENDER_MANAGER_ADDRESS: 'LenderManager',
  MARKET_LIQUIDITY_REWARDS_ADDRESS: 'MarketLiquidityRewards',
  LENDER_COMMITMENT_GROUP_FACTORY_V2_ADDRESS: 'LenderCommitmentGroupFactory_V2',
}

const targets = [
  path.resolve(__dirname, '..', '..', 'subgraph', 'config', `${network}.json`),
  path.resolve(
    __dirname,
    '..',
    '..',
    'subgraph-pool-v2',
    'config',
    `${network}.json`
  ),
]

let missing = []

for (const target of targets) {
  if (!fs.existsSync(target)) {
    console.log(`skip (no config): ${target}`)
    continue
  }
  let raw = fs.readFileSync(target, 'utf-8')

  for (const [placeholder, contract] of Object.entries(SUBSTITUTIONS)) {
    if (!raw.includes(placeholder)) continue
    const address = addressOf(contract)
    if (!address) {
      missing.push(`${contract} (for ${placeholder} in ${path.basename(target)})`)
      continue
    }
    raw = raw.split(placeholder).join(address)
  }

  raw = raw.split('DEPLOY_BLOCK').join(deployBlock)

  fs.writeFileSync(target, raw, 'utf-8')
  console.log(`wrote ${target}`)
}

console.log(`\nstart block: ${deployBlock}`)

if (missing.length) {
  console.error('\nMissing deployment artifacts:')
  for (const m of missing) console.error(`  - ${m}`)
  console.error('\nConfigs still contain placeholders. Do not deploy them.')
  process.exit(1)
}

console.log('All placeholders resolved.')
