# Graph Protocol - Teller Sub Graph

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

## API Docs

[https://thegraph.com/docs/en/developer/graphql-api/](https://thegraph.com/docs/en/developer/graphql-api/)

## Graph-node Docker Image

[https://registry.hub.docker.com/r/graphprotocol/graph-node](https://registry.hub.docker.com/r/graphprotocol/graph-node)

## Unit Testing

[https://docs.scaffoldeth.io/scaffold-eth/toolkit/infrastructure/the-graph](https://docs.scaffoldeth.io/scaffold-eth/toolkit/infrastructure/the-graph)


### Git LFS 
Some deployment files are stored using LFS.  To fetch these, use the command 

- Fetch deployment files from git LFS 
```
 git lfs fetch --all

```