

# Teller Protocol Subgraph 


## NEW DOCS 


 1. build the subgraph using the graph-cli 

 ```

yarn build 
 ```



2. set network config ????

```
 await setNetworkConfig(subgraph.network, config);

```

3.  make sure code is copied over 

```
 yarn contracts export --network base
```

 
 4. run handlebars which will build the final  subgraph.yaml file ! 

```
 yarn hbs -D ./config/${subgraph.network}.json ./src/subgraph.handlebars -o . -e yaml
 
  yarn hbs -D ./config/mainnet.json ./src/subgraph.handlebars -o . -e yaml

 yarn hbs -D ./config/arbitrum-one.json ./src/subgraph.handlebars -o . -e yaml
 
  yarn hbs -D ./config/base.json ./src/subgraph.handlebars -o . -e yaml

   yarn hbs -D ./config/polygon.json ./src/subgraph.handlebars -o . -e yaml


   yarn hbs -D ./config/optimism.json ./src/subgraph.handlebars -o . -e yaml


   yarn hbs -D ./config/katana.json ./src/subgraph.handlebars -o . -e yaml

 yarn hbs -D ./config/hyperevm.json ./src/subgraph.handlebars -o . -e yaml
 

```
 


4.1.  ( make sure graft base is OK -- in subgraph / config {{ networkname.json }} )

 


5. auth 

graph auth 

graph codegen && graph build



6. deploy ! 

 graph deploy   teller-pools-base --version-label 0.4.21.1

 graph deploy   teller-pools-arbitrum --version-label 0.4.21.1


 graph deploy   teller-v-2-katana --version-label 0.4.21-22
 graph deploy   teller-v-2-polygon --version-label 0.4.21-25

graph deploy   teller-v-2-optimism --version-label 0.4.21-19


 



 


### Deploy to Alchemy 



```


graph deploy tellerv2-polygon \
  --version-label 0.4.21 \
  --node https://subgraphs.alchemy.com/api/subgraphs/deploy \
  --deploy-key ${ALCHEMY_SUBGRAPH_DEPLOY_KEY} \
  --ipfs https://ipfs.satsuma.xyz

```





### Deploy to Goldsky 


```
graph build     (builds the yaml file in  /build/   ?  not in root  ) 


goldsky subgraph deploy teller-v2-hyperevm/0.4.21.5



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