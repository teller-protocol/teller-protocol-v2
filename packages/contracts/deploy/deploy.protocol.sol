pragma solidity >=0.8.0 <0.9.0;

/*
See examples 
https://github.com/maple-labs/maple-core-v2/tree/main/scripts
https://github.com/dabit3/foundry-cheatsheet

TO DEPLOY:

yarn anvil (in other terminal)
yarn deploy 

*/

import { Script } from "forge-std/Script.sol";
import "./deploy.teller_as.sol";
import "./deploy.market_registry.sol";
import "./deploy.teller_v2.sol";
import "./deploy.tlr_token.sol";
import "./deploy.autopay.sol";
 

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract DeployBase is Script {
    address internal deployer; 

    TellerASRegistry internal tellerAsRegistry;

    function setUp() public virtual {
        string memory mnemonic = vm.envString("MNEMONIC");
        (deployer,) = deriveRememberKey(mnemonic, 0);
    }

    function run() public {        
      
        _deployProtocol();
       
    }


    function _deployProtocol() internal {

        DeployTellerAS deployTellerAS = new DeployTellerAS();
        DeployMarketRegistry deployMarketRegistry = new DeployMarketRegistry();
        DeployTellerV2 deployTellerV2 = new DeployTellerV2();
        DeployTlrToken deployTlrToken = new DeployTlrToken();
        DeployAutopay deployAutopay = new DeployAutopay();


        vm.broadcast(deployer);
        address _tellerAS = deployTellerAS.run();

        vm.broadcast(deployer);
        address _marketRegistry = deployMarketRegistry.run(_tellerAS);
        
        vm.broadcast(deployer);
        deployTellerV2.run(_marketRegistry);

        vm.broadcast(deployer);
        deployTlrToken.run();

        vm.broadcast(deployer);
        deployAutopay.run();
    }


 
}