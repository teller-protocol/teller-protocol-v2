
### Manually build 
 Yarn contracts export --network polygon

 yarn subgraph hbs -D `./packages/subgraph/config/matic.json` -o . -e yaml
 yarn subgraph graph codegen

 yarn subgraph graph build 


 ### Deploying Manually
 yarn subgraph graph deploy --studio

-> see subgraph/config/{networkName} for name 
-> increment version from package.json 