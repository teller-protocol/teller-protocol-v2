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
#                           already-deployed chain without a full run. Honours
#                           PUSH_ARTIFACTS, which the oracle wiring needs: it
#                           writes the Safe batch that switches the firewall on.
#   ACTIVATE_ONLY=<substr>  with RUN_TAGS=activate-pools, open only the pools
#                           whose receipt key contains this. The first deposit
#                           is spent rather than authorised, so on a chain that
#                           already lists thirty pools and is opening one, the
#                           money otherwise goes to whichever unopened pool
#                           comes first in the receipt. Overrides the config's
#                           activateMarkets: naming a pool is more specific.
#   BOOTSTRAP_MARKETS=true  create the markets and lender pools for an already
#                           deployed chain and stop. A full run does this on
#                           its own; this is for re-running it alone.
#   ALLOW_UNRECORDED_BOOTSTRAP=true
#                           run BOOTSTRAP_MARKETS with PUSH_ARTIFACTS off. Only
#                           when you will commit market-bootstrap.json yourself
#                           AND repin CONTRACTS_REF to that commit: a later run
#                           against a checkout without the entry deploys the
#                           pool a second time, which is how robinhood ended up
#                           with two short:STRATEGY pools.
#   BOOTSTRAP_DRY_RUN=true  with BOOTSTRAP_MARKETS, print the plan and send
#                           nothing.
#   REPLACE_POOLS=<keys>    with BOOTSTRAP_MARKETS, comma-separated receipt keys
#                           to deploy a replacement pool for, e.g.
#                           "short:ARGUS". The existing pool keeps working and
#                           moves to retiredPools in the receipt; the key comes
#                           to name the new one, so everything that reads the
#                           receipt follows. This is the only way to change a
#                           parameter written in the pool's `initialize` - the
#                           interest rate band has no setter on any
#                           implementation.
#   FORCE_REPLACE_POOLS=true
#                           replace even a pool with loans outstanding.
#                           Delisting one hides a position someone still has to
#                           repay or liquidate, so it is refused by default.
#   REDEEM_POOL=true        redeem the deployer's own shares out of a pool and
#                           stop. The counterpart of activate-pools, for
#                           collecting the deposit that opened a pool which has
#                           since been replaced. Needs REDEEM_POOL_KEY or
#                           REDEEM_POOL_ADDRESS.
#   REDEEM_POOL_KEY=<key>   receipt key, e.g. "short:ARGUS". Looked up in
#                           retiredPools as well as pools.
#   REDEEM_POOL_ADDRESS=<a> pool address, instead of a key.
#   REDEEM_POOL_SHARES=<n>  shares to redeem, raw units. Omitted means the
#                           deployer's whole balance.
#   REDEEM_POOL_DRY_RUN=true
#                           with REDEEM_POOL, print and send nothing.
#   AUDIT_POOL_CAPS=true    report every lender pool on this chain whose
#                           maxPrincipalPerCollateralAmount leaves it open to
#                           an inflated oracle, and stop. Read-only: it signs
#                           nothing and needs no deployer key, which is what
#                           makes it safe to run on a schedule. Exits non-zero
#                           when a pool holds borrowable principal with no cap,
#                           so the exit code is the alert.
#   AUDIT_MIN_AVAILABLE=<n> ignore pools with less than this much principal
#                           borrowable, in whole units. Default 1 - a dust pool
#                           with no cap is untidy, one with real principal is
#                           an incident.
#   AUDIT_DRIFT_PCT=<n>     flag a cap further than this percentage from the
#                           live oracle reading. Default 25.
#   AUDIT_FROM_BLOCK=<n>    first block to scan the factory from. Defaults to
#                           the factory's own deployment block.
#   AUDIT_CHUNK=<n>         largest block window to ask for logs over, halved
#                           automatically when a provider refuses the range.
#                           hyperliquid's public RPC caps eth_getLogs at 1000
#                           blocks and says so only by failing.
#   AUDIT_POOLS=<addrs>     comma-separated pools to audit instead of scanning.
#   AUDIT_JSON=true         emit JSON instead of a table, for an alerting hook.
#   AUDIT_NETWORKS=<names>  comma-separated networks to sweep instead of the one
#                           NETWORK. This is the scheduled shape of the audit:
#                           one container, every chain, one verdict. A chain with
#                           no deployments/ directory here is skipped by name
#                           rather than silently.
#   AUDIT_PAUSE_MS=<n>      milliseconds between pools. A public endpoint that
#                           throttles a burst serves the same calls spread out,
#                           and hyperevm's does exactly that - the first sweep
#                           read one pool of sixteen.
#   AUDIT_OWNED_BY=<addr,...>
#                           addresses whose pools this sweep answers for.
#                           setMaxPrincipalPerCollateralAmount is onlyOwner, so
#                           an uncapped pool belonging to anyone else is still
#                           enumerated, printed with its owner and posted to
#                           Slack - but it does not fail the run, because there
#                           is no action on this side to fail at. Unset means
#                           every pool counts, which is how this behaved before
#                           the option existed.
#   AUDIT_SLACK_WEBHOOK=<url>
#                           with AUDIT_NETWORKS, post to Slack when a sweep finds
#                           anything critical. Silent otherwise: a monitor that
#                           speaks every run is one nobody reads.
#   GROW_ORACLE=true        grow a Uniswap V3 pool's observation buffer so a
#                           TWAP can be read from it, and stop. Permissionless -
#                           increaseObservationCardinalityNext is callable by
#                           anyone - so this needs gas but no ownership. Needs
#                           GROW_ORACLE_POOL.
#   GROW_ORACLE_POOL=<addr> the Uniswap V3 pool whose buffer to grow.
#   GROW_ORACLE_TARGET=<n>  slots to allocate. Default 300. Only ever grows.
#   GROW_ORACLE_STEP=<n>    slots per transaction. Default 0, which measures it
#                           against the chain's block gas limit. A slot costs an
#                           SSTORE from zero, so 300 of them is ~6.7M gas and
#                           does not fit HyperEVM's 3M blocks - the run splits
#                           itself rather than asking for a transaction no block
#                           takes. It took five there, 74 slots at a time.
#   GROW_ORACLE_PROBE=true  report which TWAP windows the pool answers today
#                           and send nothing. Run this before pointing a pool
#                           config at a window: one the oracle cannot answer is
#                           a pool that cannot lend.
#   SEED_UNIV3=true         add full-range liquidity to a Uniswap V3 pool, so
#                           its TWAP is worth reading, and stop. Needs
#                           SEED_POOL, SEED_AMOUNT0 and SEED_AMOUNT1. For a
#                           token whose real market is V4: Teller reads V3 and
#                           only V3, so the choice is seeding a V3 pool or not
#                           lending against the token.
#   SEED_POOL=<addr>        the Uniswap V3 pool to seed.
#   SEED_AMOUNT0=<n>        whole tokens of the pool's token0 to add.
#   SEED_AMOUNT1=<n>        whole tokens of its token1.
#   SEED_POSITION_MANAGER=<addr>
#                           override the NonfungiblePositionManager. Only
#                           needed on a chain whose periphery this repo does
#                           not know - it is not the canonical address
#                           everywhere, and on Robinhood it is not even a
#                           position manager at that address.
#   SEED_SLIPPAGE_BPS=<n>   how far below the asked amounts the mint may
#                           settle. Default 500.
#   SEED_DRY_RUN=true       with SEED_UNIV3, print the plan and send nothing.
#   SET_PRICE_CAPS=true     cap every pool in the bootstrap receipt at the
#                           price its own oracle quotes right now.
#   PRICE_CAPS_DRY_RUN=true with SET_PRICE_CAPS, print the caps without
#                           sending anything.
#   PRICE_CAP_BUFFER_BPS    headroom above the current reading, in bps.
#   PRICE_CAP_ONLY          only pools whose receipt key contains this.
#   SET_PAYMENT_DEFAULT=true
#                           set paymentDefaultDuration on markets that already
#                           exist. Needs PAYMENT_DEFAULT_SECONDS.
#   PAYMENT_DEFAULT_SECONDS=<n>
#                           the new grace period, in seconds.
#   PAYMENT_DEFAULT_MARKETS=<ids>
#                           comma-separated market ids, e.g. 1,2,3,4. Omitted
#                           means every market on the registry.
#   PAYMENT_DEFAULT_DRY_RUN=true
#                           with SET_PAYMENT_DEFAULT, print before/after and
#                           send nothing.
#   SET_MARKET_FEE_RECIPIENT=true
#                           point markets' marketplace fee at a new address.
#                           Needs MARKET_FEE_RECIPIENT and MARKET_FEE_MARKETS.
#   MARKET_FEE_RECIPIENT=<address>
#                           where the fee goes from now on.
#   MARKET_FEE_MARKETS=<ids>
#                           comma-separated market ids. Required: never swept
#                           across every market by default.
#   MARKET_FEE_DRY_RUN=true with SET_MARKET_FEE_RECIPIENT, print before/after
#                           and send nothing.
#   SWAP_VIA_LIFI=true      swap one ERC-20 for another from the deployer,
#                           routed by LI.FI, and stop. Needs SWAP_FROM, SWAP_TO
#                           and SWAP_AMOUNT. For funding a pool whose principal
#                           the deployer has no other way to acquire.
#   SWAP_FROM=<address>     token to sell. May be the native sentinel
#                           (0x0000...0000), which is how a wallet holding only
#                           gas buys its first token on a chain - HyperEVM's
#                           deployer arrived with 0.25 HYPE and nothing else.
#   SWAP_TO=<address>       token to buy.
#   SWAP_AMOUNT=<raw>       how much to sell, in the sold token's raw units.
#   SWAP_SLIPPAGE=<frac>    fractional tolerance, e.g. 0.03. Default 0.03.
#   SWAP_MIN_NATIVE_LEFT=<n>
#                           refuse to run if the wallet would be left with less
#                           than this much gas, in whole units. Default 5. On a
#                           chain whose gas token is the token being sold - Arc
#                           sells USDC and pays gas in it - this is the only
#                           thing standing between a swap and a stranded
#                           deployer.
#   SWAP_DRY_RUN=true       with SWAP_VIA_LIFI, print the route and send
#                           nothing.
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

