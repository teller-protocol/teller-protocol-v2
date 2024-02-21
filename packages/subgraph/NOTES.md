
### Manually build 
 Yarn contracts export --network polygon


*this works* 
yarn subgraph hbs ./src/subgraph.handlebars -D "./config/matic.json"  -o . -e yaml



 yarn subgraph graph codegen

 yarn subgraph graph build 


 ### Deploying Manually
 yarn subgraph graph deploy --studio

-> see subgraph/config/{networkName} for name  [tellerv2-polygon]
-> increment version from package.json 
