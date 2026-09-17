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
#   PUBLISH_PACKAGE=true    publish @teller-protocol/v2-contracts when done,
#                           patch-bumped from whatever npm currently has
#   NPM_TOKEN=<token>       npm credential, required by PUBLISH_PACKAGE. Must be
#                           an npm *automation* token: a classic token against
#                           an account with 2FA required cannot publish
#                           unattended, and yarn falls back to asking for a
#                           security key that nobody is there to press.
#   RUN_TAGS=<tags>         run only these deploy tags and stop. For wiring an
#                           already-deployed chain without a full run.
#   BOOTSTRAP_MARKETS=true  create the markets and lender pools for an already
#                           deployed chain and stop. A full run does this on
#                           its own; this is for re-running it alone.
#   BOOTSTRAP_DRY_RUN=true  with BOOTSTRAP_MARKETS, print the plan and send
#                           nothing.
#   SET_PRICE_CAPS=true     cap every pool in the bootstrap receipt at the
#                           price its own oracle quotes right now.
#   PRICE_CAPS_DRY_RUN=true with SET_PRICE_CAPS, print the caps without
#                           sending anything.
#   PRICE_CAP_BUFFER_BPS    headroom above the current reading, in bps.
#   PRICE_CAP_ONLY          only pools whose receipt key contains this.
#   PUBLISH_ONLY=true       publish the package from artifacts already in the
#                           repo and stop. Needs PUBLISH_PACKAGE=true and
#                           NPM_TOKEN. Sends no transaction. For a chain that
#                           deployed but never shipped, which no frontend can
#                           see until a release carries it.
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
# Same shape: ROBINHOOD_VERIFY_API_KEY, BASE_VERIFY_API_KEY, ...
VERIFY_KEY_VAR="$(echo "$NETWORK" | tr '[:lower:]-' '[:upper:]_')_VERIFY_API_KEY"

cd "$(dirname "$0")/.."   # packages/contracts

log() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
fail() { printf '\n\033[1;31m!! %s\033[0m\n' "$*" >&2; exit 1; }

