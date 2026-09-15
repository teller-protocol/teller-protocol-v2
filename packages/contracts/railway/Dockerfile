# Deploy runner for scripts/deploy-chain.sh.
#
# A one-shot job, not a service: it deploys a chain and exits. Set the Railway
# service's restart policy to NEVER (railway.json here does) — a restarting
# container would re-enter the deploy on every crash loop.
#
# Build context is the REPOSITORY ROOT, not this directory, because the yarn
# workspace resolves across packages/. On Railway set:
#   Root Directory   /
#   Dockerfile Path  packages/contracts/railway/Dockerfile

FROM node:20-bookworm-slim

# git: the artifact push writes deployments/ back to the branch.
# python3/make/g++: some transitive deps still build native addons.
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
       git ca-certificates python3 make g++ \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# The repo pins yarn 3.6.1 via packageManager and vendors it in .yarn/releases,
# so this needs no network fetch of yarn itself.
COPY .yarnrc.yml package.json yarn.lock ./
COPY .yarn/ .yarn/
RUN corepack enable && corepack prepare yarn@3.6.1 --activate

COPY . .

# Not --mode=skip-build: hardhat compiles Solidity at deploy time and wants the
# full toolchain present.
RUN yarn install --immutable

WORKDIR /app/packages/contracts

# NETWORK, DEPLOYER_MNEMONIC and SAFE_GLOBAL_API_KEY come from the Railway
# service variables. The script checks them before touching the chain.
CMD ["./scripts/deploy-chain.sh"]
