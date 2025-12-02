// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "../tests/util/FoundryTest.sol";
import "forge-std/console.sol";
import "forge-std/StdJson.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/Vm.sol";


// Import your actual contracts
import { TellerV2 } from "../contracts/TellerV2.sol";
import { SwapRolloverLoan } from "../contracts/LenderCommitmentForwarder/extensions/rollover/SwapRolloverLoan.sol";
import { SwapRolloverLoan_G1 } from "../contracts/LenderCommitmentForwarder/extensions/rollover/SwapRolloverLoan_G1.sol";
import { SwapRolloverLoan_G2 } from "../contracts/LenderCommitmentForwarder/extensions/rollover/SwapRolloverLoan_G2.sol";

import {  MockSwapRolloverLoan } from "../contracts/mock/SwapRolloverLoanMock.sol";

contract MultiSourceBorrow_Fork_Test is Test {

    string constant NETWORK_NAME = "base";
    
    MultiSourceBorrow multiSourceBorrow;
       

       using stdJson for string;
       //put this in a util ?? 
      function getDeployedAddress(  string memory contractName) internal view returns (address) {
          string memory root = vm.projectRoot();
          string memory path = string.concat(root, "/deployments/", NETWORK_NAME, "/", contractName, ".json");
          string memory json = vm.readFile(path);
          return json.readAddress(".address");
      }

      function setUp() public {


         multiSourceBorrow = new MultiSourceBorrow( tellerV2Address ) ;


         /*  address payable swapRolloverAddr = payable(getDeployedAddress(  "SwapRolloverLoan"));
          swapRolloverLoan = SwapRolloverLoan(swapRolloverAddr);

          assertTrue(swapRolloverAddr.code.length > 0, "could not connect to swap rollover loan contract ") ;

          */
      }


   /*   function etch_SwapRolloverWithMock() public {

            //all specific to hyperevm ! 
          address tellerV2Address = 0x90D08f8Df66dFdE93801783FF7A36876453DAE75;
          address uniswapFactoryAddress = 0xFf7B3e8C00e57ea31477c32A5B52a58Eea47b072 ; 
          address weth9Address = 0x1fbcCdc677c10671eE50b46C61F0f7d135112450 ; 

            // Create a mock contract first
          MockSwapRolloverLoan mockSwapRolloverLoan = new MockSwapRolloverLoan(

                tellerV2Address,
                uniswapFactoryAddress,
                weth9Address

            );
          // Then replace the code at the deployed address
          vm.etch( address(swapRolloverLoan) , address(mockSwapRolloverLoan).code );


      }*/
 
 

     function test_MultiSourceBorrow_forked() public   {
        
        /* 


        // Define test parameters
        address smartCommitmentForwarderAddress = getDeployedAddress("SmartCommitmentForwarder");
        uint256 bidId = 0; // Example loan ID - replace with actual loan ID
        uint256 borrowerAmount = 4581; // Additional amount borrower adds
        
        // Flash swap parameters
        SwapRolloverLoan_G2.FlashSwapArgs memory flashSwapArgs = SwapRolloverLoan_G2.FlashSwapArgs({
            token0: address(0x5555555555555555555555555555555555555555),  
            token1: address(0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb), 
            fee: 500, //  
            flashAmount: 422068,  
            borrowToken1: true // Borrow token0 (DAI)
        });
        
        // Accept commitment parameters
        SwapRolloverLoan_G2.AcceptCommitmentArgs memory acceptCommitmentArgs = SwapRolloverLoan_G2.AcceptCommitmentArgs({
            commitmentId: 0,
            smartCommitmentAddress: address(0xd1174957123B9645d7E95d5e0b93ebeb729Ff67f),  
            principalAmount: 422350,
            collateralAmount: 19893118616829598,
            collateralTokenId: 0,
            collateralTokenAddress: address(0x5555555555555555555555555555555555555555), 
            interestRate: 6319, 
            loanDuration: 604800,
            merkleProof: new bytes32[](0) // No merkle proof
        });
        
        // Get Andre's wallet address
        address andresWallet = 0xbc1d2Ed14128Cd7Af450319b642Fd43d65E495dc;

        // Get the principal token (token1)
        IERC20 principalToken = IERC20(0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb);

        // Log balance before rollover
        uint256 balanceBefore = principalToken.balanceOf(andresWallet);
        console.log("Principal token balance BEFORE rollover:", balanceBefore);

        vm.prank(andresWallet);  //andres wallet
        swapRolloverLoan.rolloverLoanWithFlashSwap(
            smartCommitmentForwarderAddress, 
            bidId,
            borrowerAmount,
            flashSwapArgs,
            acceptCommitmentArgs 
        );

        // Log balance after rollover
        uint256 balanceAfter = principalToken.balanceOf(andresWallet);
        console.log("Principal token balance AFTER rollover:", balanceAfter);

        // Log the difference
        if (balanceAfter > balanceBefore) {
            console.log("Principal token GAINED:", balanceAfter - balanceBefore);
        } else if (balanceBefore > balanceAfter) {
            console.log("Principal token SPENT:", balanceBefore - balanceAfter);
        } else {
            console.log("Principal token balance UNCHANGED");
        }

        // Add assertions to verify the rollover worked
        // assertTrue(someCondition, "Rollover should succeed");


        */ 
     }




 



}