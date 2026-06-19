# Audit Report Addendum — Teller Protocol v2

**Date:** 2026-06-16
**Re:** `2026-06-10` v2 Security Audit (Bad & Dangerous Patterns)
**Repo state:** commit `49c0be13`
**Process:** Each finding re-verified against live source and walked with the protocol team. Verdicts reflect code-level verification + the team's deployment, trust, and risk-acceptance decisions.

---

## Verdicts

### C-1 🔴 — TWAP `twapInterval == 0 → slot0()` spot fallback · KNOWN / RISK-ACCEPTED (team)
**Code confirmed real:** the `twapInterval == 0` → `slot0()` spot fallback exists in all 5 cited sites (`UniswapPricingLibrary:105`, `UniswapPricingLibraryV2:133`, `UniswapPricingHelper:133`, `PriceAdapterUniswapV3:162`, `PriceAdapterAlgebra:123`), and `MIN_TWAP_INTERVAL = 3` is declared in the 3 pool contracts and referenced nowhere (dead).

**Team disposition:** Not treated as a bug to fix. Live pools are configured with a non-zero `twapInterval`; a `twapInterval == 0` configuration is a publicly observable, well-understood risky setting that pool operators are expected never to use. The team accepts this as a configuration responsibility rather than a code defect.

*Auditor note (recorded for completeness, not a reopen):* the spot fallback + unused `MIN_TWAP_INTERVAL` remain in code, so the safety depends entirely on deployment discipline rather than an in-contract floor. If pool deployment is ever publicly permissionless (see C-3), an attacker-deployed pool with `twapInterval == 0` would not be protected by the team's own configuration discipline. Filed per team decision as known/accepted.

### C-2 🔴 — V2 / V4 / Aerodrome adapters spot/broken · SPLIT
- **UniswapV2 adapter** — **NOT USED** (team-confirmed): not wired to any live route. Both branches return spot reserves regardless of `twapInterval`. Dormant/unused; do not deploy as-is. No action while unused.
- **Aerodrome adapter** — **REAL bug, fix planned.** Two confirmed correctness defects in the live TWAP branch: (1) divides cumulative-reserve delta by `latestObservationTick` (observation count−1) instead of `timeElapsed` — `timeElapsed` is computed, `require`d, then unused (author comment `// divisor isnt exactly right ?`); (2) indexes the observation ring buffer by a seconds value (`latestObservationTick - twapInterval`) → underflow/revert for typical intervals, or reads the wrong slot. Cannot produce a correct TWAP — reverts or misprices collateral. **Team to plan a fix.**
- **UniswapV4 adapter** — OPEN: TWAP branch is unimplemented (reverts), so a live V4 route can only run with `twapInterval == 0` = pure spot. *Needs confirmation whether V4 is used with `twapInterval == 0`; if so it is effectively spot-priced (same risk class as C-1, but with no non-spot option).*

### C-3 🔴 — Permissionless pool factory + unvalidated routes · BY DESIGN, accepted
Confirmed: `deployLenderCommitmentGroupPool` (all 3 factory versions) has no access control and forwards `_priceAdapterAddress`/`_priceAdapterRoute` into the pool initializer without validation; ownership goes to `msg.sender`. **Team disposition: intentional, documented permissionless design (anyone can create a pool; depositor-beware).** Not a bug. Caveat (recorded, not a reopen): safe only as long as nothing on-chain or in the UI auto-trusts every `deployedLenderGroupContracts` entry as canonical.

### H-1 🟠→🟡 — Rollover reward subtraction underflows · REAL, DOWNGRADED to Medium/Low (self-inflicted)
Confirmed: `fundsRemaining -= rewardAmount` (FlashRolloverLoan_G6/G7/G8) underflows and reverts when `rewardAmount > fundsRemaining`. The only bound (`_rewardAmount <= _flashLoanAmount/10`) is unrelated to the surplus. **Downgraded** because the borrower is `msg.sender`, sets their own `rewardAmount`/`rewardRecipient`, and the reward is paid from their own surplus — so an over-large reward only reverts the borrower's own tx (no third-party harm, no fund loss). The audit's "any reward configured cannot complete" is overstated (only when reward > surplus).

