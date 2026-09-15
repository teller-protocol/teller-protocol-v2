#!/usr/bin/env bash
#
# One-shot chain deploy: everything from an empty chain to filled subgraph
# configs, in one command. Host-agnostic — a laptop, a Railway job, a CI
# runner; it only needs node, yarn and an RPC it can reach.
#
# Does the whole of the deploy that a person otherwise does by hand:
#
#   pass 1  ->  read the timelock address out of the artifacts  ->  pass 2
#   ->  verify  ->  validate  ->  fill the subgraph configs
#
# The address hand-off between the two passes is the point. hardhat-deploy
# cannot transfer ownership to a timelock that does not exist yet, so the
# first pass deploys it and the second pass consumes it. Done manually that
# means copying an address out of a JSON file into .env between two commands,
# which is exactly the kind of step that gets fat-fingered at 2am.
#
# Safe to re-run: hardhat-deploy skips contracts it has already deployed, so a
# crashed run resumes rather than redeploying.
#
#   NETWORK=robinhood \
#   DEPLOYER_MNEMONIC="..." \
#   SAFE_GLOBAL_API_KEY=... \
#   ROBINHOOD_RPC_URL=https://rpc.mainnet.chain.robinhood.com \
#     ./scripts/deploy-chain.sh
#
# Optional:
#   PUSH_ARTIFACTS=true     commit deployments/<network>/ back to the branch
#   ARTIFACT_BRANCH=<name>  branch to push to (default: current; required when
#                           HEAD is detached, as it is in the deploy image)
#   GITHUB_TOKEN=<token>    push credential, needed on a host with no git auth
#   ALLOW_EPHEMERAL_ARTIFACTS=true
#                           deploy without preserving the artifacts anywhere.
#                           Only for a host where the files actually survive.
#   SKIP_BALANCE_CHECK=true    deploy even if the deployer looks underfunded
#   MIN_DEPLOYER_BALANCE=<eth> balance the preflight insists on (default 0.02)
#
# On an ephemeral host, keep a copy of DEPLOYER_MNEMONIC somewhere durable
# before funding it. If the host dies between pass 1 and the ownership
# transfers, that key is the only thing that can finish the job.

set -euo pipefail

NETWORK="${NETWORK:?NETWORK is required (e.g. robinhood)}"
# The env var name hardhat.config.ts reads for this chain's timelock.
TIMELOCK_VAR="$(echo "$NETWORK" | tr '[:lower:]-' '[:upper:]_')_TIMELOCK_ADDRESS"

cd "$(dirname "$0")/.."   # packages/contracts

log() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
fail() { printf '\n\033[1;31m!! %s\033[0m\n' "$*" >&2; exit 1; }

# --- preflight -------------------------------------------------------------
# Fail on missing inputs now, with a readable message, rather than 40 contracts
# deep with a stack trace.

[ -n "${DEPLOYER_MNEMONIC:-}" ] || fail "DEPLOYER_MNEMONIC is not set."
[ -n "${SAFE_GLOBAL_API_KEY:-}" ] || fail "SAFE_GLOBAL_API_KEY is not set (hardhat refuses to start without it)."

