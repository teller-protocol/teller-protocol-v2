import { Testable } from "../../../Testable.sol";

//import { ExtensionsContextUpgradeable } from "../../../contracts/LenderCommitmentForwarder/extensions/ExtensionsContextUpgradeable.sol";

//contract ExtensionsContextMock is ExtensionsContextUpgradeable {}

contract ExtensionsContext_Test is Testable {
    constructor() {}

    User private extensionContract;

    User private borrower;
    User private lender;

    function setUp() public {
        borrower = new User();
        lender = new User();
    }
}

contract User {}
