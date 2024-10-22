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

make && make build && make pack 


graph auth --studio  
 graph deploy --studio tellerv2-accounting
 
 0.4.21.19





 ### HOW THINGS WORK UNDER THE HOOD

 When deploying to a subgraph, the config file  substreams.subgraph.yaml is used.  
 When you are doing tables.create_row,  that data must match what it is in  schema.graphql ! 