# Where the artifacts are going, decided before the deploy rather than after
# it. deployments/<network>/ and .openzeppelin/ are the only record of where
# anything landed and which implementation is behind which proxy; on an
# ephemeral host they die with the container, and a re-run without them
# redeploys the whole protocol from scratch rather than resuming.
if [ "${PUSH_ARTIFACTS:-}" = "true" ]; then
  ARTIFACT_BRANCH="${ARTIFACT_BRANCH:-$(git rev-parse --abbrev-ref HEAD)}"
  [ "$ARTIFACT_BRANCH" != "HEAD" ] || fail \
    "PUSH_ARTIFACTS is set but HEAD is detached, so there is no branch to push to. Set ARTIFACT_BRANCH."
  # A container clone has no credential helper and no keys. Find out now, not
  # after a successful deploy with nowhere to put the result.
  if ! git config --get-regexp '^credential\.' >/dev/null 2>&1; then
    [ -n "${GITHUB_TOKEN:-}" ] || fail \
      "PUSH_ARTIFACTS is set but this clone has no push credential and GITHUB_TOKEN is unset."
  fi
  # Presence is not access. A token that is expired, scoped to the wrong repo
  # or missing contents:write otherwise gets discovered at the push, which is
  # after the deploy — exactly the failure this whole block exists to prevent.
  # --dry-run runs the real authenticated negotiation and creates nothing, and
  # works from the depth-1 clone the image makes.
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    REPO_PATH="$(git remote get-url origin | sed -E 's#^https://[^/]+/##; s#^git@[^:]+:##; s#\.git$##')"
    git push --dry-run -q \
      "https://x-access-token:${GITHUB_TOKEN}@github.com/${REPO_PATH}.git" \
      "HEAD:refs/heads/$ARTIFACT_BRANCH" >/dev/null 2>&1 || fail \
      "GITHUB_TOKEN cannot push $REPO_PATH. Expired, scoped to another repo, or missing contents:write."
  fi
elif [ "${ALLOW_EPHEMERAL_ARTIFACTS:-}" != "true" ]; then
  fail "PUSH_ARTIFACTS is not \"true\", so the deployment artifacts would exist only on this host.
   If that is a container they are gone the moment it exits, and the next run
   redeploys everything instead of resuming. Set PUSH_ARTIFACTS=true (with
   GITHUB_TOKEN and ARTIFACT_BRANCH), or ALLOW_EPHEMERAL_ARTIFACTS=true if you
   really are deploying somewhere the files survive."
fi

# hardhat reads the deploy key from this file, not the environment.
printf '%s' "$DEPLOYER_MNEMONIC" > mnemonic.secret
chmod 600 mnemonic.secret
# Do not leave a key on disk if the container is reused or an image is cached.
trap 'rm -f mnemonic.secret' EXIT

# Not `yarn hh account`: that task prints the deployer's private key, and on a
# CI or Railway job stdout is a log store that outlives the run. This prints
# the address and the balance, checks the mnemonic parses, and refuses to go
# on with a deployer that cannot pay for the deploy.
[ "${SKIP_BALANCE_CHECK:-}" != "true" ] || export MIN_DEPLOYER_BALANCE=0

log "Deployer preflight on $NETWORK"
yarn hh run --no-compile scripts/preflight-deployer.ts --network "$NETWORK" \
  || fail "Deployer preflight failed — see the error above. A bad mnemonic, an unreachable RPC and an unfunded deployer all land here."

# --- pass 1 ----------------------------------------------------------------
log "Deploy pass 1 — $NETWORK"
yarn hh deploy --network "$NETWORK"

TIMELOCK_FILE="deployments/$NETWORK/TimelockController.json"
[ -f "$TIMELOCK_FILE" ] || fail "Pass 1 finished but $TIMELOCK_FILE does not exist. Nothing to hand to pass 2."

TIMELOCK_ADDRESS="$(node -e "process.stdout.write(require('./$TIMELOCK_FILE').address)")"
case "$TIMELOCK_ADDRESS" in
  0x[0-9a-fA-F][0-9a-fA-F]*) : ;;
  *) fail "Read a non-address timelock value: '$TIMELOCK_ADDRESS'" ;;
esac
[ "$TIMELOCK_ADDRESS" != "0x0000000000000000000000000000000000000000" ] \
  || fail "Timelock deployed to the zero address — refusing to continue."

log "Timelock: $TIMELOCK_ADDRESS  (exported as $TIMELOCK_VAR)"
export "$TIMELOCK_VAR=$TIMELOCK_ADDRESS"

# --- pass 2 ----------------------------------------------------------------
# Picks up the scripts that skipped in pass 1 because the timelock was still
# the zero address: the ProxyAdmin and beacon ownership transfers.
log "Deploy pass 2 — $NETWORK (ownership transfers)"
yarn hh deploy --network "$NETWORK"

