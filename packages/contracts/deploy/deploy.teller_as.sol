pragma solidity >=0.8.0 <0.9.0;
 

import { Script } from "forge-std/Script.sol";
import "../contracts/EAS/TellerASRegistry.sol";
import "../contracts/EAS/TellerASEIP712Verifier.sol";
import "../contracts/EAS/TellerAS.sol";
 
contract DeployTellerAS is Script { 
    TellerASRegistry internal tellerAsRegistry;
    TellerASEIP712Verifier internal tellerASEIP712Verifier;
    TellerAS internal tellerAS;

      function run() public returns (address){        
        tellerAsRegistry = new TellerASRegistry();
        tellerASEIP712Verifier = new TellerASEIP712Verifier();
        tellerAS = new TellerAS(tellerAsRegistry,tellerASEIP712Verifier);
    
        return address(tellerAS);
    }
}