# A sweep names the chains it visits, so requiring one more would be asking for
# a value nothing reads. Defaulted rather than made optional, because everything
# below this line assumes NETWORK is set.
if [ -n "${AUDIT_NETWORKS:-}" ]; then
  NETWORK="${NETWORK:-$(echo "$AUDIT_NETWORKS" | cut -d, -f1)}"
fi
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
    // Not everything in deployments/ is a contract. hardhat-deploy keeps its
    // own bookkeeping there as dotfiles (.migrations.json, .chainId), and this
    // repo writes receipts and Safe batches alongside them -
    // market-bootstrap.json, protocol-fee-safe-batch.json,
    // hypernative-safe-batch.json. Only named artifacts become manifest
    // entries, so only they can be missing from it.
    //
    // Recognised by shape rather than by a list of filenames. A list is a
    // thing someone has to remember to extend, and the failure when they do
    // not is this check refusing to publish a chain that is perfectly
    // complete - which reads exactly like the real thing it is here to catch.
    // A hardhat-deploy artifact has an address and an abi; nothing else here
    // has both.
    const onDisk = fs.readdirSync(dir)
      .filter((f) => f.endsWith(".json") && !f.startsWith("."))
      .filter((f) => {
        try {
          const a = JSON.parse(fs.readFileSync(path.join(dir, f), "utf8"));
          return typeof a.address === "string" && Array.isArray(a.abi);
        } catch {
          return false;
        }
      })
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
  #
  # The window is ten minutes rather than the 225s it used to be. 3.1.65 was
  # published successfully and took between five and eight minutes to appear
  # on the registry, so the old window expired on a publish that had worked
  # and the run died with the "nothing shipped" message below - which sends
  # whoever reads it to look for a staged package that does not exist. A
  # publish that has genuinely failed is still caught; it just costs longer
  # to say so, on a step that runs once per chain.
  PUBLISHED=""
  for attempt in $(seq 1 20); do
    PUBLISHED="$(npm view "$PKG@$NEXT" version 2>/dev/null || true)"
    [ "$PUBLISHED" = "$NEXT" ] && break
    sleep 30
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
    if ! PROBE_OUT="$(git push --dry-run \
      "https://x-access-token:${GITHUB_TOKEN}@github.com/${REPO_PATH}.git" \
      "$ARTIFACT_REFSPEC" 2>&1)"; then
      # git can echo the remote it was given, and the remote it was given has
      # the token in it. Redact before anything reaches a log.
      PROBE_OUT="$(printf '%s' "$PROBE_OUT" | sed -E 's#(https://)[^@ ]*@#\1***@#g')"
      # Two failures that look identical here and are not. A rejected
      # fast-forward means CONTRACTS_REF is *behind* $ARTIFACT_BRANCH, which
      # happens the moment anything merges to that branch after the pin was
      # set: the commit this container is standing on cannot push to a ref that
      # has already moved past it, and no token changes that. Reporting it as a
      # credential problem cost two deploy cycles and sent someone to rotate a
      # token that was working.
      case "$PROBE_OUT" in
      *non-fast-forward* | *"fetch first"* | *"remote contains work"* | *"behind its remote"*)
        fail "Cannot push to $ARTIFACT_BRANCH: this checkout ($(git rev-parse --short HEAD)) is behind it, so the artifact commit would not fast-forward. Repin CONTRACTS_REF to the head of $ARTIFACT_BRANCH, or set ARTIFACT_BRANCH to a branch this commit is not behind. The token is not the problem."
        ;;
      *)
        fail "GITHUB_TOKEN cannot push $REPO_PATH. Expired, scoped to another repo, or missing contents:write. git said: $(printf '%s' "$PROBE_OUT" | tr '\n' ' ')"
        ;;
      esac
    fi
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

  # Tags write artifacts too, and some of them are the only copy of something
  # nobody can reconstruct from the chain. hypernative-oracle:wire ends by
  # writing hypernative-safe-batch.json — the setOracle and addPauser calls a
  # signer has to import to switch the firewall on — and without this that file
  # exists only inside a container that is about to exit. The .migrations.json
  # entries matter less (the scripts are idempotent) but losing them means
  # every re-run re-derives work that was already done.
  prepare_artifact_push

  log "Deployer preflight on $NETWORK"
  yarn hh run --no-compile scripts/preflight-deployer.ts --network "$NETWORK" \
    || fail "Deployer preflight failed."

  log "Running tags [$RUN_TAGS] on $NETWORK"
  yarn hh deploy --network "$NETWORK" --tags "$RUN_TAGS"

  if [ "${PUSH_ARTIFACTS:-}" = "true" ]; then
    log "Committing artifacts to $ARTIFACT_BRANCH"
    push_artifacts "Run tags [$RUN_TAGS] on $NETWORK"
  fi

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
  #
  # And that is not a figure of speech: robinhood got a second short:STRATEGY
  # pool this way. The receipt entry existed - it had been committed by hand,
  # because prepare_artifact_push was refusing the run - but the container was
  # pinned to a commit from before that commit, so its checkout had a receipt
  # with no STRATEGY in it. A redeploy nobody asked for re-ran this branch with
  # PUSH_ARTIFACTS cleared, found no entry, and dutifully deployed a duplicate.
  #
  # Clearing PUSH_ARTIFACTS to get past a push problem is therefore not a
  # workaround, it is disabling the only thing that makes this branch
  # idempotent. It still has to be possible - the push can be broken for
  # reasons that have nothing to do with this chain - but it has to be said out
  # loud, per run, rather than inherited from whatever the service was last
  # set to.
  if [ "${BOOTSTRAP_DRY_RUN:-}" != "true" ] && \
     [ "${PUSH_ARTIFACTS:-}" != "true" ] && \
     [ "${ALLOW_UNRECORDED_BOOTSTRAP:-}" != "true" ]; then
    fail "BOOTSTRAP_MARKETS without PUSH_ARTIFACTS=true would create pools and record them nowhere, and the receipt is the only thing that stops the next run creating them again. Set PUSH_ARTIFACTS=true, or ALLOW_UNRECORDED_BOOTSTRAP=true if you have a way to commit deployments/$NETWORK/market-bootstrap.json yourself - and if you do, repin CONTRACTS_REF to that commit before this branch runs again."
  fi

  prepare_artifact_push

  log "Deployer preflight on $NETWORK"
  yarn hh run --no-compile scripts/preflight-deployer.ts --network "$NETWORK" \
    || fail "Deployer preflight failed."

  # Compare against "true" rather than using ${VAR:+...}, which expands on any
  # non-empty value — including the string "false", which would silently turn
  # a real run into a dry one.
  # Replacing a pool is how a parameter written in `initialize` gets changed -
  # the interest rate band above all, which no pool implementation exposes a
  # setter for. It is opt-in per key and never inferred, because deploying a
  # pool spends principal and splits liquidity across two addresses.
  BOOTSTRAP_ARGS=""
  [ -n "${REPLACE_POOLS:-}" ] && BOOTSTRAP_ARGS="--replace ${REPLACE_POOLS}"
  [ "${FORCE_REPLACE_POOLS:-}" = "true" ] && \
    BOOTSTRAP_ARGS="$BOOTSTRAP_ARGS --force-replace true"

  if [ "${BOOTSTRAP_DRY_RUN:-}" = "true" ]; then
    log "Bootstrap markets and pools on $NETWORK (dry run — nothing will be sent)"
    # shellcheck disable=SC2086
    yarn hh bootstrap-markets --network "$NETWORK" --dry-run true $BOOTSTRAP_ARGS
  else
    log "Bootstrap markets and pools on $NETWORK"
    # shellcheck disable=SC2086
    yarn hh bootstrap-markets --network "$NETWORK" $BOOTSTRAP_ARGS
  fi

  if [ "${PUSH_ARTIFACTS:-}" = "true" ] && [ "${BOOTSTRAP_DRY_RUN:-}" != "true" ]; then
    log "Committing bootstrap receipt to $ARTIFACT_BRANCH"
    push_artifacts "Add $NETWORK markets and lender pools"
  fi

  log "Done — $NETWORK (markets and pools)"
  exit 0
