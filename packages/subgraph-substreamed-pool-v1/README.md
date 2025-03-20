### Lender Groups Substreams




- use map-events 


-- Uniswap Example 
https://github.com/streamingfast/substreams-uniswap-v3/blob/develop/src/rpc.rs



### Adding a new custom output type 

> Add it to contract proto ? 





### Building 

> run proto gen (to output RUST ) 


```
substreams protogen 
```



> Create a substreams spkg 

```
substreams pack ./substreams.yaml
```


#### DEPLOYING 



1. make sure FACTORY_TRACKED_CONTRACT+COLLATERAL_MANAGER_TRACKED_CONTRACT in 'lib'  is defined properly for network 
2. make sure data in export_build.rs is defined properly for network (see https://thegraph.com/docs/en/supported-networks/ ) 


3. cargo run --bin exportbuild   //regenerate yaml files 
4. make && make build && make pack 


5. graph auth   (optional) 
6. graph deploy   tellerv2-lender-groups-mainnet --version-label 0.4.21.120
 
 0.4.21.120 


(  use graph deploy --studio    with old version of graph cli ) 


### graph names 

tellerv2-lender-groups-polygon  *
tellerv2-lender-groups-arbitrum *
tellerv2-lender-groups-base  * 
tellerv2-lender-groups-mainnet *






 ### CHECK THE STATUS 

 https://api.studio.thegraph.com/query/36377/tellerv2-lender-groups-polygon/0.4.21.103/graphql





 ### HOW THINGS WORK UNDER THE HOOD

 When deploying to a subgraph, the config file  substreams.subgraph.yaml is used.  
 When you are doing tables.create_row,  that data must match what it is in  schema.graphql ! 