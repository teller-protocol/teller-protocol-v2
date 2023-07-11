#!/bin/bash

# First parameter defines the name of the network to use
network=$1
# Second parameter defines the version strategy to deploy
version_strategy=$2

# Get the current version from package.json
current_version=$(node -p "require('./package.json').version")

# Ensure a network name was given
if [ -z "$network" ]; then
  read -r -p 'Network name: ' network
fi

bump_version() {
  # Ensure we get a new version from the user
  if [ -z "$version_strategy" ]; then
    read -r -p "Bump version (current: $current_version): (major | minor | patch | prerelease) " version_strategy
  fi

  # Bump the version in package.json
  yarn version "$version_strategy"

  # Get the updated version from package.json
  new_version=$(node -p "require('./package.json').version")
}

# Deploy the subgraph and upload to IPFS
if [ "$network" = "mainnet" ]; then
  bump_version
  yarn graph deploy --studio "tellerv2-$network" --version-label "v$new_version"
else
  yarn graph deploy \
    --product hosted-service \
    --node https://api.thegraph.com/deploy/ \
    "teller-protocol/tellerv2-$network-test"
fi
