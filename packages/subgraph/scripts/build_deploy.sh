#!/bin/bash

path=$(dirname "$0")

read -r -p 'Network name: ' network

"$path"/build.sh "$network" && "$path"/deploy.sh "$network"