fi

# Liquidity into a Uniswap V3 pool, so its price is worth reading.
#
# The counterpart of GROW_ORACLE, and the half that is easy to skip: growing a
# pool's observation buffer makes its TWAP readable, not honest. A pool with
# three hundred slots and two dollars in it answers every window and answers
# them wrong. Depth is what makes arbitrage worth doing, and arbitrage is the
# only thing that keeps a pool tracking the asset it prices.
if [ "${SEED_UNIV3:-}" = "true" ]; then
  [ -n "${SEED_POOL:-}" ] || fail "SEED_UNIV3 is set but SEED_POOL is not."
  [ -n "${SEED_AMOUNT0:-}" ] || fail \
    "SEED_UNIV3 is set but SEED_AMOUNT0 is not. Refusing to guess a size."
  [ -n "${SEED_AMOUNT1:-}" ] || fail \
    "SEED_UNIV3 is set but SEED_AMOUNT1 is not. Refusing to guess a size."
  [ -n "${DEPLOYER_MNEMONIC:-}" ] || fail "DEPLOYER_MNEMONIC is not set."
  printf '%s' "$DEPLOYER_MNEMONIC" > mnemonic.secret
  chmod 600 mnemonic.secret
  trap 'rm -f mnemonic.secret' EXIT

  SEED_ARGS="--pool ${SEED_POOL} --amount0 ${SEED_AMOUNT0} --amount1 ${SEED_AMOUNT1}"
  [ -n "${SEED_POSITION_MANAGER:-}" ] && \
    SEED_ARGS="$SEED_ARGS --position-manager ${SEED_POSITION_MANAGER}"
  [ -n "${SEED_SLIPPAGE_BPS:-}" ] && \
    SEED_ARGS="$SEED_ARGS --slippage-bps ${SEED_SLIPPAGE_BPS}"
  # Same "true" comparison as every other rehearsal flag here.
  [ "${SEED_DRY_RUN:-}" = "true" ] && SEED_ARGS="$SEED_ARGS --dry-run true"

  log "Seeding ${SEED_POOL} on $NETWORK"
  # shellcheck disable=SC2086
  yarn hh seed-univ3-pool --network "$NETWORK" $SEED_ARGS

  log "Done — $NETWORK (seed)"
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

