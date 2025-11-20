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

import { RewardRedeemer } from "../contracts/auxiliary/reward_redeemer.sol";


/*

 

*/

// https://dashboard.tenderly.co/teller/v2/simulator/new?block=36790450&from=0xbc1d2Ed14128Cd7Af450319b642Fd43d65E495dc&contractAddress=0x5cfD3aeD08a444Be32839bD911Ebecd688861164&rawFunctionInput=0x8288da8a000000000000000000000000000000000000000000000000000000000000060c&network=8453&blockIndex=0&gas=8000000&gasPrice=0&value=0&headerBlockNumber=&headerTimestamp=

contract MultiClaim_Fork_Test is Test {

    

      RewardRedeemer rewardRedeemer;

   
        
      using stdJson for string;
        
      function getDeployedAddress(  string memory contractName, string memory networkName ) internal view returns (address) {
          string memory root = vm.projectRoot();
          string memory path = string.concat(root, "/deployments/", networkName, "/", contractName, ".json");
          string memory json = vm.readFile(path);
          return json.readAddress(".address");
      }

  

     function test_claim_multi() public   {

        rewardRedeemer = RewardRedeemer( getDeployedAddress( "RewardRedeemer", "base" ) );


        address[] memory stakingContracts = new address[](1);

        stakingContracts[0] = 0xE9A11045dB982fc0975123Fa09c59BBb48ac2374; 
 

        vm.prank(0xD9B023522CeCe02251d877bb0EB4f06fDe6F98E6);  //andres wallet
          rewardRedeemer.claim_multi(
              stakingContracts
        );
 
     }




     function test_compound_multi() public   {

        rewardRedeemer = RewardRedeemer( getDeployedAddress( "RewardRedeemer", "base" ) );

        // Create AutoCompoundInputRow array
        RewardRedeemer.AutoCompoundInputRow[] memory autoCompoundInputRows =
            new RewardRedeemer.AutoCompoundInputRow[](1);

        // Configure the compound instruction
        // Staking contract: ThirdWeb staking contract
        // Teller pool: Compound pool (USDC) 
        autoCompoundInputRows[0] = RewardRedeemer.AutoCompoundInputRow(
            0xE9A11045dB982fc0975123Fa09c59BBb48ac2374,  // stakingContract
            0x32a2019490E14677b9260Ebe00a6A6E0C3582F93,  // tellerPool (Compound pool)
            0x1111111111166b7FE7bd91427724B487980aFc69   // rewardToken (Zora on Base)
        );

        vm.prank(0xD9B023522CeCe02251d877bb0EB4f06fDe6F98E6);  //andres wallet
          rewardRedeemer.compound_multi(
              autoCompoundInputRows
        );

     }


 
 
}