**Recommended fix (UX improvement):** clamp the reward to the available surplus instead of reverting, so a borrower who requests a generous reward simply receives the capped amount and the rollover still succeeds:
```solidity
uint256 reward = _rolloverArgs.rewardAmount > fundsRemaining
    ? fundsRemaining
    : _rolloverArgs.rewardAmount;
if (reward > 0) {
    fundsRemaining -= reward;
    IERC20Upgradeable(_flashToken).safeTransfer(_rolloverArgs.rewardRecipient, reward);
}
```
This turns a hard revert (bad UX — the borrower must guess a reward ≤ surplus and retry) into a graceful cap. Pair with SafeERC20 (see H-2).

### H-2 🟠→🟡 — Raw ERC20 calls without SafeERC20 · REAL, Medium (token vetting in place)
Confirmed: `CollateralManager` doesn't import SafeERC20 (raw `transferFrom`/`approve` in `_deposit`); `MarketLiquidityRewards` uses raw `transferFrom`/`transfer` (lines 103/159/188/317). Real ADR-0005 violation. Exploitability limited: USDT-style (no-return) tokens **revert** on these raw calls (no silent loss); only `false`-returning tokens silently succeed (phantom-collateral path), and the team's **token vetting** excludes those. **Disposition: real, Medium.** Recommended mechanical fix: `safeTransferFrom`/`forceApprove` (+ measured delta, shared with H-3) — removes the phantom-collateral path entirely for a permissionless protocol.

### H-3 🟠→🟡 — Collateral deposit credits requested amount not delta · REAL, Medium/Low (triple-mitigated)
Confirmed accounting records requested `_amount`. Mitigated by: (1) escrow side already uses `SafeERC20Upgradeable.safeTransferFrom`; (2) two-hop full-`_amount` transfer (borrower→CollateralManager→escrow) tends to **revert** on fee-on-transfer rather than over-credit, since CM is short by the fee; (3) team policy of never using fee-on-transfer collateral. **Disposition: real, Medium/Low.** Fix folds into H-2 (measure delta in `CollateralManager`, mirror `EscrowVault`).

### H-4 🟠→🟡 — Never-reset approvals in rollover contracts · Low/Medium (hygiene)
Confirmed raw `approve` to TellerV2/Aave (G8 imports SafeERC20 but uses raw `IERC20Upgradeable.approve`). Standing allowances are to *trusted* protocol contracts that pull from `msg.sender`; contracts are deployed and **empty-at-rest** (team-confirmed) → no third-party exfil primitive. The one genuine consequence is USDT-compat: a leftover non-zero allowance makes the next raw `approve` revert (non-zero→non-zero). **Disposition: Low/Medium hygiene.** Fix: `forceApprove` + reset-to-0.

### H-5 🟠 — No cardinality/liquidity/bounds on TWAP reads · RECOMMENDED HARDENING (vetted pools)
Confirmed: V3/Algebra TWAP reads call `observe()`/`getTimepoints()` with no cardinality assert, liquidity floor, or sanity bounds (none exist in the pricing layer). For attacker/third-party pools this is covered by the accepted C-3 "permissionless, depositor-beware" model. **For the team's own canonical/vetted pools: recommended hardening** — assert observation cardinality covers `twapInterval` (avoids a liveness revert on young pools) and enforce a minimum-liquidity floor to protect the team's depositors.

### H-6 🟠→🔵 — Permissionless `registerPriceRoute` · LOW / NON-ISSUE
Routes are **content-addressed** (`priceRoutes[keccak256(route)] = route`), so registration cannot overwrite/hijack any existing route, and a pool only ever consumes the specific route hash it was initialized with. A "malicious" registered route is inert unless a pool opts into its hash (the already-accepted C-3 surface). Only real effect: attacker-funded storage growth. Low/informational.

### H-7 🟠 — First-depositor / share-inflation floor too weak · FALSE POSITIVE on merits
The audit missed two structural defenses: (1) **valuation uses internal accounting, not `balanceOf`** — `getPoolTotalEstimatedValue()` sums tracked principal/interest/liquidation deltas, so a direct token **donation cannot move the share rate** (the engine of the inflation attack); (2) **first deposit is owner-only and must clear the floor in one tx** (`require(msg.sender == owner(), "FD")` + `require(poolIsActivated(), "IS")`) — an attacker can't be the first depositor in another's pool. Deposits also assert measured delta (`"TB"`), rejecting fee-on-transfer principal. The weak `1e6` share floor is therefore **moot** — it isn't the control preventing the skim. No action.