# Payment default duration, on markets that already exist.
#
# BOOTSTRAP_MARKETS cannot reconcile this. It skips any market already in
# market-bootstrap.json, so it only ever writes this value at creation time -
# and the receipt is an incomplete census anyway, because markets created
# before it existed appear nowhere in it. So this mode takes market ids
# directly (or enumerates the registry) and needs neither the receipt nor a
# config/chain-bootstrap entry, which is what lets it run on any chain rather
# than only the ones bootstrapped through that task.
if [ "${SET_PAYMENT_DEFAULT:-}" = "true" ]; then
  [ -d "deployments/$NETWORK" ] || fail \
    "SET_PAYMENT_DEFAULT needs deployments/$NETWORK in this checkout."
  [ -n "${PAYMENT_DEFAULT_SECONDS:-}" ] || fail \
    "SET_PAYMENT_DEFAULT is set but PAYMENT_DEFAULT_SECONDS is not. Refusing to guess a grace period."
  [ -n "${DEPLOYER_MNEMONIC:-}" ] || fail "DEPLOYER_MNEMONIC is not set."
  printf '%s' "$DEPLOYER_MNEMONIC" > mnemonic.secret
  chmod 600 mnemonic.secret
  trap 'rm -f mnemonic.secret' EXIT

  PAYMENT_DEFAULT_ARGS=""
  [ -n "${PAYMENT_DEFAULT_MARKETS:-}" ] && \
    PAYMENT_DEFAULT_ARGS="--markets ${PAYMENT_DEFAULT_MARKETS}"

  # Same "true" comparison as the bootstrap and price-cap dry runs, and for the
  # same reason: ${VAR:+...} expands on the string "false" and would send a run
  # meant to be a rehearsal.
  if [ "${PAYMENT_DEFAULT_DRY_RUN:-}" = "true" ]; then
    log "Set payment default duration on $NETWORK to ${PAYMENT_DEFAULT_SECONDS}s (dry run — nothing will be sent)"
    # shellcheck disable=SC2086
    yarn hh set-market-payment-default --network "$NETWORK" \
      --seconds "$PAYMENT_DEFAULT_SECONDS" --dry-run true $PAYMENT_DEFAULT_ARGS
  else
    log "Set payment default duration on $NETWORK to ${PAYMENT_DEFAULT_SECONDS}s"
    # shellcheck disable=SC2086
    yarn hh set-market-payment-default --network "$NETWORK" \
      --seconds "$PAYMENT_DEFAULT_SECONDS" $PAYMENT_DEFAULT_ARGS
  fi

  log "Done — $NETWORK (payment default duration)"
  exit 0
fi

