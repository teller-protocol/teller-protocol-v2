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

Borrow from pool 

45700000000000001n
“0xbc1d2Ed14128Cd7Af450319b642Fd43d65E495dc”,
“0"
“0x5555555555555555555555555555555555555555”
“0xd1174957123b9645d7e95d5e0b93ebeb729ff67f”
“604800”
6511
967446n  


*/

contract DeployPool_Fork_Test is Test {

    string constant NETWORK_NAME = "hyperevm";
        
    SmartCommitmentForwarder scf;

    LenderCommitmentGroup_Pool_V2 pool;
   // address constant DEPLOYED_SWAP_ROLLOVER_LOAN = 0xa4A8c60Ac9E0c38f8B46316c6B3B508b3BA04415; // Replace with actual deployed address
        

       using stdJson for string;
        
         function getDeployedAddress(  string memory contractName) internal view returns (address) {
          string memory root = vm.projectRoot();
          string memory path = string.concat(root, "/deployments/", NETWORK_NAME, "/", contractName, ".json");
          string memory json = vm.readFile(path);
          return json.readAddress(".address");
      }


/*
      function setUp() public {
         address payable scfAddr = payable( getDeployedAddress("SmartCommitmentForwarder") );
         scf = SmartCommitmentForwarder( scfAddr );

          assertTrue(scfAddr.code.length > 0, "could not connect to scf contract ") ;


          address payable poolAddr = payable( 0xd1174957123B9645d7E95d5e0b93ebeb729Ff67f );
          pool = LenderCommitmentGroup_Pool_V2(poolAddr);

          assertTrue(poolAddr.code.length > 0, "could not connect to pool contract ") ;
      }
 */
 

     function test_pool_borrow() public   {

       
       uint256 principalAmount = 967446;
       uint256 collateralAmount = 45700000000000001;
        address collateralTokenAddress = 0x5555555555555555555555555555555555555555;
       address recipient = 0xbc1d2Ed14128Cd7Af450319b642Fd43d65E495dc;
       uint16 interestRate = 6511;
       uint32 loanDuration = 604800;


        vm.prank(0xbc1d2Ed14128Cd7Af450319b642Fd43d65E495dc);  //andres wallet
        uint256 res = scf.acceptSmartCommitmentWithRecipient(
            address(pool),
            principalAmount,
            collateralAmount,
            0, //collateral token id 
            collateralTokenAddress,
            recipient,
            interestRate,
            loanDuration 
        );

        // Add assertions to verify the deployment worked
      //  assertTrue(deployedPool != address(0), "Pool should be deployed");
       // assertTrue(deployedPool.code.length > 0, "Deployed pool should have code");
     }




     function etch_uniswap_pricing_helper() public {


           
             
          address pricingHelperAddress = 0x6B38aD36f17dd55bE44217d184DB8A01536aa104;
        
           
          UniswapPricingHelper newPricingHelper = new UniswapPricingHelper( );

          // Then replace the code at the deployed address
          vm.etch( address(pricingHelperAddress) , address(newPricingHelper).code );


      } 


        function etch_mog_pool() public {

            address tellerV2Address = 0x00182FdB0B880eE24D428e3Cc39383717677C37e;
            address scfAddress = 0x80314D77E86d70A67126DA86EC823F5fc018c010;
            address uniswapV3Factory = 0x1F98431c8aD98523631AE4a59f267346ea31F984 ;
            address uniswapPricingHelper = 0x6B38aD36f17dd55bE44217d184DB8A01536aa104;
            
             
          address poolAddress = 0x5F610ca9Ff0a0Ad9FbF91B8EB85A892fb0eBC620;
        
           
          LenderCommitmentGroup_Pool_V2 newPool = new LenderCommitmentGroup_Pool_V2(
            tellerV2Address,
            scfAddress,
            uniswapV3Factory,
            uniswapPricingHelper
          );

          // Then replace the code at the deployed address
          vm.etch( address(poolAddress) , address(newPool).code );


      } 




      function test_pool_collateral_calc() public   {

             etch_mog_pool();
           etch_uniswap_pricing_helper(); 




      address mog_pool_address = 0x5F610ca9Ff0a0Ad9FbF91B8EB85A892fb0eBC620;


        uint256 amt = LenderCommitmentGroup_Pool_V2( mog_pool_address ).
            calculateCollateralRequiredToBorrowPrincipal(

                    1000000
            );




      }



    
    /*
    function test_TellerV2State() public   {
        if (address(tellerV2) != address(0)) {
            // Test reading state from deployed contract
            try tellerV2.protocolFee() returns (uint16 fee) {
                console.log("Protocol fee:", fee);
                assertTrue(fee >= 0, "Fee should be non-negative");
            } catch {
                console.log("Failed to read protocol fee");
            }
        }
    }
    
    function test_TellerV2Interactions() public {
        if (address(tellerV2) != address(0)) {
            // You can test interactions with existing state
            // For example, check if certain markets exist, etc.
        }
    }*/
}