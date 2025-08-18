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

contract SwapRollover_Fork_Test is Test {

    string constant NETWORK_NAME = "base";
    
    SwapRolloverLoan swapRolloverLoan;
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
          address payable swapRolloverAddr = payable(getDeployedAddress(  "SwapRolloverLoan"));
          swapRolloverLoan = SwapRolloverLoan(swapRolloverAddr);

          assertTrue(swapRolloverAddr.code.length > 0, "could not connect to swap rollover loan contract ") ;
      }


      function etch_SwapRolloverWithMock() public {

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


      }

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

    
 

     function test_SwapRollover_base() public   {

       // etch_SwapRolloverWithMock();

        // Define test parameters
        address smartCommitmentForwarderAddress = getDeployedAddress("SmartCommitmentForwarder");
        uint256 bidId = 1312; // Example loan ID - replace with actual loan ID
        uint256 borrowerAmount = 437109700492800; // Additional amount borrower adds
        
        // Flash swap parameters
        SwapRolloverLoan_G2.FlashSwapArgs memory flashSwapArgs = SwapRolloverLoan_G2.FlashSwapArgs({
            token0: address(0x1bc0c42215582d5A085795f4baDbaC3ff36d1Bcb),  
            token1: address(0x4200000000000000000000000000000000000006), 
            fee: 10000, //  
            flashAmount: 16865234336302306,  
            borrowToken1: false // Borrow token0 (DAI)
        });
        
        // Accept commitment parameters
        SwapRolloverLoan_G2.AcceptCommitmentArgs memory acceptCommitmentArgs = SwapRolloverLoan_G2.AcceptCommitmentArgs({
            commitmentId: 0,
            smartCommitmentAddress: address(0xa42922b1d5bd7f72337eBC4f39Ff4E1302ec8D53),  
            principalAmount: 16806947581558203,
            collateralAmount: 996554071232877,
            collateralTokenId: 0,
            collateralTokenAddress: address(0x4200000000000000000000000000000000000006), 
            interestRate: 3481, 
            loanDuration: 604800,
            merkleProof: new bytes32[](0) // No merkle proof
        });
        
        vm.prank(0xbc1d2Ed14128Cd7Af450319b642Fd43d65E495dc);  //andres wallet 
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