# Point a market's marketplace fee somewhere other than its owner.
#
# A market with no fee recipient pays its owner, and every market the bootstrap
# creates is owned by the deployer - so without this the fee on every loan lands
# in a burner key. Market ids are required rather than defaulting to the whole
# registry: redirecting fees is a decision about specific markets.
if [ "${SET_MARKET_FEE_RECIPIENT:-}" = "true" ]; then
  [ -d "deployments/$NETWORK" ] || fail \
    "SET_MARKET_FEE_RECIPIENT needs deployments/$NETWORK in this checkout."
  [ -n "${MARKET_FEE_RECIPIENT:-}" ] || fail \
    "SET_MARKET_FEE_RECIPIENT is set but MARKET_FEE_RECIPIENT is not."
  [ -n "${MARKET_FEE_MARKETS:-}" ] || fail \
    "SET_MARKET_FEE_RECIPIENT is set but MARKET_FEE_MARKETS is not. Name the markets."
  [ -n "${DEPLOYER_MNEMONIC:-}" ] || fail "DEPLOYER_MNEMONIC is not set."
  printf '%s' "$DEPLOYER_MNEMONIC" > mnemonic.secret
  chmod 600 mnemonic.secret
  trap 'rm -f mnemonic.secret' EXIT

  if [ "${MARKET_FEE_DRY_RUN:-}" = "true" ]; then
    log "Set market fee recipient on $NETWORK markets ${MARKET_FEE_MARKETS} to ${MARKET_FEE_RECIPIENT} (dry run — nothing will be sent)"
    yarn hh set-market-fee-recipient --network "$NETWORK" \
      --recipient "$MARKET_FEE_RECIPIENT" --markets "$MARKET_FEE_MARKETS" --dry-run true
  else
    log "Set market fee recipient on $NETWORK markets ${MARKET_FEE_MARKETS} to ${MARKET_FEE_RECIPIENT}"
    yarn hh set-market-fee-recipient --network "$NETWORK" \
      --recipient "$MARKET_FEE_RECIPIENT" --markets "$MARKET_FEE_MARKETS"
  fi

  log "Done — $NETWORK (market fee recipient)"
  exit 0
fi

# Make a Uniswap V3 pool's TWAP readable.
#
# A pool priced off a TWAP needs its oracle pool to hold observations spanning
# the window asked for. A fresh pool ships with observationCardinality == 1, and
# one observation is not a history: observe([n,0]) succeeds only while that
# single observation happens to be older than n, so any swap makes the oracle
# unreadable for the next n seconds - and a pool whose oracle intermittently
# reverts is worse than one with a short window, because every borrow against it
# reverts too.
#
# Permissionless: increaseObservationCardinalityNext is callable by anyone, so
# this needs gas but not ownership of the pool. That is what lets Teller price
# against a market someone else made rather than seeding its own.
if [ "${GROW_ORACLE:-}" = "true" ]; then
  [ -n "${GROW_ORACLE_POOL:-}" ] || fail \
    "GROW_ORACLE is set but GROW_ORACLE_POOL is not."
  [ -n "${DEPLOYER_MNEMONIC:-}" ] || fail "DEPLOYER_MNEMONIC is not set."
  printf '%s' "$DEPLOYER_MNEMONIC" > mnemonic.secret
  chmod 600 mnemonic.secret
  trap 'rm -f mnemonic.secret' EXIT

  GROW_ARGS="--pool ${GROW_ORACLE_POOL}"
  [ -n "${GROW_ORACLE_TARGET:-}" ] && GROW_ARGS="$GROW_ARGS --target ${GROW_ORACLE_TARGET}"
  [ -n "${GROW_ORACLE_STEP:-}" ] && GROW_ARGS="$GROW_ARGS --step ${GROW_ORACLE_STEP}"
  # Same "true" comparison as every other rehearsal flag here.
  [ "${GROW_ORACLE_PROBE:-}" = "true" ] && GROW_ARGS="$GROW_ARGS --probe true"

  log "Growing the oracle buffer on ${GROW_ORACLE_POOL} ($NETWORK)"
  # shellcheck disable=SC2086
  yarn hh grow-oracle-cardinality --network "$NETWORK" $GROW_ARGS

  log "Done — $NETWORK (oracle buffer)"
  exit 0
fi

