### Lender Groups Substreams




- use map-events 


-- Uniswap Example 
https://github.com/streamingfast/substreams-uniswap-v3/blob/develop/src/rpc.rs



### Adding a new custom output type 

> Add it to contract proto ? 





### Building 


```

make && make pack

```



### Individual build commands 
> run proto gen (to output RUST ) 


```
 make protogen 
```

```
 make gui  (visualize)  
```


> Create a substreams spkg 

```
substreams pack ./substreams.yaml
```


#### DEPLOYING 

graph auth --studio  <KEY>
 graph deploy --studio tellerv2-lender-groups-polygon
 
 0.4.21.55