# Commit whatever artifacts exist right now. Called twice on purpose: once the
# moment the deploy is done, and again at the end once verify and the subgraph
# configs have had their turn. The first call is the one that matters — it is
# what stops a crash in an optional later step taking the only record of a
# finished deploy down with the container. $1 is the commit subject.
# Cuts a release of @teller-protocol/v2-contracts carrying this chain.
#
# A function so PUBLISH_ONLY can reach it without a full deploy. It bumps from
# whatever npm currently has rather than from the tree, whose version field has
# drifted well behind, and refuses to publish a package that does not carry the
# chain — a release the frontends believe but that has no addresses in it is
# worse than no release at all.
publish_package() {
  log "Publish @teller-protocol/v2-contracts"
  PKG="$(node -p "require('./package.json').name")"
  CHAIN_ID="$(cat "deployments/$NETWORK/.chainId")"

  # The version field in the tree has drifted well behind the registry (3.1.51
  # committed against 3.1.61 published), so npm is the only trustworthy base.
  LATEST="$(npm view "$PKG" version 2>/dev/null || true)"
  [ -n "$LATEST" ] || fail "Could not read the published version of $PKG from npm."
  NEXT="$(node -e 'const [a,b,c] = process.argv[1].split(".").map(Number); console.log([a, b, c + 1].join("."))' "$LATEST")"
  log "npm has $LATEST — publishing $NEXT"
  node -e 'const fs = require("fs"); const j = JSON.parse(fs.readFileSync("./package.json", "utf8")); j.version = process.argv[1]; fs.writeFileSync("./package.json", JSON.stringify(j, null, 2) + "\n")' "$NEXT"

  # prepack compiles and regenerates build/hardhat/contracts.json, and `yarn
  # npm publish` would run it anyway. Running it here first means the tarball
  # can be inspected before it is public: a published package that does not
  # carry the chain just deployed is worse than no package, because every
  # frontend will believe it.
  # teller-math-lib is a private git submodule and the deploy image clones with
  # a depth-1 fetch that does not recurse, so build/math cannot compile without
  # this. It runs here rather than in the Dockerfile on purpose: a build arg
  # would bake the credential into the image history, while a runtime env var
  # does not survive the container.
  if [ ! -f teller-math-lib/tsconfig.json ]; then
    [ -n "${GITHUB_TOKEN:-}" ] || fail \
      "teller-math-lib is not checked out and GITHUB_TOKEN is unset, so build/math cannot be compiled. Publishing without it ships a package every frontend fails to bundle."
    log "Fetching the teller-math-lib submodule"
    git -c "url.https://x-access-token:${GITHUB_TOKEN}@github.com/.insteadOf=git@github.com:" \
        -c "url.https://x-access-token:${GITHUB_TOKEN}@github.com/.insteadOf=https://github.com/" \
        submodule update --init --depth 1 teller-math-lib >/dev/null 2>&1 || true
    [ -f teller-math-lib/tsconfig.json ] || fail \
      "Could not fetch the teller-math-lib submodule. GITHUB_TOKEN needs read access to teller-protocol/teller-math-lib, which is private."
  fi

  node ./scripts/prepack.js || fail \
    "prepack failed. Nothing was published."
  # TellerV2 present is necessary, not sufficient. Robinhood published with
  # every contract it had and still had no BorrowSwap, because the deploy that
  # created BorrowSwap died before writing its artifact - so deployments/ was
  # the thing missing it, and a check that only looks for TellerV2 sails past
  # that. The marketplace reads this manifest to decide whether Loop exists,
  # and the absence of one entry is invisible until a user clicks the tab.
  #
  # So compare the two: every artifact in deployments/<network>/ should have
  # become an entry in the manifest.
  node -e '
    const fs = require("fs");
    const path = require("path");
    const j = require("./build/hardhat/contracts.json");
    const [id, network] = process.argv.slice(1);

    const addr = j[id] && j[id].contracts && j[id].contracts.TellerV2 && j[id].contracts.TellerV2.address;
    if (!addr) { console.error("contracts.json has no TellerV2 for chain " + id); process.exit(1); }
    console.log("contracts.json carries chain " + id + " -> " + addr);

    const dir = path.join("deployments", network);
    const onDisk = fs.readdirSync(dir)
      .filter((f) => f.endsWith(".json") && f !== "market-bootstrap.json")
      .map((f) => f.slice(0, -5));
    const inManifest = new Set(Object.keys(j[id].contracts || {}));
    const missing = onDisk.filter((name) => !inManifest.has(name));
    if (missing.length) {
      console.error("contracts.json is missing " + missing.length + " of " + onDisk.length +
                    " deployed contract(s) for " + network + ": " + missing.join(", "));
      process.exit(1);
    }
    console.log("contracts.json carries all " + onDisk.length + " deployed contracts for " + network);
  ' "$CHAIN_ID" "$NETWORK" || fail \
    "The package would not carry $NETWORK (chain $CHAIN_ID) completely. Refusing to publish."

  # The chain being present is not the same as the package being whole. 3.1.62
  # carried chain 4663 correctly and still broke every frontend, because
  # build/math was silently absent and that is what useCreateCommitment
  # imports. Check the entry points a consumer actually resolves.
  for required in build/math/index.js build/hardhat/contracts.json; do
    [ -f "$required" ] || fail \
      "prepack produced no $required. Refusing to publish an incomplete package. If it is build/math, teller-math-lib is a submodule and this checkout did not fetch it."
  done

  # CI=true stops yarn falling back to a browser login. Without it, a token
  # npm will not accept for publishing (a classic token against an account with
  # 2FA required, rather than an automation token) makes yarn print a
  # npmjs.com/login URL and wait for a security key — in a container with no
  # one at the keyboard. It then exited 0, so `|| fail` never fired and the run
  # reported success having published nothing.
  CI=true YARN_NPM_AUTH_TOKEN="$NPM_TOKEN" yarn npm publish --access public \
    || fail "npm publish failed. Nothing was published; the version bump is uncommitted."

  # Ask the registry rather than trusting the exit code, for the same reason:
  # this step is the whole point of the run, and every frontend keys off its
  # result, so "probably published" is not good enough.
  #
  # Retried, because a fresh version takes a little while to become visible and
  # a single immediate check reports a good publish as a failure.
  PUBLISHED=""
  for attempt in 1 2 3 4 5 6; do
    PUBLISHED="$(npm view "$PKG@$NEXT" version 2>/dev/null || true)"
    [ "$PUBLISHED" = "$NEXT" ] && break
    sleep $((attempt * 15))
  done
  [ "$PUBLISHED" = "$NEXT" ] || fail \
    "yarn said \"Package archive published\" but npm still has no $PKG@$NEXT after 90s, so nothing shipped.
   Most likely it went to npm's staging area: check Staged Packages on npmjs.com
   and release it there, and check NPM_TOKEN grants \"Read and write (publish and
   stage)\" rather than \"stage only\".
   If the log instead shows a npmjs.com/login URL, the token is not an automation
   token and 2FA blocked the publish."
  echo "Published $PKG@$NEXT"

  # Record the version that went out, so the tree stops drifting from npm.
  if [ "${PUSH_ARTIFACTS:-}" = "true" ]; then
    git add package.json
    if ! git diff --cached --quiet; then
      git -c user.name="teller-deploy" -c user.email="deploy@teller.org" \
        commit -q -m "Publish $PKG@$NEXT with $NETWORK"
      git push origin "$ARTIFACT_REFSPEC" || \
        echo "!! Published $NEXT but could not push the version bump."
    fi
  fi
}

