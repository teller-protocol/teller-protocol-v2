// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "../tests/util/FoundryTest.sol";
import "forge-std/console.sol";

// Import interfaces for contracts you want to interact with
interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function symbol() external view returns (string memory);
}

contract ForkTest_Example is Test {
    
    function setUp() public {
        // Fork tests setup - you can add any initialization here
        console.log("Running fork test on chain:", block.chainid);
        console.log("Block number:", block.number);
    }
    
    function test_ForkNetwork() public   {
        // Basic test to verify we're on the fork
        console.log("Current block timestamp:", block.timestamp);
        console.log("Current block number:", block.number);
        
        // You can assert specific chain conditions
        assertTrue(block.number > 0, "Should have valid block number");
    }
    
    function test_ExistingContract() public {
        // Example: Test interaction with an existing token contract
        // Replace with actual contract addresses from Katana network
        address tokenAddress = 0x1234567890123456789012345678901234567890; // Replace with real address
        
        // Only run if the contract exists
        if (tokenAddress.code.length > 0) {
            IERC20 token = IERC20(tokenAddress);
            
            // Test view functions
            try token.symbol() returns (string memory symbol) {
                console.log("Token symbol:", symbol);
            } catch {
                console.log("Failed to get symbol");
            }
        }
    }
    
    function test_WithSpecificAddress() public {
        // Test interactions with specific addresses that exist on the fork
        address targetAddress = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // Replace with actual address
        
        if (targetAddress.balance > 0) {
            console.log("Address balance:", targetAddress.balance);
        }
        
        // You can impersonate accounts for testing
        vm.startPrank(targetAddress);
        // Perform actions as this address
        vm.stopPrank();
    }
}