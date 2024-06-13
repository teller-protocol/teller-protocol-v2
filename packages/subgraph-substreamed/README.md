### Lender Groups Substreams


https://www.google.com/search?client=ubuntu&channel=fs&q=substream+rust+docs

https://docs.rs/substreams/latest/substreams/store/index.html

- use map-events 





What is the best way to architect this ??



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