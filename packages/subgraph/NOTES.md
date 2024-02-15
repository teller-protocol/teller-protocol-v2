
### Manually build 
 Yarn contracts export --network polygon

 yarn subgraph hbs -D `./packages/subgraph/config/matic.json` -o . -e yaml
 yarn subgraph graph codegen

 yarn subgraph graph build 


 ### Deploying 

 Want to sync after LCF_A was deployed 