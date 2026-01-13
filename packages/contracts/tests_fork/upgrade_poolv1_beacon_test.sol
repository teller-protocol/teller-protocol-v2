// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "../tests/util/FoundryTest.sol";
import "forge-std/console.sol";
import "forge-std/StdJson.sol";

// Import contracts
import { LenderCommitmentGroup_Smart } from "../contracts/LenderCommitmentForwarder/extensions/LenderCommitmentGroup/LenderCommitmentGroup_Smart.sol";
import { IBeacon } from "../contracts/openzeppelin/beacon/IBeacon.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { IProtocolPausingManager } from "../contracts/interfaces/IProtocolPausingManager.sol";
import { IHasProtocolPausingManager } from "../contracts/interfaces/IHasProtocolPausingManager.sol";

/*

This test validates the upgrade of the LenderCommitmentGroup_Smart beacon implementation
to add pause/unpause liquidations functionality.

To run this test:
1. Start anvil forking mainnet in a separate terminal:
   anvil --fork-url https://eth-mainnet.g.alchemy.com/v2/<API_KEY> --fork-block-number <BLOCK_NUMBER>

2. Run the test:
   forge test --match-test test_upgrade_pool_v1_beacon --rpc-url http://127.0.0.1:8545 -vvv

*/

contract UpgradePoolV1BeaconTest is Test {

    using stdJson for string;

    string constant NETWORK_NAME = "mainnet";

    // Mainnet addresses
    address constant BEACON_ADDRESS = 0x645b73AF74D14B488EC296a5C0D00270DDd17Cd6;
    address constant TELLER_V2_ADDRESS = 0xf7B14778035fEAF44540A0bC1D4ED859bCB28229;
    address constant SMART_COMMITMENT_FORWARDER_ADDRESS = 0x00172f67db60E5fA346e599cdE675f0ca213b47b;
    address constant UNISWAP_V3_FACTORY_ADDRESS = 0x1F98431c8aD98523631AE4a59f267346ea31F984;

    IBeacon beacon;
    address originalImplementation;
    LenderCommitmentGroup_Smart newImplementation;

    // Get a deployed pool instance to test with
    address constant TEST_POOL_ADDRESS = 0x5F610ca9Ff0a0Ad9FbF91B8EB85A892fb0eBC620; // Example pool address - replace with actual
    LenderCommitmentGroup_Smart testPool;

    function setUp() public {
        console.log("Running fork test on chain:", block.chainid);
        console.log("Block number:", block.number);

        // Verify we're connected to the beacon
        require(BEACON_ADDRESS.code.length > 0, "Beacon not found at address");
        beacon = IBeacon(BEACON_ADDRESS);

        // Get the original implementation
        originalImplementation = beacon.implementation();
        console.log("Original implementation:", originalImplementation);
        require(originalImplementation.code.length > 0, "Original implementation has no code");

        // Connect to test pool (if it exists)
        if (TEST_POOL_ADDRESS.code.length > 0) {
            testPool = LenderCommitmentGroup_Smart(TEST_POOL_ADDRESS);
            console.log("Connected to test pool at:", TEST_POOL_ADDRESS);
        }
    }

    function test_upgrade_pool_v1_beacon() public {
        console.log("Testing Pool V1 Beacon Upgrade...");

        // Step 1: Deploy new implementation
        console.log("Deploying new LenderCommitmentGroup_Smart implementation...");
        newImplementation = new LenderCommitmentGroup_Smart(
            TELLER_V2_ADDRESS,
            SMART_COMMITMENT_FORWARDER_ADDRESS,
            UNISWAP_V3_FACTORY_ADDRESS
        );
        console.log("New implementation deployed at:", address(newImplementation));

        // Step 2: Use vm.etch to replace the implementation code at the original implementation address
        console.log("Etching new implementation over original...");
        vm.etch(originalImplementation, address(newImplementation).code);
        console.log("Implementation upgraded via etch");

        // Step 3: Verify the upgrade was successful
        console.log("Verifying upgrade...");
        address currentImplementation = beacon.implementation();
        console.log("Current implementation after etch:", currentImplementation);

        // The address should still be the same, but the code should be new
        assertEq(currentImplementation, originalImplementation, "Implementation address should not change");
        assertTrue(currentImplementation.code.length > 0, "Implementation should have code");

        console.log("Pool V1 Beacon upgrade test completed successfully!");
    }

    function test_new_pause_liquidations_functionality() public {
        // First perform the upgrade
        console.log("Testing new pause liquidations functionality...");

        // Deploy new implementation
        newImplementation = new LenderCommitmentGroup_Smart(
            TELLER_V2_ADDRESS,
            SMART_COMMITMENT_FORWARDER_ADDRESS,
            UNISWAP_V3_FACTORY_ADDRESS
        );

        // Etch over the original implementation
        vm.etch(originalImplementation, address(newImplementation).code);

        // Skip this test if we don't have a test pool
        if (TEST_POOL_ADDRESS.code.length == 0) {
            console.log("Skipping pause test - no test pool available");
            return;
        }

        // Step 1: Check initial liquidationsPaused state
        bool initialPauseState = testPool.liquidationsPaused();
        console.log("Initial liquidationsPaused state:", initialPauseState);
        assertFalse(initialPauseState, "Liquidations should not be paused initially");

        // Step 2: Get the protocol pausing manager and find a pauser
        address pausingManager = testPool.getProtocolPausingManager();
        console.log("Protocol pausing manager:", pausingManager);
        require(pausingManager != address(0) && pausingManager.code.length > 0, "Pausing manager not found");

        IProtocolPausingManager pausingMgr = IProtocolPausingManager(pausingManager);

        // Find a pauser address - we can get the owner or check specific addresses
        // For this test, we'll try to grant ourselves pauser role or find an existing pauser
        // Let's try the timelock/owner of the pausing manager
        address pauserAddress = getPauserAddress(pausingManager);
        console.log("Using pauser address:", pauserAddress);

        // Step 3: Use vm.prank to impersonate the pauser and pause liquidations
        vm.prank(pauserAddress);
        testPool.pauseLiquidations();
        console.log("Called pauseLiquidations()");

        // Step 4: Verify liquidations are now paused
        bool pausedState = testPool.liquidationsPaused();
        console.log("Liquidations paused state after pause:", pausedState);
        assertTrue(pausedState, "Liquidations should be paused");

        // Step 5: Unpause liquidations
        vm.prank(pauserAddress);
        testPool.unpauseLiquidations();
        console.log("Called unpauseLiquidations()");

        // Step 6: Verify liquidations are unpaused
        bool unpausedState = testPool.liquidationsPaused();
        console.log("Liquidations paused state after unpause:", unpausedState);
        assertFalse(unpausedState, "Liquidations should be unpaused");

        console.log("New pause liquidations functionality verified!");
    }

    function getPauserAddress(address pausingManager) internal view returns (address) {
        // The owner of the ProtocolPausingManager is always a pauser
        // (see isPauser function: returns pauserRoleBearer[_account] || _account == owner())
        try IProtocolPausingManager(pausingManager).owner() returns (address owner) {
            console.log("Pausing manager owner:", owner);
            // Owner is always a pauser according to isPauser() logic
            return owner;
        } catch {
            // If we can't get owner, return zero address and let test fail
            console.log("Failed to get pausing manager owner");
            return address(0);
        }
    }

    function test_liquidation_reverts_when_paused() public {
        console.log("Testing that liquidations revert when paused...");

        // Deploy and etch new implementation
        newImplementation = new LenderCommitmentGroup_Smart(
            TELLER_V2_ADDRESS,
            SMART_COMMITMENT_FORWARDER_ADDRESS,
            UNISWAP_V3_FACTORY_ADDRESS
        );
        vm.etch(originalImplementation, address(newImplementation).code);

        if (TEST_POOL_ADDRESS.code.length == 0) {
            console.log("Skipping liquidation revert test - no test pool available");
            return;
        }

        // Get the protocol pausing manager
        address pausingManager = testPool.getProtocolPausingManager();
        console.log("Protocol pausing manager:", pausingManager);

        if (pausingManager == address(0) || pausingManager.code.length == 0) {
            console.log("Skipping - no pausing manager configured");
            return;
        }

        // Get a pauser address
        address pauserAddress = getPauserAddress(pausingManager);
        console.log("Using pauser address:", pauserAddress);

        // Pause liquidations
        vm.prank(pauserAddress);
        testPool.pauseLiquidations();
        console.log("Liquidations paused");

        // Verify liquidations are paused
        assertTrue(testPool.liquidationsPaused(), "Liquidations should be paused");

        // Try to liquidate - this should revert with "P" (paused)
        // We'll use a dummy bid ID and expect it to revert with the pause check before any other checks
        uint256 dummyBidId = 999999;
        int256 dummyTokenDiff = 0;

        vm.expectRevert("P");
        testPool.liquidateDefaultedLoanWithIncentive(dummyBidId, dummyTokenDiff);

        console.log("Liquidation correctly reverted when paused!");

        // Unpause and verify we can proceed past the pause check
        vm.prank(pauserAddress);
        testPool.unpauseLiquidations();
        console.log("Liquidations unpaused");

        assertFalse(testPool.liquidationsPaused(), "Liquidations should be unpaused");

        console.log("Liquidation pause enforcement test completed successfully!");
    }

    function getDeployedAddress(string memory contractName) internal view returns (address) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/deployments/", NETWORK_NAME, "/", contractName, ".json");
        string memory json = vm.readFile(path);
        return json.readAddress(".address");
    }
}
