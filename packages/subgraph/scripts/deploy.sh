#!/bin/bash

# First parameter defines the name of the network to use
network=$1

# Ensure a network name was given
if [ -z "$network" ]; then
  read -r -p 'Network name: ' network
fi

# Deploy the subgraph and upload to IPFS
if [ "$network" = "mainnet" ]; then
  yarn graph deploy --studio "tellerv2-$network"
else
  yarn graph deploy \
    --product hosted-service \
    --node https://api.thegraph.com/deploy/ \
    "teller-protocol/tellerv2-$network"
fi
