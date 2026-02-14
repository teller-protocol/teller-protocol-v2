# New Network Deployment Plan (BSC / Binance Smart Chain)

Step-by-step guide for deploying Teller Protocol V2 to a new EVM chain.
Uses BSC (chain ID 56) as the concrete example.

---

## Phase 0: Prerequisites & Environment Setup

### 0.1 — Hardhat Config
- [x] Add network to `NetworkNames` type
- [x] Add RPC URL to `networkUrls`
- [x] Add network to `etherscan.apiKey`
- [x] Add network to `etherscan.customChains`
- [x] Add network entry to `networks` section

### 0.2 — Environment Variables
Add to `.env`:
```
BSC_RPC_URL=https://bsc-dataseed1.binance.org
BSCSCAN_VERIFY_API_KEY=<your key from bscscan.com>
```

### 0.3 — Fund Deployer Wallet
- Run `yarn contracts account` to get the deployer address
- Send BNB to the deployer on BSC (estimate ~0.5 BNB for full deployment)

---

## Phase 1: Create Gnosis Safe Multisig

This must happen **before** contract deployment since deploy scripts reference the Safe address.

### 1.1 — Create the Safe
1. Go to https://app.safe.global
2. Switch to **BNB Chain**
3. Create a new Safe with the desired signers and threshold
4. Record the Safe address

### 1.2 — Add Safe address to hardhat config
In `hardhat.config.ts` under `namedAccounts`:
```ts
protocolOwnerSafe: {
  // ... existing entries
  56: '<BSC_SAFE_ADDRESS>',
},
```

### 1.3 — Gnosis Safe helpers
Already configured in `helpers/gnosis-safe-helpers.ts`:
- Chain ID mapping: `'bsc': 56`
- Safe API path: `'bsc': 'bnb'`
- TX service host: `'bsc': 'https://safe-transaction-bsc.safe.global'`

No changes needed here.

---

## Phase 2: Core Contract Deployment

Run with: `yarn contracts deploy --network bsc`

Deployment scripts execute automatically in dependency order via `hardhat-deploy`.
Below is the order and what each phase deploys.

### 2.1 — Foundation (no dependencies)
| Contract | Deploy Script | Notes |
|---|---|---|
| EscrowVault | `deploy/escrow_vault.ts` | Proxy |
| CollateralEscrowBeacon | `deploy/collateral/escrow_beacon.ts` | Transfers ownership to protocolTimelock |
| MarketRegistry | `deploy/market_registry.ts` | Also deploys TellerAS* contracts |
| MetaForwarder | `deploy/meta_forwarder.ts` | EIP-2771 trusted forwarder |

### 2.2 — TellerV2 Core
| Contract | Deploy Script | Dependencies |
|---|---|---|
| V2Calculations | `deploy/teller_v2/v2_calculations.ts` | — |
| TellerV2 | `deploy/teller_v2/deploy.ts` | MetaForwarder, V2Calculations |

### 2.3 — Secondary Contracts
| Contract | Deploy Script | Dependencies |
|---|---|---|
| CollateralManager | `deploy/collateral/manager.ts` | TellerV2, EscrowBeacon |
| LenderManager | `deploy/lender_manager/deploy.ts` | MarketRegistry |
| ReputationManager | `deploy/reputation_manager.ts` | TellerV2 |
| ProtocolPausingManager | `deploy/teller_v2/protocol_pausing_manager.ts` | TellerV2 |

### 2.4 — TellerV2 Initialization
| Step | Deploy Script | What it does |
|---|---|---|
| Initialize | `deploy/teller_v2/initialize.ts` | Wires all contracts together (fee, registry, collateral mgr, etc.) |

### 2.5 — Commitment Infrastructure
| Contract | Deploy Script | Dependencies |
|---|---|---|
| LenderCommitmentForwarderAlpha | `deploy/lender_commitment_forwarder/deploy_alpha.ts` | TellerV2, MarketRegistry |
| SmartCommitmentForwarder | `deploy/smart_commitment_forwarder/deploy.ts` | TellerV2, MarketRegistry |

### 2.6 — Lender Groups (V2)
| Contract | Deploy Script | Dependencies |
|---|---|---|
| LenderGroupBeaconV2 | `deploy/.../lender_commitment_group_v2_beacon.ts` | TellerV2, SmartCommitmentForwarder |
| LenderGroupsFactoryV2 | `deploy/.../lender_groups_factory_v2.ts` | Beacon, SmartCommitmentForwarder |