### H-8 🟠→🔵 — `LoanReferralForwarder` raw transfer + commented-out min-received · LOW
Confirmed: raw `transfer` (V1) and commented-out `_minAmountReceived`. But this path has **no swap** — it accepts a commitment and forwards deterministic principal, so the missing min-received is a sanity bound, not slippage protection. Raw transfer mitigated by token vetting and **already fixed in V2** (`TransferHelper.safeTransfer`). Low.

---

## Medium findings

### M-1 🟡→ℹ️ — Untrusted call target · INFO / BY DESIGN
Forwarder calls a user-supplied smart-commitment address — intentional plugin/extensibility pattern, bounded by `nonReentrant` + oracle gating + downstream TellerV2 accounting. Document the trust assumption. No code change.

### M-2 🟡 — Missing `__gap` (esp. `ProtocolFee`, a TellerV2 base) · OUT OF SCOPE
Confirmed real upgrade-safety hazard (appending state to `ProtocolFee` would shift `TellerV2` storage). Team disposition: nothing actionable now, out of scope. (If TellerV2 is ever upgraded with new base-state, address first — add `__gap` or migrate `_protocolFee` into the `_Gn` chain.)

### M-3 🟡→🔵 — `TellerV2Autopay` raw `approve` + requested amount · LOW (token vetting)
Same class as H-2/H-3; token vetting covers it. Fold into the SafeERC20 cleanup.

### M-4 🟡 — Withdraw-delay bypass · MEDIUM (known, fix planned)
**Confirmed:** `_afterTokenTransfer` stamps only `from`, never `to`, so deposit→transfer-to-fresh-account→immediate-withdraw bypasses the anti-sandwich delay. Team already aware. **Fix planned:** stamp `to` in `_afterTokenTransfer` (received shares carry their own delay).

### M-5 🟡→ℹ️ — `transferMarketOwnership(_, address(0))` bricks a market · INFO
Confirmed no zero-check. Owner-only, self-inflicted footgun. Doesn't matter in practice. (Optional cheap zero-check.)

### M-6 🟡→🔵 — Reward-claim raw transfer + no `nonReentrant` · LOW/INFO
CEI is correct (per-(bid,allocation) flag set before transfer); cross-allocation reentrancy only enables legitimate bounded claims; reward tokens vetted. No live theft. **Recommended hardening: add `nonReentrant` + SafeERC20.**

### M-7 🟡 — `uint160` overflow in V2/Aerodrome reserve math · FOLD INTO C-2
V2 unused; Aerodrome overflow compounds the C-2 correctness bug. Addressed by the planned C-2 Aerodrome fix.

### M-8 🟡 — Single pauser can pause AND unpause · NOT AN ISSUE
Pausers are owner-appointed and trusted; combined pause/unpause authority is acceptable by design. No action.

### M-9 🟡 — `tx.origin` + fail-open in `OracleProtectionManager` · INTENTIONAL BY DESIGN
`tx.origin` used for Hypernative blacklist-origin identification + EOA-gating (not classic auth-bypass); fail-open when oracle unset is intentional (Hypernative is a defense-in-depth monitoring layer; protocol must not brick if unset). No action.

### M-10 🟡→ℹ️ — `BorrowSwap.amountOutMinimum` `uint160` / "can be 0" · INFO (accepted)
Slippage protection is the **caller's responsibility** to set; accepted as Info. (Minor latent note: `uint160` type could truncate implausibly large values; practically irrelevant at realistic token magnitudes.)

---

## Low / Informational

### L — `LenderCommitmentForwarder_G1` ineffective max-principal guard · DORMANT (G1 retired)
Confirmed: G1's `commitmentPrincipalAccepted[bidId] <= commitment.maxPrincipal` reads `bidId` before assignment (slot 0), so the cap is ineffective. **G1 is no longer used** (team-confirmed); fixed in later generations. Dormant — no action.

### I-1 — `_disableInitializers()` missing on most implementations · INFO
Confirmed: only the LCF leaf wrappers call it; `TellerV2`, `CollateralManager`, `EscrowVault`, and others do not. Impact low (proxies hold real state; none chain to `delegatecall`/`selfdestruct`). Filed as **Info** — cheap one-line constructor add recommended opportunistically.