# Which pools can be over-borrowed against.
#
# A pool with maxPrincipalPerCollateralAmount == 0 believes its Uniswap TWAP
# without limit, and the direction an attacker pushes a TWAP is up, because
# collateral quoted too high borrows more than it is worth. So an uncapped pool
# holding real principal is the shape of the loss.
#
# Signs nothing and needs no deployer key - it runs on the public hardhat test
# mnemonic, because hardhat builds its accounts config at startup whether or
# not a task sends anything. That is what makes this safe to schedule.
#
# It enumerates from the factory's deployment log rather than from
# market-bootstrap.json, so it sees pools this repo did not create - hyperevm
# has fourteen live pools and no receipt at all, which is exactly the blind
# spot a monitor must not inherit.
if [ "${AUDIT_POOL_CAPS:-}" = "true" ] && [ -n "${AUDIT_NETWORKS:-}" ]; then
  # Every chain in one run.
  #
  # The single-network form below is for looking at one chain on purpose. This
  # is the scheduled form, and the difference that matters is the verdict: a
  # sweep that stopped at the first chain with a problem would report the
  # alphabetically-earliest incident and hide the rest, so each chain runs to
  # completion and the exit code is the union.
  printf '%s' 'test test test test test test test test test test test junk' > mnemonic.secret
  chmod 600 mnemonic.secret
  # SWEEP_DIR is expanded when the trap runs, not now, so one trap covers the
  # directory created below however the sweep ends - including the `fail` at the
  # bottom, which is the path that matters.
  trap 'rm -f mnemonic.secret; rm -rf "${SWEEP_DIR:-}"' EXIT

  SWEEP_ARGS=""
  [ -n "${AUDIT_MIN_AVAILABLE:-}" ] && SWEEP_ARGS="--min-available ${AUDIT_MIN_AVAILABLE}"
  [ -n "${AUDIT_DRIFT_PCT:-}" ] && SWEEP_ARGS="$SWEEP_ARGS --drift-pct ${AUDIT_DRIFT_PCT}"
  [ -n "${AUDIT_CHUNK:-}" ] && SWEEP_ARGS="$SWEEP_ARGS --chunk ${AUDIT_CHUNK}"
  [ -n "${AUDIT_MAX_REQUESTS:-}" ] && SWEEP_ARGS="$SWEEP_ARGS --max-requests ${AUDIT_MAX_REQUESTS}"
  [ -n "${AUDIT_PAUSE_MS:-}" ] && SWEEP_ARGS="$SWEEP_ARGS --pause ${AUDIT_PAUSE_MS}"
  [ -n "${AUDIT_OWNED_BY:-}" ] && SWEEP_ARGS="$SWEEP_ARGS --owned-by ${AUDIT_OWNED_BY}"

  SWEEP_DIR="$(mktemp -d)"
  SWEEP_BAD=""
  # Chains whose only uncapped pools belong to someone else. Reported and
  # posted exactly like the rest, but they do not fail the run: nobody here can
  # sign setMaxPrincipalPerCollateralAmount on a pool they do not own, and a
  # scheduled job that is red for ever over somebody else's pool stops being
  # read at all.
  SWEEP_EXTERNAL=""
  SWEEP_SKIPPED=""
  # Chains the audit could not read, kept apart from the ones it read and found
  # wanting. Both are non-zero exits and both belong in the alert, but calling
  # the second the first is a page that names a chain with no finding on it -
  # and, worse, says nothing about the chains nobody looked at.
  SWEEP_BLIND=""

  for AUDIT_NET in $(echo "$AUDIT_NETWORKS" | tr ',' ' '); do
    # Both checks, and the second is the one that matters: the audit throws when
    # a chain has no LenderCommitmentGroupFactory_V2, and this loop reads a
    # non-zero exit as "critical findings". Without this, every chain that
    # simply has no pools would page somebody - and an alert that cries wolf on
    # a schedule is worse than no alert, because it teaches people to close it.
    if [ ! -d "deployments/$AUDIT_NET" ]; then
      log "Skipping $AUDIT_NET: no deployments/$AUDIT_NET in this checkout"
      SWEEP_SKIPPED="$SWEEP_SKIPPED $AUDIT_NET"
      continue
    fi
    if [ ! -f "deployments/$AUDIT_NET/LenderCommitmentGroupFactory_V2.json" ]; then
      log "Skipping $AUDIT_NET: no LenderCommitmentGroupFactory_V2, so no pools to audit"
      SWEEP_SKIPPED="$SWEEP_SKIPPED $AUDIT_NET"
      continue
    fi
    log "Auditing pool price caps on $AUDIT_NET"
    # Written to a file and then printed, rather than piped through tee: a
    # pipeline's status is its last command's unless pipefail is set, and this
    # loop's whole purpose is to read the audit's exit code. Getting that wrong
    # would make the sweep report every chain clean for ever.
    # shellcheck disable=SC2086
    if yarn hh audit-pool-caps --network "$AUDIT_NET" $SWEEP_ARGS \
      > "$SWEEP_DIR/$AUDIT_NET.log" 2>&1; then
      # A clean exit is no longer only "clean". With --owned-by set, a chain
      # whose uncapped pools are all somebody else's exits zero and says so on
      # its verdict line, and the sweep still has to carry those findings into
      # the report - silence here would be the sweep hiding what the audit
      # deliberately printed.
      case "$(sed -n 's/^audit-verdict: //p' "$SWEEP_DIR/$AUDIT_NET.log" | tail -1)" in
        external*) SWEEP_EXTERNAL="$SWEEP_EXTERNAL $AUDIT_NET" ;;
      esac
    else
      # The audit's last line says which kind of non-zero this is. A run that
      # died before printing one - a 502 from the RPC, a scan that blew its
      # budget, an endpoint that serves no logs at all - never got far enough
      # to have a finding, so the absence of a verdict is itself the verdict.
      case "$(sed -n 's/^audit-verdict: //p' "$SWEEP_DIR/$AUDIT_NET.log" | tail -1)" in
        critical*) SWEEP_BAD="$SWEEP_BAD $AUDIT_NET" ;;
        *)         SWEEP_BLIND="$SWEEP_BLIND $AUDIT_NET" ;;
      esac
    fi
    cat "$SWEEP_DIR/$AUDIT_NET.log"
  done

  echo
  log "Sweep complete"
  [ -n "$SWEEP_SKIPPED" ] && echo "   not deployed here:$SWEEP_SKIPPED"

  if [ -z "$SWEEP_BAD" ] && [ -z "$SWEEP_BLIND" ] && [ -z "$SWEEP_EXTERNAL" ]; then
    echo "   every audited chain clean"
    rm -rf "$SWEEP_DIR"
    log "Done — pool cap sweep"
    exit 0
  fi

  [ -n "$SWEEP_BAD" ] && echo "   chains with critical findings:$SWEEP_BAD"
  [ -n "$SWEEP_EXTERNAL" ] && \
    echo "   chains with uncapped pools owned by others:$SWEEP_EXTERNAL"
  if [ -n "$SWEEP_BLIND" ]; then
    echo "   chains this run could NOT audit:$SWEEP_BLIND"
    echo "   (no verdict from those - they are unwatched, not clean; see their output above)"
  fi

  if [ -n "${AUDIT_SLACK_WEBHOOK:-}" ]; then
    # The CRITICAL lines themselves, not a count. An alert that says "3 pools"
    # and nothing else is one somebody has to come here to act on, and the
    # addresses and owners are the whole of the action.
    if [ -n "$SWEEP_BAD" ]; then
      SWEEP_TEXT="$(printf 'Pool cap audit: critical findings on%s\n' "$SWEEP_BAD")"
    elif [ -n "$SWEEP_BLIND" ]; then
      SWEEP_TEXT="$(printf 'Pool cap audit: no critical findings, but some chains could not be read\n')"
    else
      SWEEP_TEXT="$(printf 'Pool cap audit: nothing of ours uncapped\n')"
    fi
    for AUDIT_NET in $SWEEP_BAD; do
      SWEEP_TEXT="$SWEEP_TEXT
*$AUDIT_NET*
$(grep -E 'CRITICAL|Owners who must set it' "$SWEEP_DIR/$AUDIT_NET.log" | head -20)"
    done
    # Other people's uncapped pools, under their own heading. The money in them
    # is real and the addresses are the whole of the action for whoever owns
    # them, so they go in the post - just not as something we failed to do.
    if [ -n "$SWEEP_EXTERNAL" ]; then
      SWEEP_TEXT="$SWEEP_TEXT

:information_source: *uncapped, owned by others:*$SWEEP_EXTERNAL
Not ours to sign; listed so the owners can be told."
      for AUDIT_NET in $SWEEP_EXTERNAL; do
        SWEEP_TEXT="$SWEEP_TEXT