# --- verify ----------------------------------------------------------------
# Never fatal: unverified contracts are a cosmetic problem, and on a new chain
# the explorer's API is the least reliable part of the stack.
log "Verify on $NETWORK"
yarn hh verify-all --network "$NETWORK" || \
  echo "!! Verification failed. Contracts are deployed and fine; re-run verify later (try the Blockscout vars)."

# --- validate --------------------------------------------------------------
log "Validate deployment"
yarn hh deploy --network "$NETWORK" --tags validate-deployments

# --- subgraph configs ------------------------------------------------------
log "Fill subgraph configs from the artifacts"
node scripts/fill-subgraph-config.js "$NETWORK"

# --- report ----------------------------------------------------------------
# The container is ephemeral, so the addresses have to leave in the logs at
# minimum. push-artifacts.sh is what actually gets them back into git.
log "Deployed addresses on $NETWORK"
node -e '
const fs = require("fs"), path = require("path");
const dir = path.join("deployments", process.argv[1]);
const rows = fs.readdirSync(dir)
  .filter((f) => f.endsWith(".json"))
  .map((f) => [f.replace(/\.json$/, ""), JSON.parse(fs.readFileSync(path.join(dir, f), "utf8")).address])
  .filter(([, a]) => a)
  .sort();
const w = Math.max(...rows.map(([n]) => n.length));
for (const [n, a] of rows) console.log(n.padEnd(w) + "  " + a);
' "$NETWORK"

BLOCK_FILE="deployments/$NETWORK/.latestDeploymentBlock"
[ -f "$BLOCK_FILE" ] && log "Start block: $(cat "$BLOCK_FILE")"

# On an ephemeral host the artifacts die with the container, and they are the
# only record of where anything landed — the subgraph configs, the frontend and
# the published manifest all read them. Commit them back when asked to.
if [ "${PUSH_ARTIFACTS:-}" = "true" ]; then
  log "Committing artifacts back to $ARTIFACT_BRANCH"
  # A container clone has no push credential. Inject one for this run only,
  # and keep it out of `git remote -v` and the process list where possible.
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    REPO_PATH="$(git remote get-url origin | sed -E 's#^https://[^/]+/##; s#^git@[^:]+:##; s#\.git$##')"
    git remote set-url origin "https://x-access-token:${GITHUB_TOKEN}@github.com/${REPO_PATH}.git"
  fi
  # The image clones at depth 1, and git will not push from a shallow repo.
  git fetch -q --unshallow origin 2>/dev/null || true
  # .openzeppelin lives beside deployments/ in packages/contracts, not at the
  # repo root. It held ../../ for long enough to matter: git add fails on a
  # pathspec that matches nothing and stages *none* of the other paths with
  # it, so PUSH_ARTIFACTS committed nothing at all.
  for p in "deployments/$NETWORK" \
           .openzeppelin \
           ../subgraph/config/"$NETWORK".json \
           ../subgraph-pool-v2/config/"$NETWORK".json; do
    [ -e "$p" ] && git add "$p"
  done
  if git diff --cached --quiet; then
    echo "Nothing new to commit."
  else
    git -c user.name="teller-deploy" -c user.email="deploy@teller.org" \
      commit -q -m "Add $NETWORK deployment artifacts

Written by scripts/deploy-chain.sh. Timelock: $TIMELOCK_ADDRESS"
    git push origin "HEAD:$ARTIFACT_BRANCH"
    echo "Pushed to $ARTIFACT_BRANCH."
  fi
else
  cat <<EOF

  PUSH_ARTIFACTS is not "true", so deployments/$NETWORK/ exists only on this
  host. If that is a container, the table above is the only record — copy it.
  Set PUSH_ARTIFACTS=true to have the run commit the artifacts to the branch.
EOF
fi

log "Done — $NETWORK"
