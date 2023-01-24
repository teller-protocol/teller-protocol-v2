#!/bin/bash

# First parameter defines the name of the network to use
network=$1

# Ensure a network name was given
if [ -z "$network" ]; then
  read -r -p 'Network name: ' network
fi

# Ensure the network name is valid
valid_networks=('localhost' 'polygon' 'mumbai' 'mainnet' 'goerli')
if ! echo "${valid_networks[@]}" | grep -q "\b$network\b"; then
  echo
  echo "Invalid network name provided: $network"
  echo "  Available options: ${valid_networks[*]}"
  echo
  exit 1
fi

# Define a map of network names as defined by The Graph
declare -A network_map
network_map[polygon]=matic

# Normalize network name as defined by The Graph
graph_network=$network
if [ -n "${network_map[$network]}" ]; then
  graph_network=${network_map[$network]}
fi

# Ensure the network config file is defined
network_config="config/$graph_network.json"
if ! test -f "$network_config"; then
  echo
  echo "No network config file defined: $network_config"
  echo
  exit 1
fi

# Export the deployed contracts config to the subgraph directory
yarn workspace @teller-protocol/v2-contracts export --network "$network" &&
  # Generate the subgraph definition
  yarn mustache "$network_config" src/subgraph.template.yaml > subgraph.yaml
  # Generate AssemblyScript types for the subgraph
  yarn graph codegen &&
  # Build the subgraph
  yarn graph build
