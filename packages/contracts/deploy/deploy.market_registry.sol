pragma solidity >=0.8.0 <0.9.0;
 

import { Script } from "forge-std/Script.sol";
import "../contracts/MarketRegistry.sol";
import "../contracts/EAS/TellerAS.sol";
 
contract DeployMarketRegistry is Script { 
    MarketRegistry internal marketRegistry; 

      function run(address tellerAS) public returns (address){         
        marketRegistry = new MarketRegistry();
        marketRegistry.initialize(TellerAS(tellerAS));

        return address(marketRegistry);
    }
}