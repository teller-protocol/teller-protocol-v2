#!/bin/bash

path=$(dirname "$0")

# First parameter defines the name of the network to use
network=$1

# Ensure a network name was given
if [ -z "$network" ]; then
  read -r -p 'Network name: ' network
fi

"$path"/build.sh "$network" && "$path"/deploy.sh "$network"
