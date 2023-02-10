pragma solidity >=0.8.0 <0.9.0;
 

import { Script } from "forge-std/Script.sol";
import "../contracts/ReputationManager.sol"; 
import "../contracts/MetaForwarder.sol"; 
import "../contracts/LenderCommitmentForwarder.sol"; 
import "../contracts/escrow/CollateralEscrowV1.sol";  
import "../contracts/CollateralManager.sol"; 

contract DeployTellerV2 is Script { 
    ReputationManager internal reputationManager;
    MetaForwarder internal trustedForwarder;
    LenderCommitmentForwarder internal lenderCommitmentForwarder;
    CollateralEscrow internal collateralEscrowV1;
    CollateralEscrowBeacon internal collateralEscrowBeacon;
    CollateralManager internal collateralManager;
 

      function run(address marketRegistry) public returns (address){        
        reputationManager = new ReputationManager();
        trustedForwarder = new TrustedForwarder();
        trustedForwarder.initialize();

        tellerV2 = new TellerV2(address(trustedForwarder));

        lenderCommitmentForwarder = new LenderCommitmentForwarder(address(tellerV2),address(marketRegistry));

        reputationManager.initialize();
        
        collateralEscrowV1 = new CollateralEscrowV1();
        collateralEscrowBeacon = new CollateralEscrowBeacon(address(collateralEscrowV1));

        collateralManager = new CollateralManager();
        collateralManager.initialize(address(collateralEscrowBeacon),address(tellerV2));
        
        address[] memory lendingTokens = _getTokens();

        tellerV2.initialize(
          protocolFee,
          address(marketRegistry),
          address(reputationManager),
          address(lenderCommitmentForwarder),
          lendingTokens,
          collateralManager.address
        );

        return address(tellerV2);
    }


    function _getTokens() public view returns (address[] memory){
      //if chainId == 1 

      address[] memory tokens;


      uint256 chainId = block.chainId;
      if(chainId == 1){ 
 
        tokens.push(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); //WETH

      }


      return tokens;

    }

}