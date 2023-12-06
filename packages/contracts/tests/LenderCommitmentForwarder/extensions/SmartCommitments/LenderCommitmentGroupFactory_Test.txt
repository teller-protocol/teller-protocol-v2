import { Testable } from "../../../Testable.sol";

//import { ExtensionsContextUpgradeable } from "../../../contracts/LenderCommitmentForwarder/extensions/ExtensionsContextUpgradeable.sol";

//contract ExtensionsContextMock is ExtensionsContextUpgradeable {}

import { LenderCommitmentGroupFactory } from "../../../../contracts/LenderCommitmentForwarder/extensions/LenderCommitmentGroup/LenderCommitmentGroupFactory.sol";
import "../../../../contracts/interfaces/ILenderCommitmentForwarder.sol";

contract LenderCommitmentGroupFactory_Test is Testable {
    constructor() {}

    User private extensionContract;

    User private borrower;
    User private lender;

    address _tellerV2 = address(0x02);
    address _lenderCommitmentForwarder = address(0x03);
    address _uniswapV3Factory = address(0x04);

    LenderCommitmentGroupFactory factory;

    function setUp() public {
        borrower = new User();
        lender = new User();

        factory = new LenderCommitmentGroupFactory(
            _tellerV2,
            _lenderCommitmentForwarder,
            _uniswapV3Factory
        );
    }

    function test_deployLenderCommitmentGroupPool() public {
        ILenderCommitmentForwarder.Commitment
            memory _createCommitmentArgs = ILenderCommitmentForwarder
                .Commitment({
                    maxPrincipal: 100,
                    expiration: 700000000,
                    maxDuration: 5000000,
                    minInterestRate: 100,
                    collateralTokenAddress: address(0),
                    collateralTokenId: 0,
                    maxPrincipalPerCollateralAmount: 5000,
                    collateralTokenType: ILenderCommitmentForwarder
                        .CommitmentCollateralType
                        .ERC20,
                    lender: address(lender),
                    marketId: 1,
                    principalTokenAddress: address(0)
                });

        uint256 _initialPrincipalAmount = 0;
        uint16 _liquidityThresholdPercent = 0;
        uint16 _loanToValuePercent = 0;

        address _newPoolAddress = factory.deployLenderCommitmentGroupPool(
            _createCommitmentArgs,
            _initialPrincipalAmount,
            _liquidityThresholdPercent,
            _loanToValuePercent
        );

        assertTrue(_newPoolAddress != address(0), "New pool was not deployed");
    }
}

contract User {}
