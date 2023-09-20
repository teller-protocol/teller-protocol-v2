import { Testable } from "../../Testable.sol";

import { ExtensionsContextUpgradeable } from "../../../contracts/LenderCommitmentForwarder/extensions/ExtensionsContextUpgradeable.sol";

contract ExtensionsContextMock is ExtensionsContextUpgradeable {
    function addExtension(address extension) public {
        super._addExtension(extension);
    }

    function blockExtension(address extension) public {
        super._blockExtension(extension);
    }
}

contract ExtensionsContext_Test is Testable {
    constructor() {}

    User private borrower;
    User private lender;

    ExtensionsContextMock extensionsContext;

    function setUp() public {
        borrower = new User();
        lender = new User();

        extensionsContext = new ExtensionsContextMock();
    }

    function test_addExtension() public {
        extensionsContext.addExtension(address(borrower));
    }

    function test_blockExtension() public {
        vm.expectRevert("ExtensionsContextUpgradeable: extension not added");
        extensionsContext.blockExtension(address(borrower));
    }

    function test_addBlockExtension() public {
        bool isTrustedBefore = extensionsContext.isTrustedForwarder(
            address(borrower)
        );

        extensionsContext.addExtension(address(borrower));
        extensionsContext.blockExtension(address(borrower));

        bool isTrustedAfter = extensionsContext.isTrustedForwarder(
            address(borrower)
        );

        assertFalse(isTrustedBefore, "Should not be trusted forwarder");
        assertFalse(isTrustedAfter, "Should not be trusted forwarder");
    }

    function test_isTrustedForwarder() public {
        bool isTrustedBefore = extensionsContext.isTrustedForwarder(
            address(borrower)
        );

        extensionsContext.addExtension(address(borrower));

        bool isTrustedAfter = extensionsContext.isTrustedForwarder(
            address(borrower)
        );

        assertFalse(isTrustedBefore, "Should not be trusted forwarder");
        assertTrue(isTrustedAfter, "Should be trusted forwarder");
    }
}

contract User {}
