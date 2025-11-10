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
import { IUniswapPricingLibrary } from "../contracts/interfaces/IUniswapPricingLibrary.sol";


/*


    Deploy a pool on v2 factory 


    initialPrincipalAmount: 1000000
config: [“0xb8ce59fc3717ada4c02eadf9682a9e934f625ebb”, “0x5555555555555555555555555555555555555555", “1”, 604800, 6000, 11000, 8000, 40000]
routes: [“0xbe352daf66af94ccf2012a154a67daef95facb91", true, 5, 18, 18] [“0x5d5bd83d0951a99036cdb986da8840acdf9e6085”, false, 5, 6, 18]
2:38
the pair is USDT0 <> WHYPE

*/

contract DeployPool_Fork_Test is Test {

    string constant NETWORK_NAME = "hyperevm";
    
    LenderCommitmentGroupFactory_V2 factoryv2;
   // address constant DEPLOYED_SWAP_ROLLOVER_LOAN = 0xa4A8c60Ac9E0c38f8B46316c6B3B508b3BA04415; // Replace with actual deployed address
        

       using stdJson for string;
       //put this in a util ?? 
      function getDeployedAddress(  string memory contractName) internal view returns (address) {
          string memory root = vm.projectRoot();
          string memory path = string.concat(root, "/deployments/", NETWORK_NAME, "/", contractName, ".json");
          string memory json = vm.readFile(path);
          return json.readAddress(".address");
      }

      function setUp() public {
          address payable factoryAddr = payable(getDeployedAddress(  "LenderCommitmentGroupFactory_V2" ));
          factoryv2 = LenderCommitmentGroupFactory_V2(factoryAddr);

          assertTrue(factoryAddr.code.length > 0, "could not connect to factory contract ") ;
      }


 /*     function etch_SwapRolloverWithMock() public {

            //all specific to katana ! 
          address tellerV2Address = 0xf7B14778035fEAF44540A0bC1D4ED859bCB28229;
          address uniswapFactoryAddress = 0x203e8740894c8955cB8950759876d7E7E45E04c1 ; 
          address weth9Address = 0xEE7D8BCFb72bC1880D0Cf19822eB0A2e6577aB62 ; 

            // Create a mock contract first
          MockSwapRolloverLoan mockSwapRolloverLoan = new MockSwapRolloverLoan(

                tellerV2Address,
                uniswapFactoryAddress,
                weth9Address

            );
          // Then replace the code at the deployed address
          vm.etch( address(swapRolloverLoan) , address(mockSwapRolloverLoan).code );


      }*/

/*
     function test_SwapRollover() public   {

        etch_SwapRolloverWithMock();

        // Define test parameters
        address smartCommitmentForwarderAddress = getDeployedAddress("SmartCommitmentForwarder");
        uint256 bidId = 4; // Example loan ID - replace with actual loan ID
        uint256 borrowerAmount = 0; // Additional amount borrower adds
        
        // Flash swap parameters
        SwapRolloverLoan_G1.FlashSwapArgs memory flashSwapArgs = SwapRolloverLoan_G1.FlashSwapArgs({
            token0: address(0x1e5eFCA3D0dB2c6d5C67a4491845c43253eB9e4e),  
            token1: address(0x203A662b0BD271A6ed5a60EdFbd04bFce608FD36), 
            fee: 3000, // 0.3% fee tier
            flashAmount: 1000, // 1000 tokens
            borrowToken1: false // Borrow token0 (DAI)
        });
        
        // Accept commitment parameters
        SwapRolloverLoan_G1.AcceptCommitmentArgs memory acceptCommitmentArgs = SwapRolloverLoan_G1.AcceptCommitmentArgs({
            commitmentId: 1,
            smartCommitmentAddress: address(0), // Not using smart commitment
            principalAmount: 1000,
            collateralAmount: 1200,
            collateralTokenId: 0,
            collateralTokenAddress: address(0x1e5eFCA3D0dB2c6d5C67a4491845c43253eB9e4e), 
            interestRate: 100, // 10% APR
            loanDuration: 15000,
            merkleProof: new bytes32[](0) // No merkle proof
        });
        
        vm.prank(0xbc1d2Ed14128Cd7Af450319b642Fd43d65E495dc);
        swapRolloverLoan.rolloverLoanWithFlashSwap(
            smartCommitmentForwarderAddress, 
            bidId,
            borrowerAmount,
            flashSwapArgs,
            acceptCommitmentArgs 
        );
        
        // Add assertions to verify the rollover worked
        // assertTrue(someCondition, "Rollover should succeed");
     }

*/

    
 

     function test_pool_deployment() public   {

        // Define commitment group configuration
        ILenderCommitmentGroup_V2.CommitmentGroupConfig memory config = ILenderCommitmentGroup_V2.CommitmentGroupConfig({
            principalTokenAddress: 0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb,
            collateralTokenAddress: 0x5555555555555555555555555555555555555555,
            marketId: 1,
            maxLoanDuration: 604800,
            interestRateLowerBound: 6000,
            interestRateUpperBound: 11000,
            liquidityThresholdPercent: 8000,
            collateralRatio: 40000
        });

        // Define pool oracle routes
        IUniswapPricingLibrary.PoolRouteConfig[] memory routes = new IUniswapPricingLibrary.PoolRouteConfig[](2);

        routes[0] = IUniswapPricingLibrary.PoolRouteConfig({
            pool: 0xbe352daF66af94ccF2012a154a67DAEF95FAcB91,
            zeroForOne: true,
            twapInterval: 5,
            token0Decimals: 18,
            token1Decimals: 18
        });

        routes[1] = IUniswapPricingLibrary.PoolRouteConfig({
            pool: 0x5d5BD83D0951A99036CDB986da8840ACdf9E6085,
            zeroForOne: false,
            twapInterval: 5,
            token0Decimals: 6,
            token1Decimals: 18
        });

        vm.prank(0xbc1d2Ed14128Cd7Af450319b642Fd43d65E495dc);  //andres wallet
        address deployedPool = factoryv2.deployLenderCommitmentGroupPool(
            1000000, // initialPrincipalAmount
            config,
            routes
        );

        // Add assertions to verify the deployment worked
        assertTrue(deployedPool != address(0), "Pool should be deployed");
        assertTrue(deployedPool.code.length > 0, "Deployed pool should have code");
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