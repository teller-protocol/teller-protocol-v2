pragma solidity >=0.8.0 <0.9.0;
 

import { Script } from "forge-std/Script.sol";
import {ReputationManager} from "../contracts/ReputationManager.sol"; 
import {MetaForwarder} from "../contracts/MetaForwarder.sol"; 
import {LenderCommitmentForwarder} from "../contracts/LenderCommitmentForwarder.sol"; 
import {CollateralEscrowV1} from "../contracts/escrow/CollateralEscrowV1.sol";  
import {CollateralManager} from "../contracts/CollateralManager.sol"; 
import {TellerV2} from "../contracts/TellerV2.sol"; 

import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract DeployTellerV2 is Script { 
    ReputationManager internal reputationManager;
    MetaForwarder internal trustedForwarder;
    LenderCommitmentForwarder internal lenderCommitmentForwarder;
    CollateralEscrowV1 internal collateralEscrowV1;
    UpgradeableBeacon internal collateralEscrowBeacon;
    CollateralManager internal collateralManager;
    TellerV2 internal tellerV2;


    uint16 protocolFee = 300;
 

      function run(address marketRegistry) public returns (address){        
        reputationManager = new ReputationManager();
        trustedForwarder = new MetaForwarder();
        trustedForwarder.initialize();

        tellerV2 = new TellerV2(address(trustedForwarder));

        lenderCommitmentForwarder = new LenderCommitmentForwarder(address(tellerV2),address(marketRegistry));

        reputationManager.initialize(address(tellerV2));
        
        collateralEscrowV1 = new CollateralEscrowV1();
        collateralEscrowBeacon = new UpgradeableBeacon(address(collateralEscrowV1));

        collateralManager = new CollateralManager();
        collateralManager.initialize(address(collateralEscrowBeacon),address(tellerV2));
        
        address[] memory lendingTokens = _getTokens();

        tellerV2.initialize(
          protocolFee,
          address(marketRegistry),
          address(reputationManager),
          address(lenderCommitmentForwarder),
          lendingTokens,
          address(collateralManager)
        );

        return address(tellerV2);
    }


    function _getTokens() public view returns (address[] memory){
      //if chainId == 1 

      address[] memory tokens = new address[](16);


      uint256 chainId = block.chainid;
      if(chainId == 1){ 
 
        tokens.push(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); //WETH

      }


      return tokens;

    }

}