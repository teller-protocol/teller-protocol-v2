#!/bin/bash

cd /home/passa/Documents/projects/Teller/teller-protocol-v2/packages/contracts

network="polygon"
oz_file=".openzeppelin/$network.json"

cat $oz_file | jq '.admin.address' | tr -d '"' | while read addr; do
  file=$(grep -rl "$addr" "deployments/$network" | grep 'DefaultProxyAdmin.json')
  basename $file

  cat $file | jq '.receipt.transactionHash' | tr -d '"' | while read txHash; do
    jq ".admin += { \"txHash\": \"$txHash\" }" "$oz_file" > tmp.$$.json && mv tmp.$$.json "$oz_file"
  done

  echo '--'
done

i=0
cat $oz_file | jq '.proxies[].address' | tr -d '"' | while read addr; do
  file=$(grep -rl "$addr" "deployments/$network" | grep 'Proxy.json')
  basename $file

  cat $file | jq '.receipt.transactionHash' | tr -d '"' | while read txHash; do
    jq ".proxies[$i] += { \"txHash\": \"$txHash\" }" "$oz_file" > tmp.$$.json && mv tmp.$$.json "$oz_file"
    ((i++))
  done

  echo '--'
done

cat $oz_file | jq '.impls | to_entries | .[].key' | tr -d '"' | while read hash; do
  cat $oz_file | jq ".impls.\"$hash\".address" | tr -d '"' | while read addr; do
    file=$(grep -rl "$addr" "deployments/$network" | grep 'Implementation.json')
    basename $file

    cat $file | jq '.receipt.transactionHash' | tr -d '"' | while read txHash; do
      jq ".impls.\"$hash\" += { \"txHash\": \"$txHash\" }" "$oz_file" > tmp.$$.json && mv tmp.$$.json "$oz_file"
    done

    echo '--'
  done
done
