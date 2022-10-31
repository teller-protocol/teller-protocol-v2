#!/bin/bash

network=$1

# Set a postfix for the graph name to deploy
if [ -n "$2" ]; then
  postfix="-$2"
fi

# Deploy the subgraph and upload to IPFS
if [ "$network" = "mainnet" ]; then
  yarn graph deploy --studio "tellerv2-$network"
else
  yarn graph deploy \
    --product hosted-service \
    --node https://api.thegraph.com/deploy/ \
    "teller-protocol/tellerv2-$network$postfix"
fi