# Where the artifacts are going, decided before the work rather than after it.
# deployments/<network>/ and .openzeppelin/ are the only record of where
# anything landed and which implementation is behind which proxy; on an
# ephemeral host they die with the container, and a re-run without them
# redeploys the whole protocol from scratch rather than resuming.
#
# A function because the early-exit modes need it too. BOOTSTRAP_MARKETS
# called push_artifacts while this was still inline below them, so
# ARTIFACT_REFSPEC was unset and the run died on `unbound variable` — after
# creating two markets and sixteen pools whose addresses then went nowhere.
prepare_artifact_push() {
  [ "${PUSH_ARTIFACTS:-}" = "true" ] || return 0
  ARTIFACT_BRANCH="${ARTIFACT_BRANCH:-$(git rev-parse --abbrev-ref HEAD)}"
  [ "$ARTIFACT_BRANCH" != "HEAD" ] || fail \
    "PUSH_ARTIFACTS is set but HEAD is detached, so there is no branch to push to. Set ARTIFACT_BRANCH."
  # Spelled once. `HEAD:<branch>` is rejected outright when <branch> does not
  # exist on the remote — git cannot tell whether you meant a branch or a tag
  # and refuses to guess. The probe and the push must use the *same* refspec:
  # when they did not, the probe passed, the push failed, and a finished
  # mainnet deploy went into a container that then exited.
  ARTIFACT_REFSPEC="HEAD:refs/heads/$ARTIFACT_BRANCH"
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
      "$ARTIFACT_REFSPEC" >/dev/null 2>&1 || fail \
      "GITHUB_TOKEN cannot push $REPO_PATH. Expired, scoped to another repo, or missing contents:write."
  fi
}

push_artifacts() {
  [ "${PUSH_ARTIFACTS:-}" = "true" ] || return 0
  # A container clone has no push credential. Inject one for this run only,
  # and keep it out of `git remote -v` and the process list where possible.
  if [ -n "${GITHUB_TOKEN:-}" ] && [ -z "${REMOTE_AUTHED:-}" ]; then
    REPO_PATH="$(git remote get-url origin | sed -E 's#^https://[^/]+/##; s#^git@[^:]+:##; s#\.git$##')"
    git remote set-url origin "https://x-access-token:${GITHUB_TOKEN}@github.com/${REPO_PATH}.git"
    REMOTE_AUTHED=1
  fi
  # No --unshallow. git pushes from a depth-1 clone perfectly well — the commit
  # sits on a parent the remote already has, so it sends a thin pack. Fetching
  # the full history of this repo instead took the job from "about to push" to
  # blocked on network I/O with nothing on stdout, which reads exactly like a
  # finished run and is how the second Robinhood deploy was lost.
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
    echo "Nothing staged — nothing new to commit."
    return 0
  fi
  echo "Staging $(git diff --cached --name-only | wc -l) file(s):"
  git diff --cached --name-only | sed 's/^/    /' | head -20
  git -c user.name="teller-deploy" -c user.email="deploy@teller.org" \
    commit -q -m "$1

Written by scripts/deploy-chain.sh. Timelock: ${TIMELOCK_ADDRESS:-not yet deployed}"
  # Retry: a transient network failure here costs the whole deploy record.
  for attempt in 1 2 3; do
    if git push origin "$ARTIFACT_REFSPEC"; then
      echo "Pushed to $ARTIFACT_BRANCH."
      return 0
    fi
    echo "Push attempt $attempt failed; retrying."
    sleep $((attempt * 5))
  done
  fail "Could not push the artifacts to $ARTIFACT_BRANCH after 3 attempts. They exist only in this container — copy the address table above before it exits."
}

