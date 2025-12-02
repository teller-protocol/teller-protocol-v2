// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "../tests/util/FoundryTest.sol";
import "forge-std/console.sol";
import "forge-std/StdJson.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/Vm.sol";

// Import your actual contracts
import { TellerV2 } from "../contracts/TellerV2.sol";
import { MultiSourceBorrow } from "../contracts/LenderCommitmentForwarder/MultiSourceBorrow.sol";
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
          address tellerV2Address = getDeployedAddress("TellerV2");
          multiSourceBorrow = new MultiSourceBorrow(tellerV2Address);
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
 
 

     function test_MultiSourceBorrow_forked() public {
        // Define test parameters
        address commitmentForwarderAddress = getDeployedAddress("LenderCommitmentForwarder");
        address smartCommitmentForwarderAddress = getDeployedAddress("SmartCommitmentForwarder");

        // Accept commitment parameters
        MultiSourceBorrow.AcceptCommitmentArgs memory acceptCommitmentArgs = MultiSourceBorrow.AcceptCommitmentArgs({
            commitmentId: 0,
            smartCommitmentAddress: address(0), // Use standard LCF in this test
            principalAmount: 422350,
            collateralAmount: 19893118616829598,
            collateralTokenId: 0,
            collateralTokenAddress: address(0x5555555555555555555555555555555555555555),
            interestRate: 6319,
            loanDuration: 604800,
            merkleProof: new bytes32[](0)
        });

        // Borrower's wallet address
        address borrower = address(0xbc1d2Ed14128Cd7Af450319b642Fd43d65E495dc);
        address recipient = address(0xABCD000000000000000000000000000000000001);

        // Get the principal token
        IERC20 principalToken = IERC20(0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb);

        // Log balance before
        uint256 balanceBefore = principalToken.balanceOf(recipient);
        console.log("Recipient balance BEFORE acceptCommitment:", balanceBefore);

        vm.prank(borrower);
        uint256 bidId = multiSourceBorrow.acceptCommitmentWithMultiSource(
            commitmentForwarderAddress,
            acceptCommitmentArgs,
            address(0), // No pool withdrawal
            0,
            address(0), // No staking withdrawal
            0,
            recipient
        );

        // Log balance after
        uint256 balanceAfter = principalToken.balanceOf(recipient);
        console.log("Recipient balance AFTER acceptCommitment:", balanceAfter);
        console.log("Bid ID created:", bidId);

        // Log the difference
        if (balanceAfter > balanceBefore) {
            console.log("Recipient token GAINED:", balanceAfter - balanceBefore);
        } else if (balanceBefore > balanceAfter) {
            console.log("Recipient token SPENT:", balanceBefore - balanceAfter);
        } else {
            console.log("Recipient token balance UNCHANGED");
        }

        // Add assertions
        assertTrue(bidId > 0, "Bid ID should be created");
     }




 



}