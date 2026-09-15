# Deploy runner (Railway)

Runs `scripts/deploy-chain.sh` as a **one-shot job** on Railway: it deploys a
chain, prints every address, and exits. Nothing in the script is
Railway-specific — this directory is just the container and service config for
running it somewhere with a good RPC route and no laptop involved.

## Service setup

Create a service in the Railway project from this repo, then:

| Setting | Value |
|---|---|
| Root Directory | `/` (the workspace resolves across `packages/`) |
| Dockerfile Path | `packages/contracts/railway/Dockerfile` |
| Restart Policy | **NEVER** |

**The restart policy matters.** This is a job that exits, not a server. On the
default `ON_FAILURE` policy a non-zero exit puts the container into a restart
loop, and each restart re-enters the deploy.

## Variables

| Variable | Required | Notes |
|---|---|---|
| `NETWORK` | yes | e.g. `robinhood` |
| `DEPLOYER_MNEMONIC` | yes | **use a burner.** See below. |
| `SAFE_GLOBAL_API_KEY` | yes | hardhat refuses to start without it |
| `ALCHEMY_API_KEY` | recommended | `hardhat.config.ts` builds `robinhood-mainnet.g.alchemy.com` from it |
| `ROBINHOOD_RPC_URL` | no | explicit override; wins over Alchemy |
| `PUSH_ARTIFACTS` | no | `true` commits `deployments/<network>/` back to the branch |
| `ARTIFACT_BRANCH` | no | branch to push to (default: the checked-out one) |
| `GITHUB_TOKEN` | with `PUSH_ARTIFACTS` | a container clone has no push credential |
| `ROBINHOOD_VERIFY_API_URL` | no | point at Blockscout if Etherscan V2 doesn't cover 4663 |

### On the deployer key

Use a fresh burner funded with just enough gas. It holds no lasting power —
the deploy transfers ownership to the Safe and the timelock — so the exposure
is the gas in it plus the window before those transfers land.

**Keep a copy of the mnemonic somewhere durable before funding it.** A
container is disposable; the key is not. If the job dies between pass 1 and the
ownership transfers, that key is the only thing that can finish the job, and
whatever it already deployed is otherwise stranded.

### On the artifacts

`deployments/<network>/` is the only record of where anything landed — the
subgraph configs, the frontend, teller-pro and the published manifest all read
it, and it dies with the container. Either set `PUSH_ARTIFACTS=true` with a
`GITHUB_TOKEN`, or copy the address table out of the run's logs before the
service is torn down.

## What a run does

```
preflight (mnemonic, Safe key, balance)
  -> deploy pass 1
  -> read TimelockController.json, export <NETWORK>_TIMELOCK_ADDRESS
  -> deploy pass 2   (ownership transfers)
  -> verify          (non-fatal)
  -> validate-deployments
  -> fill-subgraph-config.js
  -> print every deployed address
```

Re-running is safe: hardhat-deploy skips contracts it has already deployed, so
a crashed run resumes rather than redeploying.

## After the run

1. Check the ownership assertions in the `validate-deployments` output.
2. Get `deployments/<network>/` into git if `PUSH_ARTIFACTS` was off.
3. Deploy the two subgraphs against the filled configs, and register their
   query URLs with the endpoints middleware.
4. **Delete the service, or at least clear `DEPLOYER_MNEMONIC`.** The job is
   done and the variable is the only sensitive thing here.