# --- preflight -------------------------------------------------------------
# Fail on missing inputs now, with a readable message, rather than 40 contracts
# deep with a stack trace.

[ -n "${SAFE_GLOBAL_API_KEY:-}" ] || fail "SAFE_GLOBAL_API_KEY is not set (hardhat refuses to start without it)."

# Publishing is how the frontends find out a chain exists at all, so the
# credential for it is a preflight concern like any other.
if [ "${PUBLISH_PACKAGE:-}" = "true" ]; then
  [ -n "${NPM_TOKEN:-}" ] || fail \
    "PUBLISH_PACKAGE is set but NPM_TOKEN is not. The package cannot be published without it."
fi

# A single deploy tag, against a chain that is already deployed.
#
# Wiring steps — granting a role, pointing the forwarder at an oracle — are
# ordinary deploy scripts, but reaching them through a full run means paying
# for two passes and a verification sweep to execute one of them. Worse, on a
# chain whose artifacts went missing it would deploy a second protocol. This
# runs the named tags and stops.
#
# hardhat-deploy still resolves each tag's dependencies, and skips any script
# whose id is already recorded in deployments/<network>/.migrations.json — so
# the dependencies resolve to no-ops on a chain that is already deployed, and
# fail loudly rather than silently redeploying if the artifacts are absent.
if [ -n "${RUN_TAGS:-}" ]; then
  [ -d "deployments/$NETWORK" ] || fail \
    "RUN_TAGS needs deployments/$NETWORK in this checkout, or its dependencies would deploy a second protocol."
  [ -n "${DEPLOYER_MNEMONIC:-}" ] || fail "DEPLOYER_MNEMONIC is not set."
  printf '%s' "$DEPLOYER_MNEMONIC" > mnemonic.secret
  chmod 600 mnemonic.secret
  trap 'rm -f mnemonic.secret' EXIT

  log "Deployer preflight on $NETWORK"
  yarn hh run --no-compile scripts/preflight-deployer.ts --network "$NETWORK" \
    || fail "Deployer preflight failed."

  log "Running tags [$RUN_TAGS] on $NETWORK"
  yarn hh deploy --network "$NETWORK" --tags "$RUN_TAGS"
  log "Done — $NETWORK (tags: $RUN_TAGS)"
  exit 0
fi

# Markets and lender pools, against a protocol that is already deployed.
#
# Separated from the deploy for the same reason as RUN_TAGS: creating markets
# is cheap and idempotent, but reaching it through a full run on a chain whose
# artifacts went missing would mint a second protocol. The task itself skips
# anything already recorded in market-bootstrap.json, so re-running is safe.
if [ "${BOOTSTRAP_MARKETS:-}" = "true" ]; then
  [ -d "deployments/$NETWORK" ] || fail \
    "BOOTSTRAP_MARKETS needs deployments/$NETWORK in this checkout."
  [ -f "config/chain-bootstrap/$NETWORK.ts" ] || fail \
    "No config/chain-bootstrap/$NETWORK.ts. Add one before bootstrapping $NETWORK."
  [ -n "${DEPLOYER_MNEMONIC:-}" ] || fail "DEPLOYER_MNEMONIC is not set."
  printf '%s' "$DEPLOYER_MNEMONIC" > mnemonic.secret
  chmod 600 mnemonic.secret
  trap 'rm -f mnemonic.secret' EXIT

  # Before the first transaction, not after the last one. The receipt is the
  # only thing that stops a re-run creating a second set of markets, so a run
  # that cannot push it is worse than one that never started.
  prepare_artifact_push

  log "Deployer preflight on $NETWORK"
  yarn hh run --no-compile scripts/preflight-deployer.ts --network "$NETWORK" \
    || fail "Deployer preflight failed."

  # Compare against "true" rather than using ${VAR:+...}, which expands on any
  # non-empty value — including the string "false", which would silently turn
  # a real run into a dry one.
  if [ "${BOOTSTRAP_DRY_RUN:-}" = "true" ]; then
    log "Bootstrap markets and pools on $NETWORK (dry run — nothing will be sent)"
    yarn hh bootstrap-markets --network "$NETWORK" --dry-run true
  else
    log "Bootstrap markets and pools on $NETWORK"
    yarn hh bootstrap-markets --network "$NETWORK"
  fi

  if [ "${PUSH_ARTIFACTS:-}" = "true" ] && [ "${BOOTSTRAP_DRY_RUN:-}" != "true" ]; then
    log "Committing bootstrap receipt to $ARTIFACT_BRANCH"
    push_artifacts "Add $NETWORK markets and lender pools"
  fi

  log "Done — $NETWORK (markets and pools)"
  exit 0
