// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "../tests/util/FoundryTest.sol";
import "forge-std/console.sol";
import "forge-std/StdJson.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/Vm.sol";


// Import your actual contracts
import { TellerV2 } from "../contracts/TellerV2.sol";
import { FlashRolloverLoan_G7 } from "../contracts/LenderCommitmentForwarder/extensions/rollover/FlashRolloverLoan_G7.sol";


contract FlashRollover_Fork_Test is Test {

    string constant NETWORK_NAME = "base";

    FlashRolloverLoan_G7 flashRolloverLoan;


       using stdJson for string;

      function getDeployedAddress(  string memory contractName) internal view returns (address) {
          string memory root = vm.projectRoot();
          string memory path = string.concat(root, "/deployments/", NETWORK_NAME, "/", contractName, ".json");
          string memory json = vm.readFile(path);
          return json.readAddress(".address");
      }

      function setUp() public {
          address payable flashRolloverAddr = payable(getDeployedAddress(  "FlashRolloverLoan"));
          flashRolloverLoan = FlashRolloverLoan_G7(flashRolloverAddr);

          assertTrue(flashRolloverAddr.code.length > 0, "could not connect to flash rollover loan contract ") ;
      }


 

     function test_FlashRollover_forked() public   {

       // etch_FlashRolloverWithMock();

        // Define test parameters
        address lenderCommitmentForwarder = 0x0708480670BdE591e275B06Cd19EcaDFC93A1f16;
        uint256 bidId = 1815; // Example loan ID - replace with actual loan ID
        uint256 flashLoanAmount = 15986;
        uint256 borrowerAmount = 0; // Additional amount borrower adds
        uint256 rewardAmount = 0;
        address rewardRecipient = 0x0000000000000000000000000000000000000000 ;

        // Accept commitment parameters
        FlashRolloverLoan_G7.AcceptCommitmentArgs memory acceptCommitmentArgs = FlashRolloverLoan_G7.AcceptCommitmentArgs({
            commitmentId: 0,
            smartCommitmentAddress: address(0x672520522383C09e601F8FA767b61dD41767b502),
            principalAmount: 16695,
            collateralAmount: 149997751,
            collateralTokenId: 0,
            collateralTokenAddress: address(0x2a06A17CBC6d0032Cac2c6696DA90f29D39a1a29),  //??
            interestRate: 3615,
            loanDuration: 604800,
            merkleProof: new bytes32[](0) // No merkle proof
        });

        // Get Andre's wallet address
        address andresWallet = 0xbc1d2Ed14128Cd7Af450319b642Fd43d65E495dc;

        // Get the principal token (token1)
        IERC20 principalToken = IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);

        // Log balance before rollover
        uint256 balanceBefore = principalToken.balanceOf(andresWallet);
       // console.log("Principal token balance BEFORE rollover:", balanceBefore);

        vm.prank(andresWallet);  //andres wallet
        flashRolloverLoan.rolloverLoanWithFlash (
            lenderCommitmentForwarder,
            bidId,
            flashLoanAmount,
            borrowerAmount,
            rewardAmount,
            rewardRecipient,

            acceptCommitmentArgs
        );

        // Log balance after rollover
        uint256 balanceAfter = principalToken.balanceOf(andresWallet);
      //  console.log("Principal token balance AFTER rollover:", balanceAfter);

        // Log the difference
        

        // Add assertions to verify the rollover worked
        // assertTrue(someCondition, "Rollover should succeed");
     }





 
 
  function test_replayFlashRolloverTx() public {


        bytes memory tx_calldata = hex"ffaae46b0000000000000000000000000708480670bde591e275b06cd19ecadfc93a1f1600000000000000000000000000000000000000000000000000000000000007170000000000000000000000000000000000000000000000000000000000003e7200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000672520522383c09e601f8fa767b61dd41767b50200000000000000000000000000000000000000000000000000000000000041370000000000000000000000000000000000000000000000000000000008f0c8b700000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a06a17cbc6d0032cac2c6696da90f29d39a1a290000000000000000000000000000000000000000000000000000000000000e1f0000000000000000000000000000000000000000000000000000000000093a8000000000000000000000000000000000000000000000000000000000000001200000000000000000000000000000000000000000000000000000000000000000";

        // Decode the calldata (skip first 4 bytes which is the function selector)
        bytes memory params = new bytes(tx_calldata.length - 4);
        for (uint i = 4; i < tx_calldata.length; i++) {
            params[i - 4] = tx_calldata[i];
        }

        // Decode parameters using abi.decode for FlashRolloverLoan
        (
            address decoded_lenderCommitmentForwarder,
            uint256 decoded_bidId,
            uint256 decoded_flashLoanAmount,
            uint256 decoded_borrowerAmount,
            uint256 decoded_rewardAmount,
            address decoded_rewardRecipient,
            FlashRolloverLoan_G7.AcceptCommitmentArgs memory decoded_acceptCommitmentArgs
        ) = abi.decode(params, (
            address,
            uint256,
            uint256,
            uint256,
            uint256,
            address,
            FlashRolloverLoan_G7.AcceptCommitmentArgs
        ));

        console.log("=== Decoded Parameters ===");
        console.log("Lender Commitment Forwarder:", decoded_lenderCommitmentForwarder);
        console.log("Bid ID:", decoded_bidId);
        console.log("Flash Loan Amount:", decoded_flashLoanAmount);
        console.log("Borrower Amount:", decoded_borrowerAmount);
        console.log("Reward Amount:", decoded_rewardAmount);
        console.log("Reward Recipient:", decoded_rewardRecipient);
        console.log("Smart Commitment Address:", decoded_acceptCommitmentArgs.smartCommitmentAddress);
        console.log("Principal Amount:", decoded_acceptCommitmentArgs.principalAmount);
        console.log("Collateral Amount:", decoded_acceptCommitmentArgs.collateralAmount);

        // Impersonate the original caller
        vm.prank(0xbc1d2Ed14128Cd7Af450319b642Fd43d65E495dc);

        // Replay with decoded parameters
        flashRolloverLoan.rolloverLoanWithFlash (
            decoded_lenderCommitmentForwarder,
            decoded_bidId,
            decoded_flashLoanAmount,
            decoded_borrowerAmount,
            decoded_rewardAmount,
            decoded_rewardRecipient,
            decoded_acceptCommitmentArgs
        );

        console.log(" Transaction replayed successfully with decoded params!");
    }
 









}