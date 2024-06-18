### Lender Groups Substreams


https://www.google.com/search?client=ubuntu&channel=fs&q=substream+rust+docs

https://docs.rs/substreams/latest/substreams/store/index.html

- use map-events 





Example: https://github.com/Dirt-Nasty/lender-groups-subgraph-substream/blob/83120e376907a1c585d1dc216be8a4ef98675506/src/lib.rs



What is the best way to architect this ??



  - When you use STORES, you want to use a DELTA type typically so you only pass along the   (key,value) pairs from THIS block to the next module(s)
  - When you use STOERS you typically want to use a PRIMITIVE type as opposed to a Struct(protobuf) so that you can use an ADD type 
  
  - you have to do very special custom key mgmt kind of like workign with a REDIS store 
  
  - you dont need db_out at all , just use graph_out 
  
  
  - the graph_out is ONLY able to output directives to the POSTGRES db, it cannot read from the POSTGRES db 
   





I want to: 


have a Store of  LenderGroupMetrics   which i can use to read and save   LenderGroupMetricDataPoints !! 




PROBLEMS: 

How do i populate LenderGroupMetrics?


- i can start simple and dumb by first ONLY populating it when the group initialized trigger happens.. ???







### Adding a new custom output type 

> Add it to contract proto ? 

substreams protogen 



### Building 


> Run makefile 

```
make 
```


> Create a substreams spkg 

```
substreams pack ./substreams.yaml
```



### Deploying 


yarn deploy:prompt 