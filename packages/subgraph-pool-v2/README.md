

# Teller Protocol Pools Subgraph 




### Templates 

Have to use data source templates to achieve the factory pattern ! 




## NEW DOCS 


 1. build the subgraph using the graph-cli 

 ```

npm run codegen && npm run build 
 ```


 
 
2. run handlebars which will build the final  subgraph.yaml file ! 

```
 
npm run generate mainnet


```
 
 



 
 ```

Deploy to THE GRAPH 


graph auth 


 graph deploy   teller-pools-v2-mainnet --version-label 0.4.21.4


 ```


 

```

## Deploy to alchemy 

graph deploy tellerv2-poolsv2-mainnet \
  --version-label 0.4.21.4 \
  --node https://subgraphs.alchemy.com/api/subgraphs/deploy \
  --deploy-key xxxxxx \
  --ipfs https://ipfs.satsuma.xyz



```


```

## Deploy to ormi labs 

npm run generate arbitrum

npm run codegen && npm run build 

 yarn deploy_ormi teller-pools-v2-mainnet 
 yarn deploy_ormi teller-pools-v2-base 
  yarn deploy_ormi teller-pools-v2-apechain 

```





``` 

deploy to goldsky 


npm run generate katana



npm run codegen && npm run build 


npm run generate hyperevm

goldsky subgraph deploy teller-pools-v2-hyperevm/0.4.21.2

goldsky subgraph deploy teller-pools-v2-katana/0.4.21.13


```















 ## OLD DOCS  ----


# Setup commands

**note: First make sure that docker is installed and running locally*

[https://docs.scaffoldeth.io/scaffold-eth/toolkit/infrastructure/the-graph](https://docs.scaffoldeth.io/scaffold-eth/toolkit/infrastructure/the-graph)

- *For linux users:*
    - *Install docker , docker-ce  ([https://docs.docker.com/engine/install/ubuntu/](https://docs.docker.com/engine/install/ubuntu/))*
    - *Elevate docker permissions (sudo chmod 666 /var/run/docker.sock)*

Terminal 1 - Hardhat contracts
- Install packages
```
yarn install
```
- Start local Hardhat chain
```
yarn chain --hostname 0.0.0.0
```
- Deploy contracts to localhost chain
```
yarn deploy --network localhost
```

Terminal 2 - Front end
- Start web app
```
yarn start
```

Terminal 3 - Graph node
- Clean/reset graph node
```
yarn clean-graph-node
```
- Run graph node
```
yarn run-graph-node
```

Terminal 4 - Subgraph deployment

- Generate types
```
yarn subgraph graph codegen
```
- Create subgraph
```
yarn subgraph create-local:polygon
```
- Deploy subgraph to node
```
yarn subgraph deploy-local:polygon
```



## Simplified Commands 

1. Build:  yarn subgraph build goerli

2. Deploy: yarn subgraph build:deploy goerli 