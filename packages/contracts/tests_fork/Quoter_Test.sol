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
import { Quoter } from "../contracts/uniswap/v3-periphery/contracts/lens/Quoter.sol";

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

contract Quoter_Fork_Test is Test {

    string constant NETWORK_NAME = "katana";
    
    Quoter quoter;
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
          address payable quoterAddr = payable(getDeployedAddress(  "Quoter" ));
          quoter = Quoter(quoterAddr);

          assertTrue(quoterAddr.code.length > 0, "could not connect to quoter contract ") ;
      }
 



     function etch_Quoter() public {

            //all specific to hyperevm ! 
           address payable quoterAddr = payable(getDeployedAddress(  "Quoter" ));

            //on katana .. 
          address uniswapFactoryAddress = 0x203e8740894c8955cB8950759876d7E7E45E04c1  ; 
         
            // deploy the new contract... 
          Quoter newQuoter = new Quoter( 
                
                uniswapFactoryAddress 

            );


          // Then replace the code at the deployed address
          vm.etch( address(quoterAddr) , address(newQuoter).code );


      }



     function test_quoter_math() public   {



         etch_Quoter();





        address inputToken = 0x203A662b0BD271A6ed5a60EdFbd04bFce608FD36;
        uint256 amountIn = 698130000;
        address outputToken = 0xEE7D8BCFb72bC1880D0Cf19822eB0A2e6577aB62;
        uint24 poolFee = 500;

        // Encode the swap path: inputToken -> outputToken with poolFee
        bytes memory swapPath = abi.encodePacked(inputToken, poolFee, outputToken);

        vm.prank(0xbc1d2Ed14128Cd7Af450319b642Fd43d65E495dc);  //andres wallet
        (
            uint256 amountOut,
            uint160[] memory sqrtPriceX96AfterList,
            uint32[] memory initializedTicksCrossedList,
            uint256 gasEstimate
        ) = quoter.quoteExactInput(swapPath, amountIn);

        // Add assertions to verify the quote worked
       // assertTrue(amountOut > 0, "Quote should return a positive amount out");
      //  assertTrue(sqrtPriceX96AfterList.length > 0, "Should return price data");

        console.log("Amount in:", amountIn);
        console.log("Amount out:", amountOut);

     }


 
}