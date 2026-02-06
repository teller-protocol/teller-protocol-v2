import { Testable } from "../Testable.sol";

import { LenderCommitmentGroup_Smart_Override } from "./LenderCommitmentGroup_Smart_Override.sol";

import {TestERC20Token} from "../tokens/TestERC20Token.sol";


import {MarketRegistry} from "../../contracts/MarketRegistry.sol";
import {SmartCommitmentForwarder} from "../../contracts/LenderCommitmentForwarder/SmartCommitmentForwarder.sol";
import {TellerV2SolMock} from "../../contracts/mock/TellerV2SolMock.sol";
import {UniswapV3PoolMock} from "../../contracts/mock/uniswap/UniswapV3PoolMock.sol";
import {UniswapV3FactoryMock} from "../../contracts/mock/uniswap/UniswapV3FactoryMock.sol";
import { PaymentType, PaymentCycleType } from "../../contracts/libraries/V2Calculations.sol";
import { LoanDetails, Payment, BidState , Bid, Terms } from "../../contracts/TellerV2Storage.sol";

import { ILenderCommitmentGroup } from "../../contracts/interfaces/ILenderCommitmentGroup.sol";
import { IUniswapPricingLibrary } from "../../contracts/interfaces/IUniswapPricingLibrary.sol";

import {ProtocolPausingManager} from "../../contracts/pausing/ProtocolPausingManager.sol";


