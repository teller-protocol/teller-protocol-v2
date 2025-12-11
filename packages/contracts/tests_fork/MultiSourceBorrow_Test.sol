// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "../tests/util/FoundryTest.sol";
import "forge-std/console.sol";
import "forge-std/StdJson.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/Vm.sol";

// Import your actual contracts
import { TellerV2 } from "../contracts/TellerV2.sol";
import { TellerV2Context } from "../contracts/TellerV2Context.sol";
import { MultiSourceBorrow } from "../contracts/LenderCommitmentForwarder/MultiSourceBorrow.sol";
import { SmartCommitmentForwarder } from "../contracts/LenderCommitmentForwarder/SmartCommitmentForwarder.sol";
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
        address hypernativeOracle = getDeployedAddress("HypernativeOracle");

        // Mock the Hypernative oracle to allow our newly deployed MultiSourceBorrow contract
        // isTimeExceeded should return true (time has passed since registration)
        vm.mockCall(
            hypernativeOracle,
            abi.encodeWithSignature("isTimeExceeded(address)", address(multiSourceBorrow)),
            abi.encode(true)
        );

        // Borrower's wallet address
        address borrower = address(0xbc1d2Ed14128Cd7Af450319b642Fd43d65E495dc);
        address recipient = address(0xbc1d2Ed14128Cd7Af450319b642Fd43d65E495dc);

        // Borrower needs to approve the SmartCommitmentForwarder as a market forwarder
        address tellerV2Address = getDeployedAddress("TellerV2");
        uint256 marketId = 13; // From the trace

        { 
            vm.startPrank(borrower);

            // Approve SmartCommitmentForwarder as a market forwarder on TellerV2
            TellerV2Context(tellerV2Address).approveMarketForwarder(marketId, smartCommitmentForwarderAddress);

            // Approve MultiSourceBorrow as an extension on SmartCommitmentForwarder
            // This allows SmartCommitmentForwarder to extract borrower address from calldata
            SmartCommitmentForwarder(smartCommitmentForwarderAddress).addExtension(address(multiSourceBorrow));

            vm.stopPrank();
        }

        // Accept commitment parameters
        MultiSourceBorrow.AcceptCommitmentArgs memory acceptCommitmentArgs = MultiSourceBorrow.AcceptCommitmentArgs({
            commitmentId: 0,
            smartCommitmentAddress: address(0x1191354f5796C03F194CA94f6d6736176fCFAC89),  // pool address
            principalAmount: 42,
            collateralAmount: 200000000000000000000,  // Increased to ~200e18 to account for pricing bug
            collateralTokenId: 0,
            collateralTokenAddress: address(0x940181a94A35A4569E4529A3CDfB74e38FD98631),
            interestRate: 6319,
            loanDuration: 604800,
            merkleProof: new bytes32[](0)
        });

        // Get the principal token
        IERC20 principalToken = IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);



         // Deal collateral tokens to borrower  --- this works !
           deal(
            address( acceptCommitmentArgs.collateralTokenAddress ),
            address( borrower ),
            uint256( acceptCommitmentArgs.collateralAmount )
          );

        // Debug: Calculate what the required collateral actually is
        address smartCommitment = acceptCommitmentArgs.smartCommitmentAddress;
        uint256 requiredCollateral;
        {
            // Call the smart commitment to get required collateral
            (bool success, bytes memory data) = smartCommitment.staticcall(
                abi.encodeWithSignature("calculateCollateralRequiredToBorrowPrincipal(uint256)", acceptCommitmentArgs.principalAmount)
            );
            if (success) {
                requiredCollateral = abi.decode(data, (uint256));
                console.log("Required collateral:", requiredCollateral);
                console.log("Provided collateral:", acceptCommitmentArgs.collateralAmount);
            }
        }


        // Log balance before
     //   uint256 balanceBefore = principalToken.balanceOf(recipient);
      //  console.log("Recipient balance BEFORE acceptCommitment:", balanceBefore);

        {
            // Approve collateral token transfer
            IERC20 collateralToken = IERC20(acceptCommitmentArgs.collateralTokenAddress);
            vm.prank(borrower);
            collateralToken.approve(address(multiSourceBorrow), acceptCommitmentArgs.collateralAmount);
            vm.stopPrank();
        }

        vm.prank(borrower);
        uint256 bidId = multiSourceBorrow.acceptCommitmentWithMultiSource(
            smartCommitmentForwarderAddress,
            acceptCommitmentArgs,
            address(0), // No pool withdrawal
            0,
            address(0), // No staking withdrawal
            0,
            recipient
        );

        // Log balance after
     //   uint256 balanceAfter = principalToken.balanceOf(recipient);
     //   console.log("Recipient balance AFTER acceptCommitment:", balanceAfter);
       console.log("Bid ID created:", bidId);

        // Log the difference
       /*  if (balanceAfter > balanceBefore) {
            console.log("Recipient token GAINED:", balanceAfter - balanceBefore);
        } else if (balanceBefore > balanceAfter) {
            console.log("Recipient token SPENT:", balanceBefore - balanceAfter);
        } else {
            console.log("Recipient token balance UNCHANGED");
        } */

        // Add assertions
         //  assertTrue(bidId > 0, "Bid ID should be created");
     }




 



}