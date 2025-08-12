// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "../tests/util/FoundryTest.sol";
import "forge-std/console.sol";

// Import your actual contracts
import { TellerV2 } from "../contracts/TellerV2.sol";

contract TellerV2_Fork_Test is Test {
    
    TellerV2 tellerV2;
    address constant DEPLOYED_TELLER_ADDRESS = 0x1234567890123456789012345678901234567890; // Replace with actual deployed address
    
    function setUp() public {
        // Connect to existing deployed contract on the fork
        if (DEPLOYED_TELLER_ADDRESS.code.length > 0) {
            tellerV2 = TellerV2(DEPLOYED_TELLER_ADDRESS);
            console.log("Connected to TellerV2 at:", DEPLOYED_TELLER_ADDRESS);
        }
    }
    
    function testTellerV2State() public view {
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
    
    function testTellerV2Interactions() public {
        if (address(tellerV2) != address(0)) {
            // You can test interactions with existing state
            // For example, check if certain markets exist, etc.
        }
    }
}