*$AUDIT_NET*
$(grep -E 'belong to someone else' "$SWEEP_DIR/$AUDIT_NET.log" | head -3)"
      done
    fi
    # Named, with the reason, and never folded in with the findings. A chain
    # that could not be read is the one thing this report cannot reassure
    # anybody about, so it says so in its own words rather than borrowing the
    # word "critical" from a pool it never saw.
    if [ -n "$SWEEP_BLIND" ]; then
      SWEEP_TEXT="$SWEEP_TEXT

:warning: *could not audit:*$SWEEP_BLIND
These chains are unwatched this run, not clean."
      for AUDIT_NET in $SWEEP_BLIND; do
        SWEEP_TEXT="$SWEEP_TEXT
*$AUDIT_NET* $(grep -E '^(Error|HardhatError|ProviderError|.*scan budget spent)' "$SWEEP_DIR/$AUDIT_NET.log" | head -2 | tr '\n' ' ' | cut -c1-220)"
      done
    fi
    # Built by jq so a pool address or an owner can never break the JSON.
    if command -v jq >/dev/null 2>&1; then
      jq -n --arg text "$SWEEP_TEXT" '{text: $text}' > "$SWEEP_DIR/slack.json"
      curl -sS -X POST -H 'Content-Type: application/json' \
        --data @"$SWEEP_DIR/slack.json" "$AUDIT_SLACK_WEBHOOK" >/dev/null \
        && echo "   posted to Slack" \
        || echo "!! could not post to Slack; the findings are above"
    else
      echo "!! jq is not installed, so the Slack post was skipped; the findings are above"
    fi
  fi

  rm -rf "$SWEEP_DIR"
  # Non-zero either way: the scheduler's own failure notification is the second
  # alert, and the one that still arrives if the webhook is wrong. A chain that
  # could not be read earns it as squarely as a chain with an uncapped pool -
  # the whole point of the job is to be able to say, and this run could not.
  if [ -n "$SWEEP_BAD" ] && [ -n "$SWEEP_BLIND" ]; then
    fail "pool cap audit found critical findings on$SWEEP_BAD; could not audit$SWEEP_BLIND"
  elif [ -n "$SWEEP_BAD" ]; then
    fail "pool cap audit found critical findings on$SWEEP_BAD"
  elif [ -n "$SWEEP_BLIND" ]; then
    fail "pool cap audit could not audit$SWEEP_BLIND"
  fi

  # Only other people's uncapped pools left. Reported above and posted to
  # Slack, but a zero exit: there is no action on this side to fail at.
  log "Done — pool cap sweep (nothing of ours uncapped)"
  exit 0
fi

if [ "${AUDIT_POOL_CAPS:-}" = "true" ]; then
  [ -d "deployments/$NETWORK" ] || fail \
    "AUDIT_POOL_CAPS needs deployments/$NETWORK in this checkout to find the pool factory."
  printf '%s' 'test test test test test test test test test test test junk' > mnemonic.secret
  chmod 600 mnemonic.secret
  trap 'rm -f mnemonic.secret' EXIT

  AUDIT_ARGS=""
  [ -n "${AUDIT_MIN_AVAILABLE:-}" ] && AUDIT_ARGS="--min-available ${AUDIT_MIN_AVAILABLE}"
  [ -n "${AUDIT_DRIFT_PCT:-}" ] && AUDIT_ARGS="$AUDIT_ARGS --drift-pct ${AUDIT_DRIFT_PCT}"
  [ -n "${AUDIT_FROM_BLOCK:-}" ] && AUDIT_ARGS="$AUDIT_ARGS --from-block ${AUDIT_FROM_BLOCK}"
  [ -n "${AUDIT_CHUNK:-}" ] && AUDIT_ARGS="$AUDIT_ARGS --chunk ${AUDIT_CHUNK}"
  [ -n "${AUDIT_MAX_REQUESTS:-}" ] && AUDIT_ARGS="$AUDIT_ARGS --max-requests ${AUDIT_MAX_REQUESTS}"
  [ -n "${AUDIT_PAUSE_MS:-}" ] && AUDIT_ARGS="$AUDIT_ARGS --pause ${AUDIT_PAUSE_MS}"
  [ -n "${AUDIT_POOLS:-}" ] && AUDIT_ARGS="$AUDIT_ARGS --pools ${AUDIT_POOLS}"
  [ "${AUDIT_JSON:-}" = "true" ] && AUDIT_ARGS="$AUDIT_ARGS --json true"

  log "Auditing pool price caps on $NETWORK"
  # No `|| fail` wrapper: the task's own non-zero exit is the alert, and its
  # message already names the pools and the owners who must act.
  # shellcheck disable=SC2086
  yarn hh audit-pool-caps --network "$NETWORK" $AUDIT_ARGS

  log "Done — $NETWORK (pool cap audit)"
  exit 0
fi

# Take the deployer's own deposit back out of a pool.
#
# The counterpart of activate-pools, which puts the owner's first deposit into
# every listed pool and never had a way to collect it. That did not matter until
# a pool had to be replaced: repricing one means deploying another, and the
# deposit that opened the old one is then sitting in a pool nothing lists.
#
# The task only ever redeems the deployer's own shares - redeeming is
# `msg.sender == owner` on the pool - so this cannot reach a lender's position.
if [ "${REDEEM_POOL:-}" = "true" ]; then
  [ -d "deployments/$NETWORK" ] || fail \
    "REDEEM_POOL needs deployments/$NETWORK in this checkout to look a pool key up in."
  [ -n "${REDEEM_POOL_KEY:-}${REDEEM_POOL_ADDRESS:-}" ] || fail \
    "REDEEM_POOL is set but neither REDEEM_POOL_KEY nor REDEEM_POOL_ADDRESS is."
  [ -n "${DEPLOYER_MNEMONIC:-}" ] || fail "DEPLOYER_MNEMONIC is not set."
  printf '%s' "$DEPLOYER_MNEMONIC" > mnemonic.secret
  chmod 600 mnemonic.secret
  trap 'rm -f mnemonic.secret' EXIT

  REDEEM_ARGS=""
  [ -n "${REDEEM_POOL_KEY:-}" ] && REDEEM_ARGS="--key ${REDEEM_POOL_KEY}"
  [ -n "${REDEEM_POOL_ADDRESS:-}" ] && \
    REDEEM_ARGS="$REDEEM_ARGS --address ${REDEEM_POOL_ADDRESS}"
  [ -n "${REDEEM_POOL_SHARES:-}" ] && \
    REDEEM_ARGS="$REDEEM_ARGS --shares ${REDEEM_POOL_SHARES}"

  # Same "true" comparison as every other dry run here.
  if [ "${REDEEM_POOL_DRY_RUN:-}" = "true" ]; then
    log "Redeem deployer shares on $NETWORK (dry run — nothing will be sent)"
    # shellcheck disable=SC2086
    yarn hh redeem-pool-shares --network "$NETWORK" --dry-run true $REDEEM_ARGS
  else
    log "Redeem deployer shares on $NETWORK"
    # shellcheck disable=SC2086
    yarn hh redeem-pool-shares --network "$NETWORK" $REDEEM_ARGS
  fi

  log "Done — $NETWORK (redeem)"
  exit 0
