# Base: LenderCommitmentGroup_Pool_V2 — raise MAX_WITHDRAW_DELAY_TIME to 30 days

Replacement implementation for the Base V2 pool beacon. The **only** source change
from the currently deployed implementation is:

```diff
-    uint256 immutable public MAX_WITHDRAW_DELAY_TIME = 86400;
+    uint256 immutable public MAX_WITHDRAW_DELAY_TIME = 2592000;
```

## Provenance

| | |
|---|---|
| Current implementation (Base) | `0xd177f4b8e348B4C56c2aC8E03b58E41b79351a7f` |
| V2 beacon | `0x7848585b707F54CcF7044F8C82CF53F43100dc83` (owner `0x6BBf498C429C51d05bcA3fC67D2C720B15FC73B8`) |
| Source commit | `e30dbeb516727ff78b68ce4ac989025176ee1b39` (the full dependency tree is in `standard-json-input.json`) |
| Compiler | solc `v0.8.11+commit.d7f03943`, optimizer on, 200 runs, default EVM version |

Why we think `e30dbeb5` is the deployed source:
- Its ABI matches the verified ABI of `0xd177…` function for function (94 functions, no `setWithdrawDelayBypassForAccount`).
- Compiled with these settings, its runtime code is 24,574 bytes, the same size as `0xd177…` on chain.

This modified build has the same 24,574-byte runtime. Its creation bytecode differs from
the unmodified build in two places only:
- the constant pushed in the constructor (`0x015180` → `0x278d00`)
- the CBOR metadata hash

## Constructor args (copied from the current implementation)

| Arg | Address |
|---|---|
| `_tellerV2` | `0x5cfD3aeD08a444Be32839bD911Ebecd688861164` |
| `_smartCommitmentForwarder` | `0x0708480670BdE591e275B06Cd19EcaDFC93A1f16` |
| `_uniswapV3Factory` | `0x33128a8fC17869897dcE68Ed026d694621f6FDfD` |
| `_uniswapPricingHelper` | `0xAd0fD5947877382E493e17Fb37303D94c4A1deEF` |

## Files

- `LenderCommitmentGroup_Pool_V2.sol`: the modified contract source.
- `LenderCommitmentGroup_Pool_V2.json`: ABI, creation `bytecode` and `deployedBytecode`.
- `deploy-tx-data.txt`: the full `data` for the contract-creation transaction (creation bytecode + ABI-encoded constructor args). Send it with no `to` address.
- `constructor-args.txt`: the ABI-encoded constructor args, for Basescan verification.
- `standard-json-input.json`: solc standard JSON input, for Basescan verification ("Standard-Json-Input", compiler v0.8.11+commit.d7f03943).

## Steps

1. **Deploy the new implementation.** Any EOA can send `deploy-tx-data.txt` as a contract creation. Call the resulting address `NEW_IMPL`.
2. **Point the beacon at it.** From the beacon owner `0x6BBf…73B8`, call `upgradeTo(NEW_IMPL)` on `0x7848585b…dc83`:
   ```
   0x3659cfe6000000000000000000000000<NEW_IMPL without 0x, lowercase>
   ```
   This upgrades **every** V2 pool that uses this beacon. Other pools keep their current `withdrawDelayTimeSeconds`; only the maximum they may be set to changes.
3. **Set the delay on the pool.** From the TellerV2 owner `0x2f74c448cf6d613bee183fe35db0c9ac5084f66a`, call `setWithdrawDelayTime` on `0x13cd7cf42ccbaca8cd97e7f09572b6ea0de1097b`.

   The check is `require(_seconds < MAX_WITHDRAW_DELAY_TIME, "WD")`, which is a **strict** less-than. So `2592000` itself still reverts with `WD`. The largest accepted value is `2591999`:
   ```
   0x08a6355a0000000000000000000000000000000000000000000000000000000000278cff
   ```