contract LenderCommitmentGroup_Smart_EmergencyWithdraw_Test is Testable {
    constructor() {}

    User private borrower;
    User private lender;
    User private liquidator;

    TestERC20Token principalToken;

    TestERC20Token collateralToken;

    LenderCommitmentGroup_Smart_Override lenderCommitmentGroupSmart;

    MarketRegistry _marketRegistry;
    TellerV2SolMock _tellerV2;
    SmartCommitmentForwarder _smartCommitmentForwarder;
    UniswapV3PoolMock _uniswapV3Pool;
    UniswapV3FactoryMock _uniswapV3Factory;

    function setUp() public {
        borrower = new User();
        lender = new User();
        liquidator = new User();

        _tellerV2 = new TellerV2SolMock();
        _marketRegistry = new MarketRegistry();
        _smartCommitmentForwarder = new SmartCommitmentForwarder(
            address(_tellerV2),address(_marketRegistry));

        _uniswapV3Pool = new UniswapV3PoolMock();

        _uniswapV3Factory = new UniswapV3FactoryMock();
        _uniswapV3Factory.setPoolMock(address(_uniswapV3Pool));



        ProtocolPausingManager protocolPausingManager = new ProtocolPausingManager();
        protocolPausingManager.initialize();

        _tellerV2.setProtocolPausingManager(address(protocolPausingManager));



        principalToken = new TestERC20Token("wrappedETH", "WETH", 1e24, 18);

        collateralToken = new TestERC20Token("PEPE", "pepe", 1e24, 18);

        principalToken.transfer(address(lender), 1e18);
        collateralToken.transfer(address(borrower), 1e18);


        _uniswapV3Pool.set_mockToken0(address(principalToken));
        _uniswapV3Pool.set_mockToken1(address(collateralToken));

        lenderCommitmentGroupSmart = new LenderCommitmentGroup_Smart_Override(
            address(_tellerV2),
            address(_smartCommitmentForwarder),
            address(_uniswapV3Factory)
        );
    }

    function initialize_group_contract() public {
        address _principalTokenAddress = address(principalToken);
        address _collateralTokenAddress = address(collateralToken);
        uint256 _marketId = 1;
        uint32 _maxLoanDuration = 5000000;
        uint16 _interestRateLowerBound = 0;
        uint16 _interestRateUpperBound = 800;
        uint16 _liquidityThresholdPercent = 10000;
        uint16 _collateralRatio = 10000;

         ILenderCommitmentGroup.CommitmentGroupConfig memory groupConfig = ILenderCommitmentGroup.CommitmentGroupConfig({
            principalTokenAddress: _principalTokenAddress,
            collateralTokenAddress: _collateralTokenAddress,
            marketId: _marketId,
            maxLoanDuration: _maxLoanDuration,
            interestRateLowerBound: _interestRateLowerBound,
            interestRateUpperBound: _interestRateUpperBound,
            liquidityThresholdPercent: _liquidityThresholdPercent,
            collateralRatio: _collateralRatio
        });

          bool zeroForOne = false;
          uint32 twapInterval = 0;


          IUniswapPricingLibrary.PoolRouteConfig
            memory routeConfig = IUniswapPricingLibrary.PoolRouteConfig({
                pool: address(_uniswapV3Pool),
                zeroForOne: zeroForOne,
                twapInterval: twapInterval,
                token0Decimals: 18,
                token1Decimals: 18
            });


       IUniswapPricingLibrary.PoolRouteConfig[]
            memory routesConfig = new IUniswapPricingLibrary.PoolRouteConfig[](
                1
            );

        routesConfig[0] = routeConfig;


        address _poolSharesToken = lenderCommitmentGroupSmart.initialize(
            groupConfig,
            routesConfig
        );

        lenderCommitmentGroupSmart.mock_setFirstDepositMade(true);
    }


    function test_emergencyWithdrawCollateral_succeeds_when_liquidations_paused() public {
        initialize_group_contract();

        uint256 bidId = 0;
        uint256 amountDueRemaining = 1000;

        // Setup pool accounting
        lenderCommitmentGroupSmart.set_totalPrincipalTokensCommitted(6000);
        lenderCommitmentGroupSmart.set_totalPrincipalTokensLended(2000);
        lenderCommitmentGroupSmart.set_mockActiveBidsAmountDueRemaining(bidId, amountDueRemaining);
        lenderCommitmentGroupSmart.set_mockBidAsActiveForGroup(bidId, true);

        // Set the test contract as protocol owner
        _tellerV2.setMockOwner(address(this));

        // Pause liquidations
        lenderCommitmentGroupSmart.pauseLiquidations();

        uint256 poolValueBefore = lenderCommitmentGroupSmart.getPoolTotalEstimatedValue();

        // Call emergency withdraw as protocol owner
        lenderCommitmentGroupSmart.emergencyWithdrawCollateral(bidId);

        uint256 poolValueAfter = lenderCommitmentGroupSmart.getPoolTotalEstimatedValue();

        // Pool value should drop by amountDueRemaining
        assertEq(poolValueBefore - poolValueAfter, amountDueRemaining, "pool value should decrease by amount due remaining");

        // lenderCloseLoanWithRecipient should have been called
        assertEq(_tellerV2.lenderCloseLoanWasCalled(), true, "lender close loan not called");
    }


    function test_emergencyWithdrawCollateral_reverts_when_liquidations_not_paused() public {
        initialize_group_contract();

        uint256 bidId = 0;

        // Set the test contract as protocol owner
        _tellerV2.setMockOwner(address(this));

        // Do NOT pause liquidations

        vm.expectRevert("Liquidations must be paused");
        lenderCommitmentGroupSmart.emergencyWithdrawCollateral(bidId);
    }


    function test_emergencyWithdrawCollateral_reverts_when_not_protocol_owner() public {
        initialize_group_contract();

        uint256 bidId = 0;

        // Set a different address as protocol owner
        _tellerV2.setMockOwner(address(lender));

        // Pause liquidations
        lenderCommitmentGroupSmart.pauseLiquidations();

        // Try to call as non-owner (this contract is not the owner)
        vm.expectRevert("Not Protocol Owner");
        lenderCommitmentGroupSmart.emergencyWithdrawCollateral(bidId);
    }


    function test_emergencyWithdrawCollateral_updates_tokenDifferenceFromLiquidations() public {
        initialize_group_contract();

        uint256 bidId = 0;
        uint256 amountDueRemaining = 500;

        lenderCommitmentGroupSmart.set_totalPrincipalTokensCommitted(6000);
        lenderCommitmentGroupSmart.set_mockActiveBidsAmountDueRemaining(bidId, amountDueRemaining);
        lenderCommitmentGroupSmart.set_mockBidAsActiveForGroup(bidId, true);

        // Set the test contract as protocol owner
        _tellerV2.setMockOwner(address(this));

        // Pause liquidations
        lenderCommitmentGroupSmart.pauseLiquidations();

        uint256 poolValueBefore = lenderCommitmentGroupSmart.getPoolTotalEstimatedValue();

        lenderCommitmentGroupSmart.emergencyWithdrawCollateral(bidId);

        uint256 poolValueAfter = lenderCommitmentGroupSmart.getPoolTotalEstimatedValue();

        // Pool value drops by the full amount due remaining (total loss)
        assertEq(poolValueBefore, 6000, "unexpected pool value before");
        assertEq(poolValueAfter, 5500, "unexpected pool value after");
        assertEq(poolValueBefore - poolValueAfter, 500, "pool value should decrease by amount due remaining");
    }


    function test_emergencyWithdrawCollateral_does_not_change_totalPrincipalTokensRepaid() public {
        initialize_group_contract();

        uint256 bidId = 0;
        uint256 amountDueRemaining = 1000;

        uint256 originalTotalPrincipalTokensRepaid = 2000;
        lenderCommitmentGroupSmart.set_totalPrincipalTokensRepaid(originalTotalPrincipalTokensRepaid);
        lenderCommitmentGroupSmart.set_totalPrincipalTokensLended(4000);
        lenderCommitmentGroupSmart.set_totalPrincipalTokensCommitted(6000);
        lenderCommitmentGroupSmart.set_mockActiveBidsAmountDueRemaining(bidId, amountDueRemaining);
        lenderCommitmentGroupSmart.set_mockBidAsActiveForGroup(bidId, true);

        _tellerV2.setMockOwner(address(this));
        lenderCommitmentGroupSmart.pauseLiquidations();

        lenderCommitmentGroupSmart.emergencyWithdrawCollateral(bidId);

        uint256 totalPrincipalTokensRepaid = lenderCommitmentGroupSmart.totalPrincipalTokensRepaid();

        // totalPrincipalTokensRepaid should NOT change — outstanding stays inflated to block new loans
        assertEq(totalPrincipalTokensRepaid, originalTotalPrincipalTokensRepaid, "totalPrincipalTokensRepaid should not change");

        // outstanding should still include the emergency-withdrawn loan
        uint256 outstanding = lenderCommitmentGroupSmart.getTotalPrincipalTokensOutstandingInActiveLoans();
        assertEq(outstanding, 4000 - 2000, "outstanding should remain unchanged");
    }

}

contract User {}
