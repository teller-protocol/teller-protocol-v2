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

 

import { PriceAdapterUniswapV3 } from "../contracts/price_adapters/PriceAdapterUniswapV3.sol";

 
import { LenderCommitmentGroup_Pool_V3 } from "../contracts/LenderCommitmentForwarder/extensions/LenderCommitmentGroup/LenderCommitmentGroup_Pool_V3.sol";
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

    string constant NETWORK_NAME = "mainnet";
        
    SmartCommitmentForwarder scf;

    LenderCommitmentGroup_Pool_V3 pool;

     PriceAdapterUniswapV3 price_adapter ;

        

       using stdJson for string;
        
         function getDeployedAddress(  string memory contractName) internal view returns (address) {
          string memory root = vm.projectRoot();
          string memory path = string.concat(root, "/deployments/", NETWORK_NAME, "/", contractName, ".json");
          string memory json = vm.readFile(path);
          return json.readAddress(".address");
      }



    function setUp() public { 

        price_adapter = new PriceAdapterUniswapV3() ; 
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
 




/*
    
        Test the UniswapV3 Price oracle for the MOG pool 

            0x5F610ca9Ff0a0Ad9FbF91B8EB85A892fb0eBC620

*/



     function test_pool_v3_price_routes () public   {


        // principal token is USDC
        //collateral is MOG 

        address MOG_POOL = 0xE7f05308e67C33D1041438aDCbBb4405e6430E62;
        uint256 token0Decimals = 6;
        uint256 token1Decimals = 18; 


        // register the route 

       PriceAdapterUniswapV3.PoolRoute[] memory routes = new PriceAdapterUniswapV3.PoolRoute[](1);
        routes[0] = PriceAdapterUniswapV3.PoolRoute({
            pool: MOG_POOL,
            zeroForOne: false,
            twapInterval: 0,
            token0Decimals: token0Decimals,
            token1Decimals: token1Decimals
        });

        bytes memory encodedRoute = price_adapter.encodePoolRoutes(routes);

        bytes32 routeHash = price_adapter.registerPriceRoute (

                encodedRoute 

            );


        uint256 priceRatioQ96 = price_adapter.getPriceRatioQ96(routeHash) ;




        // query the route 



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
        ); */ 
 
     }




   /*  function etch_uniswap_pricing_helper() public {


           
             
          address pricingHelperAddress = 0x6B38aD36f17dd55bE44217d184DB8A01536aa104;
        
           
          UniswapPricingHelper newPricingHelper = new UniswapPricingHelper( );

          // Then replace the code at the deployed address
          vm.etch( address(pricingHelperAddress) , address(newPricingHelper).code );


      } */




 
}