### 2.7 — Post-Deploy Ownership Transfer
| Step | Deploy Script | What it does |
|---|---|---|
| Transfer ProxyAdmin | `deploy/default_proxy_admin.ts` | Transfers ProxyAdmin ownership to `protocolTimelock` |
| Transfer TellerV2 | `deploy/teller_v2/transfer_ownership_to_safe.ts` | Transfers TellerV2 ownership to `protocolOwnerSafe` |

---

## Phase 3: Deploy TimelockController

> **IMPORTANT — This is a two-pass process.**
> The TimelockController deploys during the first `yarn contracts deploy` run,
> but several other scripts (ProxyAdmin transfer, beacon ownership transfers)
> need the timelock address in `namedAccounts.protocolTimelock` to work.
> You must pause after the first run, backfill the address, then re-run.

### 3.1 — How the Timelock deploys
The script `deploy/admin/timelock_controller.ts` runs automatically as part of
`yarn contracts deploy --network bsc`. It deploys an OpenZeppelin `TimelockController` with:
- **minDelay**: 180 seconds (3 minutes)
- **proposers**: `[protocolOwnerSafe]` (your Gnosis Safe)
- **executors**: `[protocolOwnerSafe]`
- **admin**: `protocolOwnerSafe`

This means **only your Safe can propose and execute timelocked operations**.

### 3.2 — After the first deploy run
1. The timelock address will be saved in `deployments/bsc/TimelockController.json`
2. Open that file and copy the `"address"` field
3. Add it to `hardhat.config.ts`:
```ts
protocolTimelock: {
  // ... existing entries
  56: '<ADDRESS_FROM_STEP_2>',
},
```

### 3.3 — Re-run deploy to complete ownership transfers
```bash
yarn contracts deploy --network bsc
```
On this second run, `hardhat-deploy` skips already-deployed contracts (idempotent)
and picks up the scripts that previously failed or were skipped due to the missing
timelock address. These scripts transfer ownership to the timelock:
- `deploy/default_proxy_admin.ts` — transfers **ProxyAdmin** ownership to timelock
- `deploy/collateral/escrow_beacon.ts` — transfers **CollateralEscrowBeacon** ownership to timelock
- `deploy/.../lender_commitment_group_v2_beacon.ts` — transfers **LenderGroupBeaconV2** ownership to timelock

### 3.4 — Verify ownership transfers
After the second run, confirm on BscScan that:
- ProxyAdmin `owner()` → timelock address
- CollateralEscrowBeacon `owner()` → timelock address
- LenderGroupBeaconV2 `owner()` → timelock address

---

## Phase 4: Ecosystem Contract Addresses

These are chain-specific external contract addresses required for DeFi integrations.

### 4.1 — `helpers/ecosystem-contracts-lookup.ts`
Add a `case 'bsc':` block with:

| Contract | BSC Address | Notes |
|---|---|---|
| WETH9 (WBNB) | `0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c` | Wrapped native token |
| Uniswap V3 Factory | Use PancakeSwap V3 factory address | PancakeSwap is the dominant V3 DEX on BSC |
| Swap Router | PancakeSwap V3 SwapRouter | |
| Quoter V2 | PancakeSwap V3 QuoterV2 | |

**PancakeSwap V3 Addresses (BSC):**
- Factory: `0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865`
- SwapRouter: `0x1b81D678ffb9C0263b24A97847620C99d213eB14`
- QuoterV2: `0xB048Bbc1Ee6b733FFfCFb9e9CeF7375518e25997`

### 4.2 — Deploy Script Addresses
Update the following deploy scripts with BSC entries:

**Aave V3 Pool Address Provider** (for flash loan support):
- `deploy/upgrades/03_flash_rollover_g3.ts`
- `deploy/upgrades/09_flash_rollover_g4.ts`
- `deploy/upgrades/11_upgrade_rollover_g5.ts`

BSC Aave V3 Pool Address Provider: `0xff75B6da14FfbbfD355Daf7a2731456b3562Ba6D`

**DEX Router / Quoter** (for swap functionality):
- `deploy/lender_commitment_forwarder/extensions/borrow_swap.ts`
- `deploy/lender_commitment_forwarder/extensions/flash_swap_rollover.ts`
- `deploy/lender_commitment_forwarder/uniswap_pricing_libraryV2.ts`

---