fi

# Price caps on pools that already exist.
#
# Separate from BOOTSTRAP_MARKETS because it is a recurring job, not a launch
# step: the cap is only worth having while it sits near the real price, so this
# is meant to be re-run. It reads each pool's own oracle and writes the result
# back as a ceiling, so it needs the bootstrap receipt to know which pools
# exist and the deployer key to sign as their owner.
if [ "${SET_PRICE_CAPS:-}" = "true" ]; then
  [ -d "deployments/$NETWORK" ] || fail \
    "SET_PRICE_CAPS needs deployments/$NETWORK in this checkout."
  [ -f "deployments/$NETWORK/market-bootstrap.json" ] || fail \
    "No deployments/$NETWORK/market-bootstrap.json. Run BOOTSTRAP_MARKETS first."
  [ -n "${DEPLOYER_MNEMONIC:-}" ] || fail "DEPLOYER_MNEMONIC is not set."
  printf '%s' "$DEPLOYER_MNEMONIC" > mnemonic.secret
  chmod 600 mnemonic.secret
  trap 'rm -f mnemonic.secret' EXIT

  CAP_ARGS=""
  [ -n "${PRICE_CAP_BUFFER_BPS:-}" ] && CAP_ARGS="--buffer-bps ${PRICE_CAP_BUFFER_BPS}"
  [ -n "${PRICE_CAP_ONLY:-}" ] && CAP_ARGS="$CAP_ARGS --only ${PRICE_CAP_ONLY}"

  # Same "true" comparison as the bootstrap dry run, and for the same reason:
  # ${VAR:+...} expands on the string "false" and would send a run meant to be
  # a rehearsal.
  if [ "${PRICE_CAPS_DRY_RUN:-}" = "true" ]; then
    log "Set pool price caps on $NETWORK (dry run — nothing will be sent)"
    # shellcheck disable=SC2086
    yarn hh set-pool-price-caps --network "$NETWORK" --dry-run true $CAP_ARGS
  else
    log "Set pool price caps on $NETWORK"
    # shellcheck disable=SC2086
    yarn hh set-pool-price-caps --network "$NETWORK" $CAP_ARGS
  fi

  log "Done — $NETWORK (price caps)"
  exit 0
fi

# Publishing alone, from deployment artifacts already in the repo.
#
# A chain is invisible to every frontend until @teller-protocol/v2-contracts
# ships its TellerV2 address: the network switcher filters its chain list on
# exactly that. When a deploy lands but the publish does not — no NPM_TOKEN at
# the time, or a later failure — the only way to ship it used to be re-running
# the whole deploy, which on a chain whose artifacts went missing mints a
# second protocol. This sends no transaction and needs no deployer key.
if [ "${PUBLISH_ONLY:-}" = "true" ]; then
  [ -d "deployments/$NETWORK" ] || fail \
    "PUBLISH_ONLY needs deployments/$NETWORK in this checkout, or the package would not carry the chain."
  [ "${PUBLISH_PACKAGE:-}" = "true" ] || fail \
    "PUBLISH_ONLY is set but PUBLISH_PACKAGE is not \"true\". Set both, so publishing is never a side effect of one flag."
  # prepack runs a hardhat compile, and hardhat builds its accounts config at
  # startup. Publishing signs nothing, so this is the public hardhat test
  # mnemonic rather than the real key.
  printf '%s' 'test test test test test test test test test test test junk' > mnemonic.secret
  chmod 600 mnemonic.secret
  trap 'rm -f mnemonic.secret' EXIT
  prepare_artifact_push
  publish_package
  log "Done — $NETWORK (publish only)"
  exit 0
fi