### All remaining Low/Info items · INFO (accepted)
Blanket disposition: filed as Informational / accepted, address opportunistically.
- `require("string")` + cryptic short codes (ADR-0004); migrate per boy-scout rule.
- Missing zero-address checks on some setters/initializers.
- Approvals to escrow not reset (`setApprovalForAll(escrow, true)`); escrow trusted.
- Minor CEI deviations (`CollateralEscrowV1._withdrawCollateral`, `TellerAS._attest`) — trusted-caller guarded.
- Rollover no `nonReentrant` on flash callbacks — bounded by `msg.sender == pool` + `initiator == address(this)`; recommend `nonReentrant` + zero approvals as hardening.
- EAS verifier: `immutable DOMAIN_SEPARATOR` (chain-fork replay) + no attestation deadline.
- `MetaForwarder`: no meta-tx deadline.
- `V2Calculations.calculateAmountOwed`: underflow-revert DoS (not loss) for deeply delinquent loans.
- Dead code / misleading `*Upgradeable` + `oz-upgrades-unsafe-allow` tags on non-upgradeable rollover contracts — clean up to avoid an unsafe proxy deployment.
- `LenderCommitmentForwarder_U1` TWAP `twapInterval == 0 → slot0()` — covered by C-1.

---

## Disposition summary (v2)

| Finding | Audit sev | Verdict |
|---|---|---|
| C-1 TWAP spot fallback | Critical | Known / risk-accepted (config discipline) |
| C-2 V2 adapter | Critical | Not used (dormant) |
| C-2 Aerodrome | Critical | **REAL — fix planned** |
| C-2 V4 | Critical | OPEN — confirm if used with `twapInterval==0` |
| C-3 permissionless factory | Critical | By design, accepted |
| H-1 rollover reward underflow | High | Real → **Medium/Low**, clamp fix recommended |
| H-2 raw ERC20 | High | Real → **Medium** (token vetting); SafeERC20 fix |
| H-3 deposit credits requested amt | High | Real → **Medium/Low** (triple-mitigated) |
| H-4 never-reset approvals | High | **Low/Medium** hygiene; `forceApprove` |
| H-5 no TWAP cardinality/liquidity | High | Recommended hardening (vetted pools) |
| H-6 permissionless registerPriceRoute | High | **Low/non-issue** (content-addressed) |
| H-7 first-depositor floor | High | **False positive** (internal accounting + owner-only first deposit) |
| H-8 referral raw transfer / min-received | High | **Low** (no swap; V2 already fixed) |
| M-1 untrusted target | Med | Info / by design |
| M-2 missing `__gap` | Med | Out of scope (TellerV2 upgrade hazard) |
| M-3 Autopay raw approve | Med | Low (token vetting) |
| M-4 withdraw-delay bypass | Med | **Medium — known, fix planned** |
| M-5 market-brick zero owner | Med | Info |
| M-6 reward-claim reentrancy | Med | Low/info; recommend `nonReentrant` |
| M-7 uint160 overflow | Med | Fold into C-2 |
| M-8 single pauser | Med | Not an issue |
| M-9 tx.origin / fail-open | Med | Intentional by design |
| M-10 swap `amountOutMinimum` | Med | Info (caller responsibility) |
| L-G1 ineffective guard | Low | Dormant (G1 retired) |
| I-1 `_disableInitializers` | Info | Info |
| All other L | Low | Info |

**Net action items:** (1) **C-2 Aerodrome** correctness fix [planned]; (2) **M-4** withdraw-delay recipient stamp [planned]; (3) confirm **C-2 V4** usage; recommended hardening: H-1 reward clamp, H-2/H-3/M-3 SafeERC20+measured-delta cleanup, H-4 `forceApprove`, H-5 cardinality/liquidity on vetted pools, M-6 `nonReentrant`.

---

*Verdicts reflect verification against commit `49c0be13` plus the team's deployment, trust (token vetting, trusted pausers/owner), and design (permissionless pools, defense-in-depth oracle) model. "Real but downgraded" and "fix planned" items are genuine defects; "false positive / non-issue" items were refuted on the merits.*
