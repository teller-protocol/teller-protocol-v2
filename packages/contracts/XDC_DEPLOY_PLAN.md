# XDC Chain Deployment Plan

## Context

After successfully deploying to ApeChain, we need to deploy Teller Protocol V2 to **XDC Network** (chain ID 50). This follows the established deployment pattern from BSC and ApeChain. Key decisions: use official Uniswap V3 for DEX/pricing, deploy V2 pools only (not V3 initially), Gnosis Safe is natively supported.

---

## Research Findings

### DEX: Official Uniswap V3 on XDC
Uniswap V3 was officially deployed on XDC via DAO governance (approved Dec 2025). Contract addresses:

| Contract | Address |
|----------|---------|
| **v3CoreFactory** | `0xcb2436774C3e191c85056d248EF4260ce5f27A9D` |
| **SwapRouter02** | `0xaa52bB8110fE38D0d2d2AF0B85C3A3eE622CA455` |
| **QuoterV2** | `0x5911cB3633e764939edc2d92b7e1ad375Bb57649` |
| NonfungiblePositionManager | `0x743E03cceB4af2efA3CC76838f6E8B50B63F184c` |
| TickLens | `0xB3309C48F8407651D918ca3Da4C45DE40109E641` |
| Universal Router | `0x738fD6d10bCc05c230388B4027CAd37f82fe2AF2` |
| Permit2 | `0xB952578f3520EE8Ea45b7914994dcf4702cEe578` |

**Price Adapter**: Use `PriceAdapterUniswapV3` (standard V3, not Algebra)

### Wrapped Native Token
- **WXDC**: `0x951857744785e80e2de051c32ee7b25f9c458c42`

### Gnosis Safe: Natively Supported
- Safe{Wallet} supports XDC at app.safe.global
- TX service URL: `https://safe-transaction-xdc.safe.global` (follows standard pattern)
- EIP3770 chain prefix: `xdc`

### Block Explorer: XDCScan (BlocksScan)
- **apiURL**: `https://api.xdcscan.io/api`
- **browserURL**: `https://xdcscan.io/`
- API key: placeholder `"abc"` works (no key required per docs)

---

## Execution Plan

### Phase 0: Prerequisites ✅ DONE

- [x] Create Gnosis Safe on XDC at app.safe.global
- [x] Set up environment variables (`XDC_RPC_URL`, `XDC_VERIFY_API_KEY`)
- [x] Fund deployer wallet with XDC

---

### Phase 1: Hardhat Config
**File**: `packages/contracts/hardhat.config.ts`

- [ ] Add `'xdc'` to `NetworkNames` type union
- [ ] Add RPC URL: `xdc: process.env.XDC_RPC_URL || 'https://rpc.xdc.org'`
- [ ] Add etherscan API key: `xdc: process.env.XDC_VERIFY_API_KEY || 'abc'`
- [ ] Add custom chain to `etherscan.customChains`:
  ```ts
  { network: 'xdc', chainId: 50, urls: { apiURL: 'https://api.xdcscan.io/api', browserURL: 'https://xdcscan.io/' } }
  ```
- [ ] Add network entry:
  ```ts
  xdc: networkConfig({ url: networkUrls.xdc, chainId: 50, live: true, verify: { etherscan: { apiKey: process.env.XDC_VERIFY_API_KEY || 'abc' } } })
  ```
- [ ] Add `protocolOwnerSafe`: `50: '<XDC_SAFE_ADDRESS>'`
- [ ] Add `protocolTimelock`: `50: '0x...'` (placeholder, backfill after first deploy)

---

### Phase 2: Ecosystem Contracts
**File**: `packages/contracts/helpers/ecosystem-contracts-lookup.ts`