# Verification alone, against deployment artifacts already in the repo.
#
# It exists because verification and deployment fail for unrelated reasons, and
# without it the only way to retry a verify is to re-run the deploy — which on
# a chain whose artifacts are missing mints a second set of contracts. It sends
# no transaction, needs no deployer key, and skips the artifact gate because it
# produces no artifacts.
if [ "${VERIFY_ONLY:-}" = "true" ]; then
  [ -d "deployments/$NETWORK" ] || fail \
    "VERIFY_ONLY needs deployments/$NETWORK, which is not in this checkout. Pin the image to a ref that has the artifacts."
  # hardhat builds its accounts config at startup and throws "Invalid mnemonic"
  # without this file, so verify-all cannot even start. Verification signs
  # nothing, so this is the public hardhat test mnemonic rather than the real
  # key: a verify run has no business holding the thing that can deploy.
  printf '%s' 'test test test test test test test test test test test junk' > mnemonic.secret
  chmod 600 mnemonic.secret
  trap 'rm -f mnemonic.secret' EXIT
  log "Verify on $NETWORK (VERIFY_ONLY — nothing will be deployed)"
  yarn hh verify-all --network "$NETWORK" || \
    echo "!! verify-all reported errors. The check below is what actually counts."
  log "What is actually verified on $NETWORK"
  yarn hh run --no-compile scripts/check-verification.ts --network "$NETWORK"
  log "Done — $NETWORK (verification only)"
  exit 0
fi

# Deploying a whole protocol is the fall-through, and that is the wrong
# default for a service that anything can redeploy.
#
# Every mode above exits on its own, so a run with no mode set lands here and
# starts a two-pass deployment of the entire protocol. On a chain that is
# already live, whether that mints a second protocol or no-ops depends entirely
# on whether deployments/<network>/ happens to be in the image — which is a
# property of the pinned ref, not of anyone's intent. A redeploy button, a
# variable edit or a merge to main is enough to trigger it.
#
# So the big one asks to be named. DEPLOY_PROTOCOL=true is the only way to
# reach it, and without it the run lists what it could have done and exits
# clean rather than either deploying or crash-looping.
if [ "${DEPLOY_PROTOCOL:-}" != "true" ]; then
  cat <<EOF

  Nothing to do: no mode is set, and a full protocol deploy is not the default.

  This service runs one job and exits. Pick one:

    BOOTSTRAP_MARKETS=true   create this chain's markets and lender pools
    SET_PRICE_CAPS=true      cap existing pools at their current oracle price
    RUN_TAGS=<tags>          run named deploy tags against a deployed chain
    VERIFY_ONLY=true         verify already-deployed contracts
    PUBLISH_ONLY=true        publish the package (with PUBLISH_PACKAGE=true)
    DEPLOY_PROTOCOL=true     deploy the entire protocol to $NETWORK from scratch

  DEPLOY_PROTOCOL is deliberately not the default. Reaching it by accident on a
  chain that is already live can deploy a second protocol, and the deployed
  addresses of the first one are then only in this container's logs.
EOF
  exit 0
fi

[ -n "${DEPLOYER_MNEMONIC:-}" ] || fail "DEPLOYER_MNEMONIC is not set."

prepare_artifact_push
if [ "${PUSH_ARTIFACTS:-}" != "true" ] && [ "${ALLOW_EPHEMERAL_ARTIFACTS:-}" != "true" ]; then
  fail "PUSH_ARTIFACTS is not \"true\", so the deployment artifacts would exist only on this host.
   If that is a container they are gone the moment it exits, and the next run
   redeploys everything instead of resuming. Set PUSH_ARTIFACTS=true (with
   GITHUB_TOKEN and ARTIFACT_BRANCH), or ALLOW_EPHEMERAL_ARTIFACTS=true if you
   really are deploying somewhere the files survive."
fi

# Verification needs its key up front too. Etherscan V2 covers chain 4663 and
# every other network here off one key, so this is nearly always just
# ETHERSCANV2_VERIFY_API_KEY — but an unverified lending protocol is not
# something to discover after the fact, when re-verifying means having kept
# the artifacts and running the whole thing again.
if [ "${SKIP_VERIFY:-}" != "true" ]; then
  eval "NETWORK_VERIFY_KEY=\${${VERIFY_KEY_VAR}:-}"
  [ -n "${NETWORK_VERIFY_KEY}${ETHERSCANV2_VERIFY_API_KEY:-}" ] || fail \
    "No verification key: set ETHERSCANV2_VERIFY_API_KEY (Etherscan V2, one key for every chain it lists) or $VERIFY_KEY_VAR, or SKIP_VERIFY=true to deploy unverified."
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
# Cheap insurance: the addresses exist now, so bank them before pass 2. The
# second call re-stages and says "nothing new" if pass 2 changes nothing.
log "Committing artifacts to $ARTIFACT_BRANCH (pass 1 complete)"
push_artifacts "Add $NETWORK deployment artifacts (pass 1)"