fi

# One swap, from the deployer wallet, routed by LI.FI.
#
# Not part of any deploy. It exists because activating a LenderCommitmentGroup
# pool needs the owner's first deposit in that pool's *principal*, and an
# inverse pool's principal is the volatile asset - on Arc, ARGUS, which the
# deployer holds none of and has no other way to get. Every other funding route
# in this repo assumes a human at a bridge UI.
#
# Sends a transaction and touches no deployment, so it needs the key but not
# deployments/$NETWORK.
if [ "${SWAP_VIA_LIFI:-}" = "true" ]; then
  [ -n "${SWAP_FROM:-}" ] || fail "SWAP_VIA_LIFI is set but SWAP_FROM is not."
  [ -n "${SWAP_TO:-}" ] || fail "SWAP_VIA_LIFI is set but SWAP_TO is not."
  [ -n "${SWAP_AMOUNT:-}" ] || fail \
    "SWAP_VIA_LIFI is set but SWAP_AMOUNT is not. Refusing to guess a trade size."
  [ -n "${DEPLOYER_MNEMONIC:-}" ] || fail "DEPLOYER_MNEMONIC is not set."
  printf '%s' "$DEPLOYER_MNEMONIC" > mnemonic.secret
  chmod 600 mnemonic.secret
  trap 'rm -f mnemonic.secret' EXIT

  SWAP_ARGS=""
  [ -n "${SWAP_SLIPPAGE:-}" ] && SWAP_ARGS="--slippage ${SWAP_SLIPPAGE}"
  [ -n "${SWAP_MIN_NATIVE_LEFT:-}" ] && \
    SWAP_ARGS="$SWAP_ARGS --min-native-left ${SWAP_MIN_NATIVE_LEFT}"

  # Same "true" comparison as every other dry run here, and for the same
  # reason: ${VAR:+...} expands on the string "false" and would send a run
  # meant to be a rehearsal.
  if [ "${SWAP_DRY_RUN:-}" = "true" ]; then
    log "Swap $SWAP_AMOUNT of $SWAP_FROM for $SWAP_TO on $NETWORK (dry run — nothing will be sent)"
    # shellcheck disable=SC2086
    yarn hh swap-via-lifi --network "$NETWORK" \
      --from "$SWAP_FROM" --to "$SWAP_TO" --amount "$SWAP_AMOUNT" \
      --dry-run true $SWAP_ARGS
  else
    log "Swap $SWAP_AMOUNT of $SWAP_FROM for $SWAP_TO on $NETWORK"
    # shellcheck disable=SC2086
    yarn hh swap-via-lifi --network "$NETWORK" \
      --from "$SWAP_FROM" --to "$SWAP_TO" --amount "$SWAP_AMOUNT" $SWAP_ARGS
  fi

  log "Done — $NETWORK (swap)"
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
  # Non-fatal, the same way the full deploy treats it. check-verification exits
  # non-zero when anything is unverified, and on a new chain that is routinely
  # the libraries: Arc came back 17 of 26, the nine being libraries and plain
  # contracts that hardhat-verify cannot match rather than anything wrong with
  # the deployment. Letting that kill the job turns a report into an alert, and
  # the count it prints is already the signal.
  yarn hh run --no-compile scripts/check-verification.ts --network "$NETWORK" || \
    echo "!! Some contracts are not verified. The deployment itself is fine; re-run verify-all."
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
    SET_MARKET_FEE_RECIPIENT=true  send a market's fee to a new address
    RUN_TAGS=<tags>          run named deploy tags against a deployed chain
    VERIFY_ONLY=true         verify already-deployed contracts
    REDEEM_POOL=true         take the deployer's own deposit back out of a pool
    AUDIT_POOL_CAPS=true     report pools with no price cap (read-only, no key)
    AUDIT_NETWORKS=<names>   sweep several chains in one run, for a schedule
    GROW_ORACLE=true         grow a Uniswap V3 pool's TWAP observation buffer
    SEED_UNIV3=true          add full-range liquidity to a Uniswap V3 pool
    SWAP_VIA_LIFI=true       swap one ERC-20 for another from the deployer
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
if [ ! -f "$TIMELOCK_FILE" ]; then
  # Keep what pass 1 built before giving up. Without this the artifacts die
  # with the container and the next run deploys the whole protocol again from
  # scratch - which on Arc it did three times, ~89 transactions apiece, leaving
  # three orphaned copies and no record of any of them. A pass 1 that finished
  # is worth preserving even when the hand-off to pass 2 cannot happen.
  push_artifacts "Add $NETWORK deployment artifacts (pass 1, no timelock)"
  fail "Pass 1 finished but $TIMELOCK_FILE does not exist. Nothing to hand to pass 2.
     The artifacts from pass 1 have been pushed, so re-running resumes rather
     than redeploying. A chain missing from the allowlist in
     deploy/admin/timelock_controller.ts is the usual cause."
fi

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
