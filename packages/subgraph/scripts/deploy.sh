#!/bin/bash

# First parameter defines the name of the network to use
network=$1

# Ensure a network name was given
if [ -z "$network" ]; then
  read -r -p 'Network name: ' network
fi

studio_networks=("mainnet" "arbitrum")

is_studio=0

for ntwr in "${studio_networks[@]}"; do
    if [[ $ntwr == $network ]]; then
        is_studio=1
        break
    fi
done

# Deploy the subgraph and upload to IPFS
if [[ $is_studio -eq 1 ]]; then
  yarn graph deploy \
    "tellerv2-$network" \
    --studio
else
  yarn graph deploy \
    "teller-protocol/tellerv2-$network-test" \
    --product hosted-service
fi
