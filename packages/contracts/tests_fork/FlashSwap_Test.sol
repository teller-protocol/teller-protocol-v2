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

contract SwapRollover_Fork_Test is Test {

    string constant NETWORK_NAME = "katana";
    
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
 
 

     function test_SwapRollover_forked() public   {

       // etch_SwapRolloverWithMock();

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

/*
    function test_replayTransaction() public {
      

        address smartCommitmentForwarderAddress = getDeployedAddress("SmartCommitmentForwarder");

          bytes memory tx_calldata = hex"0f29fee20000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011f70000000000000000000000005555555555555555555555555555555555555555000000000000000000000000b8ce59fc3717ada4c02eadf9682a9e934f625ebb00000000000000000000000000000000000000000000000000000000000001f400000000000000000000000000000000000000000000000000000000000670c5000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000001200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d1174957123b9645d7e95d5e0b93ebeb729ff67f00000000000000000000000000000000000000000000000000000000000671ce00000000000000000000000000000000000000000000000000465440a530220a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000555555555555555555555555555555555555555500000000000000000000000000000000000000000000000000000000000018af0000000000000000000000000000000000000000000000000000000000093a8000000000000000000000000000000000000000000000000000000000000001200000000000000000000000000000000000000000000000000000000000000000";

        // Decode the calldata (skip first 4 bytes which is the function selector)
        bytes memory params = new bytes(tx_calldata.length - 4);
        for (uint i = 4; i < tx_calldata.length; i++) {
            params[i - 4] = tx_calldata[i];
        }

        // Decode parameters using abi.decode
        (
            address decoded_smartCommitmentForwarderAddress,
            uint256 decoded_bidId,
            uint256 decoded_borrowerAmount,
            SwapRolloverLoan_G2.FlashSwapArgs memory decoded_flashSwapArgs,
            SwapRolloverLoan_G2.AcceptCommitmentArgs memory decoded_acceptCommitmentArgs
        ) = abi.decode(params, (
            address,
            uint256,
            uint256,
            SwapRolloverLoan_G2.FlashSwapArgs,
            SwapRolloverLoan_G2.AcceptCommitmentArgs
        ));

        console.log("=== Decoded Parameters ===");
        console.log("Smart Commitment Forwarder:", decoded_smartCommitmentForwarderAddress);
        console.log("Bid ID:", decoded_bidId);
        console.log("Borrower Amount:", decoded_borrowerAmount);
        console.log("Flash Swap token0:", decoded_flashSwapArgs.token0);
        console.log("Flash Swap token1:", decoded_flashSwapArgs.token1);
        console.log("Flash Swap fee:", decoded_flashSwapArgs.fee);
        console.log("Flash Amount:", decoded_flashSwapArgs.flashAmount);
        console.log("Borrow Token1:", decoded_flashSwapArgs.borrowToken1);

        // Impersonate the original caller
        vm.prank(0xbc1d2Ed14128Cd7Af450319b642Fd43d65E495dc);

        // Replay with decoded parameters
        swapRolloverLoan.rolloverLoanWithFlashSwap(
            decoded_smartCommitmentForwarderAddress,
            decoded_bidId,
            decoded_borrowerAmount,
            decoded_flashSwapArgs,
            decoded_acceptCommitmentArgs
        );

        console.log(" Transaction replayed successfully with decoded params!");
    }
 */

 //  cast tx 0x6495cc312a71a06f0e7cc7f928819c14e5ed388d2a7b5a196962b9a89069bb9f --rpc-url https://rpc.hyperliquid.xyz/evm


 //  cast tx 0xc7621a27aeefd48f37c2bfe03c9bfce21ab01d86eaae66e073e4f1b78a8c3f4b --rpc-url https://rpc.hyperliquid.xyz/evm


  function test_replayTransaction() public {
      

        address smartCommitmentForwarderAddress = getDeployedAddress("SmartCommitmentForwarder");

        bytes memory tx_calldata = hex"0f29fee20000000000000000000000009fa5a22a3c0b8030147d363f68a763deb9f00acb000000000000000000000000000000000000000000000000000000000000002500000000000000000000000000000000000000000000000000000000000009de000000000000000000000000203a662b0bd271a6ed5a60edfbd04bfce608fd36000000000000000000000000b24e3035d1fcbc0e43cf3143c3fd92e53df2009b00000000000000000000000000000000000000000000000000000000000001f400000000000000000000000000000000000000000000000000000000000120f800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000120000000000000000000000000000000000000000000000000000000000000000000000000000000000000000093fea7170a9b5ef6dbe35cee0f7d94f5a848a8fb0000000000000000000000000000000000000000000000000000000000011e4c0000000000000000000000000000000000000000000000000dba2b837c220c130000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b24e3035d1fcbc0e43cf3143c3fd92e53df2009b00000000000000000000000000000000000000000000000000000000000000640000000000000000000000000000000000000000000000000000000000278d0000000000000000000000000000000000000000000000000000000000000001200000000000000000000000000000000000000000000000000000000000000000";

        // Decode the calldata (skip first 4 bytes which is the function selector)
        bytes memory params = new bytes(tx_calldata.length - 4);
        for (uint i = 4; i < tx_calldata.length; i++) {
            params[i - 4] = tx_calldata[i];
        }

        // Decode parameters using abi.decode
        (
            address decoded_smartCommitmentForwarderAddress,
            uint256 decoded_bidId,
            uint256 decoded_borrowerAmount,
            SwapRolloverLoan_G2.FlashSwapArgs memory decoded_flashSwapArgs,
            SwapRolloverLoan_G2.AcceptCommitmentArgs memory decoded_acceptCommitmentArgs
        ) = abi.decode(params, (
            address,
            uint256,
            uint256,
            SwapRolloverLoan_G2.FlashSwapArgs,
            SwapRolloverLoan_G2.AcceptCommitmentArgs
        ));

        console.log("=== Decoded Parameters ===");
        console.log("Smart Commitment Forwarder:", decoded_smartCommitmentForwarderAddress);
        console.log("Bid ID:", decoded_bidId);
        console.log("Borrower Amount:", decoded_borrowerAmount);
        console.log("Flash Swap token0:", decoded_flashSwapArgs.token0);
        console.log("Flash Swap token1:", decoded_flashSwapArgs.token1);
        console.log("Flash Swap fee:", decoded_flashSwapArgs.fee);
        console.log("Flash Amount:", decoded_flashSwapArgs.flashAmount);
        console.log("Borrow Token1:", decoded_flashSwapArgs.borrowToken1);

        // Impersonate the original caller
        vm.prank(0x7133c664af6763ab9aeeb095d3c114a750d8dfdc);

        // Replay with decoded parameters
        swapRolloverLoan.rolloverLoanWithFlashSwap(
            decoded_smartCommitmentForwarderAddress,
            decoded_bidId,
            decoded_borrowerAmount,
            decoded_flashSwapArgs,
            decoded_acceptCommitmentArgs
        );

        console.log(" Transaction replayed successfully with decoded params!");
    }
 









}