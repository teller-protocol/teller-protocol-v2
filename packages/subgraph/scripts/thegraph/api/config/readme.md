
### How to use this folder 



#### Example studio.json file in this folder 

{
   "0x1a76339211668a6939e1d6D13AB902bBef5D9ebc": {   <---- public key of gnosis safe wallet 
      "deployKey":"1384...7294e81ae"    <--- deploy key from subgraph studio page ,
         "network": "mainnet" | "arbitrum-one"
   }
   
}


#### notes 

The scripts should add a cookie 'Cookie' to the object above .  It is an access token. 
This is used to the graphs websocket api. 