## Phase 5: Update Deploy Script Network Lists

Most deploy scripts have a skip check like:
```ts
deployFn.skip = async (hre) => {
  return !hre.network.live || !['polygon', 'mainnet', 'arbitrum', ...].includes(hre.network.name)
}
```

Add `'bsc'` to the network arrays in these files:

### Core Deploys
- [ ] `deploy/proxy/deploy.ts`
- [ ] `deploy/smart_commitment_forwarder/deploy.ts`
- [ ] `deploy/teller_v2/protocol_pausing_manager.ts`
- [ ] `deploy/lender_commitment_forwarder/deploy_alpha.ts`
- [ ] `deploy/lender_commitment_forwarder/uniswap_pricing_libraryV2.ts`
- [ ] `deploy/lender_commitment_forwarder/extensions/lender_groups_v2/lender_groups_factory_v2.ts`
- [ ] `deploy/lender_commitment_forwarder/extensions/lender_groups_v2/lender_commitment_group_v2_beacon.ts`
- [ ] `deploy/oracle/mock_hypernative_oracle.ts`

### Extensions (if deploying flash loans / swaps on BSC)
- [ ] `deploy/lender_commitment_forwarder/extensions/borrow_swap.ts`
- [ ] `deploy/lender_commitment_forwarder/extensions/flash_rollover.ts`
- [ ] `deploy/lender_commitment_forwarder/extensions/flash_rollover_widget.ts`
- [ ] `deploy/lender_commitment_forwarder/extensions/flash_swap_rollover.ts`
- [ ] `deploy/lender_commitment_forwarder/extensions/loan_referral_forwarder.ts`

### Upgrade Scripts (for future upgrades)
- [ ] `deploy/upgrades/22_upgrade_tellerv2_lender_groups.ts`
- [ ] `deploy/upgrades/26_upgrade_scf_oracle_protection.ts`
- [ ] `deploy/upgrades/30_upgrade_lender_groups_beacon_v2_first_deposit.ts`
- [ ] `deploy/upgrades/31_upgrade_lender_groups_pricing_helper.ts`
- [ ] `deploy/upgrades/34_update_timelock_delay.ts`
- [ ] `deploy/upgrades/35_upgrade_lender_pools_v1.ts`

---

## Phase 6: Verify Contracts

After deployment, verify all contracts on BscScan:
```bash
yarn contracts verify --network bsc
```

Requires `BSCSCAN_VERIFY_API_KEY` in `.env`.
Get an API key from https://bscscan.com/myapikey.

---

## Phase 7: Post-Deployment Validation

### 7.1 — Run the validation script
```bash
yarn contracts deploy --network bsc --tags validate-deployments
```

This checks:
- SmartCommitmentForwarder owner
- LenderGroupsFactory owner
- LenderGroupsBeacon owner
- TellerV2 owner
- EscrowVault configuration
- PausingManager configuration

### 7.2 — Manual Checks
- [ ] TellerV2 is initialized (marketRegistry, collateralManager, etc. all set)
- [ ] ProxyAdmin owned by `protocolTimelock`
- [ ] TellerV2 owned by `protocolOwnerSafe`
- [ ] SmartCommitmentForwarder owned by `protocolOwnerSafe`
- [ ] CollateralEscrowBeacon owned by `protocolTimelock`
- [ ] Safe can propose and execute transactions via the Safe TX service

---

## Execution Order Summary

```
1.  Fund deployer wallet with BNB
2.  Create Gnosis Safe on BSC → get address
3.  Add Safe address to hardhat config (protocolOwnerSafe[56])
4.  Add ecosystem addresses to ecosystem-contracts-lookup.ts
5.  Add 'bsc' to all deploy script network lists
6.  Run: yarn contracts deploy --network bsc          ← FIRST PASS
7.  Open deployments/bsc/TimelockController.json → copy the address
8.  Add timelock address to hardhat config (protocolTimelock[56])
9.  Run: yarn contracts deploy --network bsc          ← SECOND PASS
       (completes ownership transfers to timelock)
10. Verify contracts on BscScan
11. Run validation script
12. Manual smoke test via Safe
```

---

## Rollback

If deployment fails partway through:
- `hardhat-deploy` is idempotent — re-running `yarn contracts deploy --network bsc` will skip already-deployed contracts
- Deployment artifacts are saved in `deployments/bsc/`
- To redeploy a specific contract, delete its JSON from `deployments/bsc/` and re-run
