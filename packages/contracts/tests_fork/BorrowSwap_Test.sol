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

import { LenderCommitmentGroup_Pool_V2 } from "../contracts/LenderCommitmentForwarder/extensions/LenderCommitmentGroup/LenderCommitmentGroup_Pool_V2.sol";
import { SmartCommitmentForwarder } from "../contracts/LenderCommitmentForwarder/SmartCommitmentForwarder.sol";
import { BorrowSwap } from "../contracts/LenderCommitmentForwarder/extensions/rollover/BorrowSwap.sol";
import { BorrowSwap_G3 } from "../contracts/LenderCommitmentForwarder/extensions/rollover/BorrowSwap_G3.sol";

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

contract BorrowSwap_Fork_Test is Test {

    string constant NETWORK_NAME = "katana";
        
    SmartCommitmentForwarder scf;

    LenderCommitmentGroup_Pool_V2 pool;

     BorrowSwap borrowSwap;

   // address constant DEPLOYED_SWAP_ROLLOVER_LOAN = 0xa4A8c60Ac9E0c38f8B46316c6B3B508b3BA04415; // Replace with actual deployed address
        

       using stdJson for string;
        
         function getDeployedAddress(  string memory contractName) internal view returns (address) {
          string memory root = vm.projectRoot();
          string memory path = string.concat(root, "/deployments/", NETWORK_NAME, "/", contractName, ".json");
          string memory json = vm.readFile(path);
          return json.readAddress(".address");
      }



      function setUp() public {
         address payable scfAddr = payable( getDeployedAddress("SmartCommitmentForwarder") );
         scf = SmartCommitmentForwarder( scfAddr );

          assertTrue(scfAddr.code.length > 0, "could not connect to scf contract ") ;


          address payable poolAddr = payable( 0x028523F05775bFD0ea91f17298Df7b3c60d16194 );
          pool = LenderCommitmentGroup_Pool_V2(poolAddr);

          assertTrue(poolAddr.code.length > 0, "could not connect to pool contract ") ;


          address payable  borrowSwapAddr = payable( getDeployedAddress("BorrowSwap") );
          borrowSwap = BorrowSwap( borrowSwapAddr );

          assertTrue(borrowSwapAddr.code.length > 0, "could not connect to borrowSwap contract ") ;


      }
 
 

     function test_borrowswap_quote() public   {


        address inputToken = 0x203A662b0BD271A6ed5a60EdFbd04bFce608FD36; // Example token address
        uint256 amountIn = 1000;

        BorrowSwap_G3.TokenSwapPath[] memory swapPaths = new BorrowSwap_G3.TokenSwapPath[](1);
        swapPaths[0] = BorrowSwap_G3.TokenSwapPath({
            poolFee: 500, // 0.3% fee
            tokenOut: 0x0913DA6Da4b42f538B445599b46Bb4622342Cf52 // Example output token
        });

        uint256 amountOut = borrowSwap.quoteExactInput(
            inputToken,
            amountIn,
            swapPaths
        );

        assertTrue(amountOut > 0, "Quote should return positive amount");

       /*
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
        */

        // Add assertions to verify the deployment worked
      //  assertTrue(deployedPool != address(0), "Pool should be deployed");
       // assertTrue(deployedPool.code.length > 0, "Deployed pool should have code");
     }

/* 
   function etch_tellerV2() public {


            address metaForwarder = 0x5d3eCF8877eDAB28e14bD7d243fA8B0fE416E95E;

             
          address tellerV2Address = 0xf7B14778035fEAF44540A0bC1D4ED859bCB28229;
        
           
          TellerV2 newTellerV2 = new TellerV2( 
                 metaForwarder
            );

          // Then replace the code at the deployed address
          vm.etch( address(tellerV2Address) , address(newTellerV2).code );


      }  */ 




 function test_borrowswap_quote_two() public   {

          //  etch_tellerV2(); 


        /*
            Approve scf as trusted market forwarder for market 2 

        */  

            address borrowerAddress = 0xbc1d2Ed14128Cd7Af450319b642Fd43d65E495dc;



        /* 
        vm.prank(0x73393b8a593a9659c6AD6afF156800FD9e5470c6); 
        TellerV2(address (0xf7B14778035fEAF44540A0bC1D4ED859bCB28229) ).setTrustedMarketForwarder( 2 , 0x9Fa5A22A3c0b8030147d363f68A763DEB9f00acB);  
 
        */ 


        SmartCommitmentForwarder smartCommitmentForwarder = SmartCommitmentForwarder(0x9Fa5A22A3c0b8030147d363f68A763DEB9f00acB);

        // !!!! NEEDED !!!!!!!!!!! 
       // vm.prank(borrowerAddress);
     //   smartCommitmentForwarder.addExtension( address(borrowSwap) );





        address inputToken = 0x203A662b0BD271A6ed5a60EdFbd04bFce608FD36;
        uint256 amountIn = 0;


        address lenderCommitmentForwarder = 0x9Fa5A22A3c0b8030147d363f68A763DEB9f00acB;



        // Setup swap paths
        BorrowSwap_G3.TokenSwapPath[] memory swapPaths = new BorrowSwap_G3.TokenSwapPath[](2);
        swapPaths[0] = BorrowSwap_G3.TokenSwapPath({
            poolFee: 500,
            tokenOut: 0xEE7D8BCFb72bC1880D0Cf19822eB0A2e6577aB62
        });
        swapPaths[1] = BorrowSwap_G3.TokenSwapPath({
            poolFee: 500,
            tokenOut: 0x17BFF452dae47e07CeA877Ff0E1aba17eB62b0aB
        });

        // Setup swap args
        BorrowSwap_G3.SwapArgs memory swapArgs = BorrowSwap_G3.SwapArgs({
            amountOutMinimum: 103008674744076537,
            swapPaths: swapPaths
        });




        // Setup accept commitment args
        bytes32[] memory emptyProof = new bytes32[](0);
        BorrowSwap_G3.AcceptCommitmentArgs memory acceptCommitmentArgs = BorrowSwap_G3.AcceptCommitmentArgs({
            smartCommitmentAddress: 0x57041602534466802be86D3D66A5AA2cEacb8663,
            principalAmount: 77698,
            collateralAmount: 548884820906494937,
            collateralTokenId: 0,
            collateralTokenAddress: 0x17BFF452dae47e07CeA877Ff0E1aba17eB62b0aB,
            commitmentId: 0, 
            interestRate: 101,
            loanDuration: 2592000,
            merkleProof: emptyProof

        });

        vm.prank(borrowerAddress);
        borrowSwap.borrowSwap(
            lenderCommitmentForwarder,
            inputToken,
            amountIn,
            swapArgs,
            acceptCommitmentArgs
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