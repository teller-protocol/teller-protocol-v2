// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Testable } from "../Testable.sol";
import "../../contracts/LenderCommitmentForwarder/SmartCommitmentForwarder.sol";

contract SmartCommitmentForwarder_ContextUpgrade_Test is Testable {

    // Polygon SmartCommitmentForwarder proxy address
    address constant SMART_COMMITMENT_FORWARDER_MAINNET = 0x80314D77E86d70A67126DA86EC823F5fc018c010;

    SmartCommitmentForwarder smartCommitmentForwarder;

    // Struct to store contract state snapshot
    struct StateSnapshot {
        uint256 liquidationProtocolFeePercent;
        bool paused;
        address tellerV2;
        address marketRegistry;
        uint256 lastUnpausedAt;
    }

    function setUp() public {
        // Fork Polygon at a recent block
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));

        smartCommitmentForwarder = SmartCommitmentForwarder(SMART_COMMITMENT_FORWARDER_MAINNET);
    }

    function test_storage_preserved_after_etch_upgrade() public {
        // Get contract state before the upgrade
        StateSnapshot memory stateBefore = _getStateSnapshot();

        // Get the TellerV2 and MarketRegistry addresses for the constructor
        address tellerV2Address = smartCommitmentForwarder.getTellerV2();
        address marketRegistryAddress = smartCommitmentForwarder.getMarketRegistry();

        // Deploy new SmartCommitmentForwarder implementation
        SmartCommitmentForwarder newImplementation = new SmartCommitmentForwarder(
            tellerV2Address,
            marketRegistryAddress
        );

        // Get the runtime code of the new implementation
        bytes memory newCode = address(newImplementation).code;

        // Use vm.etch to replace the code at the proxy address
        // Note: This simulates an upgrade by replacing the implementation code
        // In a real upgrade, this would be done through the proxy admin
        vm.etch(SMART_COMMITMENT_FORWARDER_MAINNET, newCode);

        // Get contract state after the etch
        StateSnapshot memory stateAfter = _getStateSnapshot();

        // Assert all state is unchanged
        assertEq(
            stateAfter.liquidationProtocolFeePercent,
            stateBefore.liquidationProtocolFeePercent,
            "Liquidation protocol fee percent changed"
        );
        assertEq(stateAfter.paused, stateBefore.paused, "Paused status changed");
        assertEq(stateAfter.tellerV2, stateBefore.tellerV2, "TellerV2 address changed");
        assertEq(stateAfter.marketRegistry, stateBefore.marketRegistry, "MarketRegistry address changed");
        assertEq(stateAfter.lastUnpausedAt, stateBefore.lastUnpausedAt, "Last unpaused timestamp changed");
    }

    function _getStateSnapshot() internal view returns (StateSnapshot memory snapshot) {
        snapshot.liquidationProtocolFeePercent = smartCommitmentForwarder.getLiquidationProtocolFeePercent();
        snapshot.paused = smartCommitmentForwarder.paused();
        snapshot.tellerV2 = smartCommitmentForwarder.getTellerV2();
        snapshot.marketRegistry = smartCommitmentForwarder.getMarketRegistry();
        snapshot.lastUnpausedAt = smartCommitmentForwarder.getLastUnpausedAt();
    }
}
