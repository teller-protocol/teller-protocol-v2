// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "../tests/util/FoundryTest.sol";
import "forge-std/console.sol";
import "forge-std/StdJson.sol";


// Import your actual contracts
import { TellerV2 } from "../contracts/TellerV2.sol";
import { SwapRolloverLoan } from "../contracts/LenderCommitmentForwarder/extensions/rollover/SwapRolloverLoan.sol";
import { SwapRolloverLoan_G1 } from "../contracts/LenderCommitmentForwarder/extensions/rollover/SwapRolloverLoan_G1.sol";
import { SwapRolloverLoan_G2 } from "../contracts/LenderCommitmentForwarder/extensions/rollover/SwapRolloverLoan_G2.sol";

import {  MockSwapRolloverLoan } from "../contracts/mock/SwapRolloverLoanMock.sol";
import { LenderCommitmentGroupFactory_V2 } from "../contracts/LenderCommitmentForwarder/extensions/LenderCommitmentGroup/LenderCommitmentGroup_Factory_V2.sol";
import { ILenderCommitmentGroup_V2 } from "../contracts/interfaces/ILenderCommitmentGroup_V2.sol";

 

import { UniswapPricingHelper } from "../contracts/price_oracles/UniswapPricingHelper.sol";

import { IUniswapPricingLibrary } from "../contracts/interfaces/IUniswapPricingLibrary.sol";

import { LenderCommitmentGroup_Pool_V2 } from "../contracts/LenderCommitmentForwarder/extensions/LenderCommitmentGroup/LenderCommitmentGroup_Pool_V2.sol";
import { SmartCommitmentForwarder } from "../contracts/LenderCommitmentForwarder/SmartCommitmentForwarder.sol";

/*

 

*/

// https://dashboard.tenderly.co/teller/v2/simulator/new?block=36790450&from=0xbc1d2Ed14128Cd7Af450319b642Fd43d65E495dc&contractAddress=0x5cfD3aeD08a444Be32839bD911Ebecd688861164&rawFunctionInput=0x8288da8a000000000000000000000000000000000000000000000000000000000000060c&network=8453&blockIndex=0&gas=8000000&gasPrice=0&value=0&headerBlockNumber=&headerTimestamp=

contract LiquidateBid_Fork_Test is Test {

    string constant NETWORK_NAME = "base";


     TellerV2 tellerV2;

    /*    
    SmartCommitmentForwarder scf;

    LenderCommitmentGroup_Pool_V2 pool;
 
      
     */
        
         using stdJson for string;
        
         function getDeployedAddress(  string memory contractName) internal view returns (address) {
          string memory root = vm.projectRoot();
          string memory path = string.concat(root, "/deployments/", NETWORK_NAME, "/", contractName, ".json");
          string memory json = vm.readFile(path);
          return json.readAddress(".address");
      }

  

     function test_loan_liquidate() public   {

        tellerV2 = TellerV2( getDeployedAddress("TellerV2") );

        


        vm.prank(0xbc1d2Ed14128Cd7Af450319b642Fd43d65E495dc);  //andres wallet
          tellerV2.liquidateLoanFull(
             1548
        );

        // Add assertions to verify the deployment worked
      //  assertTrue(deployedPool != address(0), "Pool should be deployed");
       // assertTrue(deployedPool.code.length > 0, "Deployed pool should have code");
     }


 
 
}