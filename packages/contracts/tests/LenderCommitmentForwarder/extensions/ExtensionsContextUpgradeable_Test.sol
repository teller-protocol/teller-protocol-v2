// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Testable } from "../../Testable.sol";

import { ExtensionsContextUpgradeable } from "../../../contracts/LenderCommitmentForwarder/extensions/ExtensionsContextUpgradeable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ExtensionsContextMock is ExtensionsContextUpgradeable {
    address private mockTellerV2;

    constructor(address _tellerV2) {
        mockTellerV2 = _tellerV2;
        __initExtensionsModule(_tellerV2);
    }
}

contract MockTellerV2 is Ownable {
    constructor(address owner) {
        _transferOwnership(owner);
    }
}

contract ExtensionsContext_Test is Testable {
    constructor() {}

    address private extensionContract;
    address private protocolOwner;

    User private borrower;
    User private lender;

    ExtensionsContextMock extensionsContext;
    MockTellerV2 mockTellerV2;

    function setUp() public {
        borrower = new User();
        lender = new User();
        extensionContract = address(new User());
        protocolOwner = address(this);

        // Deploy mock TellerV2 with this contract as owner
        mockTellerV2 = new MockTellerV2(protocolOwner);

        // Deploy ExtensionsContext with mock TellerV2
        extensionsContext = new ExtensionsContextMock(address(mockTellerV2));
    }

    function test_addingExtension() public {
        bool isTrustedBefore = extensionsContext.hasExtension(
            address(borrower),
            extensionContract
        );

        //the user will approve
        vm.prank(address(borrower));
        extensionsContext.addExtension(extensionContract);

        bool isTrustedAfter = extensionsContext.hasExtension(
            address(borrower),
            extensionContract
        );

        assertFalse(isTrustedBefore, "Should not be trusted extension before");
        assertTrue(isTrustedAfter, "Should be trusted extension after");
    }

    function test_revokingExtension() public {
        // First add the extension
        vm.prank(address(borrower));
        extensionsContext.addExtension(extensionContract);

        // Verify it's added
        assertTrue(
            extensionsContext.hasExtension(address(borrower), extensionContract),
            "Extension should be added"
        );

        // Revoke the extension
        vm.prank(address(borrower));
        extensionsContext.revokeExtension(extensionContract);

        // Verify it's revoked
        assertFalse(
            extensionsContext.hasExtension(address(borrower), extensionContract),
            "Extension should be revoked"
        );
    }

    function test_hasExtension_false_for_different_user() public {
        // Borrower adds extension
        vm.prank(address(borrower));
        extensionsContext.addExtension(extensionContract);

        // Should not be approved for lender
        assertFalse(
            extensionsContext.hasExtension(address(lender), extensionContract),
            "Extension should not be approved for different user"
        );
    }

    function test_addGlobalExtension_by_protocol_owner() public {
        bool isTrustedBefore = extensionsContext.hasExtension(
            address(borrower),
            extensionContract
        );

        // Protocol owner adds global extension
        extensionsContext.addGlobalExtension(extensionContract);

        bool isTrustedAfter = extensionsContext.hasExtension(
            address(borrower),
            extensionContract
        );

        assertFalse(isTrustedBefore, "Should not be trusted extension before");
        assertTrue(isTrustedAfter, "Should be trusted extension after being added as global");
    }

    function test_globalExtension_works_for_all_users() public {
        // Protocol owner adds global extension
        extensionsContext.addGlobalExtension(extensionContract);

        // Should work for borrower
        assertTrue(
            extensionsContext.hasExtension(address(borrower), extensionContract),
            "Global extension should work for borrower"
        );

        // Should work for lender
        assertTrue(
            extensionsContext.hasExtension(address(lender), extensionContract),
            "Global extension should work for lender"
        );

        // Should work for any random address
        assertTrue(
            extensionsContext.hasExtension(address(123), extensionContract),
            "Global extension should work for any address"
        );
    }

    function test_revokeGlobalExtension_by_protocol_owner() public {
        // Add global extension
        extensionsContext.addGlobalExtension(extensionContract);

        assertTrue(
            extensionsContext.hasExtension(address(borrower), extensionContract),
            "Extension should be trusted after adding as global"
        );

        // Revoke global extension
        extensionsContext.revokeGlobalExtension(extensionContract);

        assertFalse(
            extensionsContext.hasExtension(address(borrower), extensionContract),
            "Extension should not be trusted after revoking global status"
        );
    }

    function test_globalExtension_overrides_lack_of_user_approval() public {
        // Add as global extension WITHOUT user approval
        extensionsContext.addGlobalExtension(extensionContract);

        // Should still return true even though user never approved
        assertTrue(
            extensionsContext.hasExtension(address(borrower), extensionContract),
            "Global extension should work without user approval"
        );
    }

    function test_userExtension_still_works_after_globalExtension_revoked() public {
        // User adds extension
        vm.prank(address(borrower));
        extensionsContext.addExtension(extensionContract);

        // Protocol owner adds as global
        extensionsContext.addGlobalExtension(extensionContract);

        // Protocol owner revokes global status
        extensionsContext.revokeGlobalExtension(extensionContract);

        // Should still work for borrower due to user-level approval
        assertTrue(
            extensionsContext.hasExtension(address(borrower), extensionContract),
            "User extension should still work after global is revoked"
        );

        // Should NOT work for lender who never approved
        assertFalse(
            extensionsContext.hasExtension(address(lender), extensionContract),
            "Should not work for user without approval after global is revoked"
        );
    }

    function test_addGlobalExtension_reverts_for_non_owner() public {
        vm.prank(address(borrower));
        vm.expectRevert("Sender not authorized");
        extensionsContext.addGlobalExtension(extensionContract);
    }

    function test_revokeGlobalExtension_reverts_for_non_owner() public {
        // First add as global (as owner)
        extensionsContext.addGlobalExtension(extensionContract);

        // Try to revoke as non-owner
        vm.prank(address(borrower));
        vm.expectRevert("Sender not authorized");
        extensionsContext.revokeGlobalExtension(extensionContract);
    }
}

contract User {}