log "Deploy pass 2 — $NETWORK (ownership transfers)"
yarn hh deploy --network "$NETWORK"

# The chain is now deployed. Get the record out before doing anything that can
# fail — verify talks to an explorer API, and on a new chain that is the least
# reliable thing in the stack.
log "Committing artifacts to $ARTIFACT_BRANCH (deploy complete)"
push_artifacts "Add $NETWORK deployment artifacts"

# --- verify ----------------------------------------------------------------
# Never fatal: unverified contracts are a cosmetic problem, and on a new chain
# the explorer's API is the least reliable part of the stack.
if [ "${SKIP_VERIFY:-}" = "true" ]; then
  log "Skipping verification on $NETWORK (SKIP_VERIFY=true)"
else
  log "Verify on $NETWORK"
  yarn hh verify-all --network "$NETWORK" || \
    echo "!! Verification failed. Contracts are deployed and fine; re-run verify later."
  # hardhat-verify 1.x predates Etherscan V2 and drops the chainid param when
  # polling for a result, so it reports failures on submissions the API
  # accepted. Ask the API directly rather than believing either one.
  log "What is actually verified on $NETWORK"
  yarn hh run --no-compile scripts/check-verification.ts --network "$NETWORK" || \
    echo "!! Some contracts are not verified. Re-run verify-all; the deploy itself is fine."
fi

# --- validate --------------------------------------------------------------
log "Validate deployment"
yarn hh deploy --network "$NETWORK" --tags validate-deployments

# --- subgraph configs ------------------------------------------------------
log "Fill subgraph configs from the artifacts"
node scripts/fill-subgraph-config.js "$NETWORK"

# --- markets and pools -----------------------------------------------------
# A chain with contracts but no markets has nothing for a borrower to bid into
# and nothing for a lender to deposit against, so every new chain gets the
# standard set. Chains without a config/chain-bootstrap entry are skipped
# rather than failed: the protocol is still correctly deployed without it.
if [ -f "config/chain-bootstrap/$NETWORK.ts" ]; then
  log "Bootstrap markets and pools on $NETWORK"
  yarn hh bootstrap-markets --network "$NETWORK" \
    || echo "!! bootstrap-markets failed. The protocol is deployed; re-run with BOOTSTRAP_MARKETS=true."
else
  log "No config/chain-bootstrap/$NETWORK.ts — skipping markets and pools"
fi

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

# Second pass at the artifacts: the subgraph configs did not exist at the first
# call, and verify may have written to .openzeppelin.
if [ "${PUSH_ARTIFACTS:-}" = "true" ]; then
  log "Committing subgraph configs to $ARTIFACT_BRANCH"
  push_artifacts "Add $NETWORK subgraph configs"
else
  cat <<EOF

  PUSH_ARTIFACTS is not "true", so deployments/$NETWORK/ exists only on this
  host. If that is a container, the table above is the only record — copy it.
  Set PUSH_ARTIFACTS=true to have the run commit the artifacts to the branch.
EOF
fi

# --- publish ---------------------------------------------------------------
# @teller-protocol/v2-contracts is how every frontend learns a chain exists:
# the network switcher keys off contracts.json carrying that chain's TellerV2
# address, and useContracts reads the same file. A chain that is deployed,
# verified and indexed but never published is still invisible in the app.
#
# Runs last on purpose. Publishing is the one step here that cannot be undone
# — npm forbids re-using a version number — so it goes after everything that
# might still fail.
if [ "${PUBLISH_PACKAGE:-}" = "true" ]; then
  publish_package
else
  cat <<EOF

  PUBLISH_PACKAGE is not "true", so $NETWORK is deployed but not published.
  The frontends read @teller-protocol/v2-contracts and will not show this
  chain until a release carries it. PUBLISH_ONLY=true ships it later without
  redeploying anything.
EOF
fi

log "Done — $NETWORK"