Add `case 'xdc':` entries:
- [ ] `uniswapV3Factory`: `0xcb2436774C3e191c85056d248EF4260ce5f27A9D`
- [ ] `weth9` (WXDC): `0x951857744785e80e2de051c32ee7b25f9c458c42`
- [ ] `uniswapV3SwapRouter`: `0xaa52bB8110fE38D0d2d2AF0B85C3A3eE622CA455`
- [ ] `uniswapV3Quoter`: `0x5911cB3633e764939edc2d92b7e1ad375Bb57649`

---

### Phase 3: Gnosis Safe Helpers
**File**: `packages/contracts/helpers/gnosis-safe-helpers.ts`

- [ ] Add `'xdc': 50` to `getChainId()` (line ~451)
- [ ] Add `'xdc': 'xdc'` to `getNetworkPath()` (line ~529)
- [ ] Add `'xdc': 'https://safe-transaction-xdc.safe.global'` to `getTxServiceHost()` (line ~550)

---

### Phase 4: Deploy Script Network Lists
Add `'xdc'` to network arrays in these deploy scripts:

**Core (required):**
- [ ] `deploy/smart_commitment_forwarder/deploy.ts`
- [ ] `deploy/teller_v2/protocol_pausing_manager.ts`
- [ ] `deploy/lender_commitment_forwarder/deploy_alpha.ts`
- [ ] `deploy/lender_commitment_forwarder/extensions/lender_groups_v2/lender_groups_factory_v2.ts`
- [ ] `deploy/lender_commitment_forwarder/extensions/lender_groups_v2/lender_commitment_group_v2_beacon.ts`
- [ ] `deploy/oracle/mock_hypernative_oracle.ts`

**Pricing (Uniswap V3):**
- [ ] `deploy/lender_commitment_forwarder/uniswap_pricing_libraryV2.ts`
- [ ] Add `'xdc'` to `PriceAdapterUniswapV3` deploy script (deploy/pricing/)

**NOT deploying V3 pools initially** — skip lender_groups_v3 scripts.

---

### Phase 5: Deploy Contracts (Two-Pass)

```bash
# FIRST PASS - deploys all contracts
yarn contracts deploy --network xdc

# After first pass:
# 1. Open deployments/xdc/TimelockController.json → copy address
# 2. Update protocolTimelock[50] in hardhat.config.ts

# SECOND PASS - completes ownership transfers
yarn contracts deploy --network xdc
```

---

### Phase 6: Verify Contracts

```bash
yarn contracts verify --network xdc
```

---

### Phase 7: Create XDC-Specific Ownership Transfer Script
**File**: `deploy/upgrades/XX_transfer_xdc_ownership.ts` (following pattern of `37_transfer_apechain_ownership.ts`)

- [ ] Transfer SmartCommitmentForwarder to Safe
- [ ] Transfer LenderCommitmentGroupFactory_V2 to Safe
- [ ] Transfer CollateralManager to Safe

---

### Phase 8: Subgraph Config
**File**: `packages/subgraph/config/xdc.json` (new file)

- [ ] Create config with deployed contract addresses and start blocks
- [ ] Follow pattern from `apechain.json`

---

### Phase 9: Post-Deployment Validation

- [ ] TellerV2 owned by `protocolOwnerSafe`
- [ ] ProxyAdmin owned by `protocolTimelock`
- [ ] Beacons owned by `protocolTimelock`
- [ ] SmartCommitmentForwarder owned by `protocolOwnerSafe`
- [ ] Test Safe can propose/execute transactions on XDC

---

## Key Files to Modify

| File | Changes |
|------|---------|
| `packages/contracts/hardhat.config.ts` | Network, etherscan, named accounts |
| `packages/contracts/helpers/ecosystem-contracts-lookup.ts` | Uniswap V3 + WXDC addresses |
| `packages/contracts/helpers/gnosis-safe-helpers.ts` | Chain ID, network path, TX service |
| `packages/contracts/deploy/` (6-8 scripts) | Add 'xdc' to network lists |
| `packages/contracts/deploy/upgrades/XX_transfer_xdc_ownership.ts` | New ownership transfer script |
| `packages/subgraph/config/xdc.json` | New subgraph config |
