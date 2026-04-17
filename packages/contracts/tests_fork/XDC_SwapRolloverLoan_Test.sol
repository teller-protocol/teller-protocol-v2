// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "../tests/util/FoundryTest.sol";
import "forge-std/console.sol";
import "forge-std/StdJson.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { SwapRolloverLoan } from "../contracts/LenderCommitmentForwarder/extensions/rollover/SwapRolloverLoan.sol";
import { SwapRolloverLoan_G2 } from "../contracts/LenderCommitmentForwarder/extensions/rollover/SwapRolloverLoan_G2.sol";
import { ITellerV2 } from "../contracts/interfaces/ITellerV2.sol";

import { LenderCommitmentGroupFactory_V2 } from "../contracts/LenderCommitmentForwarder/extensions/LenderCommitmentGroup/LenderCommitmentGroup_Factory_V2.sol";
import { ILenderCommitmentGroup_V2 } from "../contracts/interfaces/ILenderCommitmentGroup_V2.sol";
import { IUniswapPricingLibrary } from "../contracts/interfaces/IUniswapPricingLibrary.sol";

interface IUniswapV3Pool_XDC_Rollover {
    function flash(address recipient, uint256 amount0, uint256 amount1, bytes calldata data) external;
    function token0() external view returns (address);
    function token1() external view returns (address);
    function fee() external view returns (uint24);
    function slot0() external view returns (
        uint160 sqrtPriceX96, int24 tick, uint16 observationIndex,
        uint16 observationCardinality, uint16 observationCardinalityNext,
        uint8 feeProtocol, bool unlocked
    );
}

interface IUniswapV3Factory_XDC_Rollover {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool);
}

interface IERC20_Rollover {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
}

interface IMarketRegistry_Rollover {
    function createMarket(
        address _initialOwner, uint32 _paymentCycleDuration,
        uint32 _paymentDefaultDuration, uint32 _bidExpirationTime,
        uint16 _feePercent, bool _requireLenderAttestation,
        bool _requireBorrowerAttestation, string calldata _uri
    ) external returns (uint256 marketId_);
}

interface ITellerV2_Rollover {
    function marketRegistry() external view returns (address);
    function setTrustedMarketForwarder(uint256 _marketId, address _forwarder) external;
    function approveMarketForwarder(uint256 _marketId, address _forwarder) external;
    function getLoanBorrower(uint256 _bidId) external view returns (address);
    function getLoanLendingToken(uint256 _bidId) external view returns (address);
    function getBidState(uint256 _bidId) external view returns (uint8);
    function collateralManager() external view returns (address);
}

interface ISmartCommitmentForwarder_Rollover {
    function acceptSmartCommitmentWithRecipient(
        address _smartCommitmentAddress,
        uint256 _principalAmount,
        uint256 _collateralAmount,
        uint256 _collateralTokenId,
        address _collateralTokenAddress,
        address _recipient,
        uint16 _interestRate,
        uint32 _loanDuration
    ) external returns (uint256 bidId);

    function addExtension(address extension) external;
}

interface IPoolV2_Rollover {
    function addPrincipalToCommitmentGroup(
        uint256 _amount, address _sharesRecipient, uint256 _minSharesAmountOut
    ) external returns (uint256 sharesAmount_);
    function getPrincipalAmountAvailableToBorrow() external view returns (uint256);
}

/**
 * @title XDC SwapRolloverLoan Fork Test
 * @notice End-to-end rollover test on XDC Network with official Uniswap V3.
 *
 * Tests the full flow:
 *   1. Deploy a lending pool and fund it
 *   2. Borrower takes loan #1 from the pool
 *   3. Borrower rollovers loan #1 into loan #2 via flash swap
 *
 * Also includes compatibility/diagnostic tests for Uniswap V3 on XDC.
 *
 * Run with:
 *   FOUNDRY_PROFILE=fork forge test --match-contract XDC_SwapRolloverLoan_Test -vvvv \
 *     --fork-url https://rpc.xdc.org
 */
contract XDC_SwapRolloverLoan_Test is Test {

    string constant NETWORK_NAME = "xdc";

    using stdJson for string;

    // XDC addresses
    address constant WXDC = 0x951857744785E80e2De051c32EE7b25f9c458C42;
    address constant USDC = 0xfA2958CB79b0491CC627c1557F441eF849Ca8eb1; // Circle native USDC
    address constant UNISWAP_V3_FACTORY = 0xcb2436774C3e191c85056d248EF4260ce5f27A9D;

    SwapRolloverLoan swapRolloverLoan;
    ISmartCommitmentForwarder_Rollover smartCommitmentForwarder;
    ITellerV2_Rollover tellerV2;
    LenderCommitmentGroupFactory_V2 factoryV2;
    address collateralManager;

    address uniPool;
    uint24 activeFee;
    bool usdcIsToken0;

    uint8 usdcDecimals;
    uint8 wxdcDecimals;

    // Test actors
    address lender = address(0xA001);
    address borrower = address(0xB001);

    function getDeployedAddress(string memory contractName) internal view returns (address) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/deployments/", NETWORK_NAME, "/", contractName, ".json");
        string memory json = vm.readFile(path);
        return json.readAddress(".address");
    }

    function setUp() public {
        // Load deployed contracts
        swapRolloverLoan = SwapRolloverLoan(payable(getDeployedAddress("SwapRolloverLoan")));
        smartCommitmentForwarder = ISmartCommitmentForwarder_Rollover(getDeployedAddress("SmartCommitmentForwarder"));
        tellerV2 = ITellerV2_Rollover(getDeployedAddress("TellerV2"));
        factoryV2 = LenderCommitmentGroupFactory_V2(payable(getDeployedAddress("LenderCommitmentGroupFactory_V2")));
        collateralManager = tellerV2.collateralManager();

        assertTrue(address(swapRolloverLoan).code.length > 0, "SwapRolloverLoan not deployed");
        assertTrue(address(smartCommitmentForwarder).code.length > 0, "SmartCommitmentForwarder not deployed");

        console.log("SwapRolloverLoan:", address(swapRolloverLoan));
        console.log("TellerV2:", address(tellerV2));

        // Find active USDC/WXDC pool
        IUniswapV3Factory_XDC_Rollover factory = IUniswapV3Factory_XDC_Rollover(UNISWAP_V3_FACTORY);
        uint24[] memory fees = new uint24[](3);
        fees[0] = 500;
        fees[1] = 3000;
        fees[2] = 10000;

        for (uint i = 0; i < fees.length; i++) {
            address candidate = factory.getPool(USDC, WXDC, fees[i]);
            if (candidate != address(0) && candidate.code.length > 0) {
                uniPool = candidate;
                activeFee = fees[i];
                break;
            }
        }
        require(uniPool != address(0), "No USDC/WXDC pool found on Uniswap V3 (XDC)");

        IUniswapV3Pool_XDC_Rollover pool = IUniswapV3Pool_XDC_Rollover(uniPool);
        usdcIsToken0 = (pool.token0() == USDC);
        usdcDecimals = IERC20_Rollover(USDC).decimals();
        wxdcDecimals = IERC20_Rollover(WXDC).decimals();

        console.log("Uniswap V3 USDC/WXDC pool:", uniPool, "fee:", activeFee);
    }

    // ============ Helpers ============

    function _createMarketAndPool(uint256 initialDeposit, uint256 lenderAmount)
        internal returns (uint256 marketId, address pool)
    {
        IMarketRegistry_Rollover marketRegistry = IMarketRegistry_Rollover(tellerV2.marketRegistry());

        // Create market
        marketId = marketRegistry.createMarket(
            address(this), 2592000, 2592000, 86400, 0, false, false, ""
        );
        tellerV2.setTrustedMarketForwarder(marketId, address(smartCommitmentForwarder));

        // Build oracle routes
        IUniswapV3Pool_XDC_Rollover uniPoolI = IUniswapV3Pool_XDC_Rollover(uniPool);
        IUniswapPricingLibrary.PoolRouteConfig[] memory routes = new IUniswapPricingLibrary.PoolRouteConfig[](1);
        routes[0] = IUniswapPricingLibrary.PoolRouteConfig({
            pool: uniPool,
            zeroForOne: usdcIsToken0,
            twapInterval: 5,
            token0Decimals: uniPoolI.token0() == USDC ? usdcDecimals : wxdcDecimals,
            token1Decimals: uniPoolI.token1() == USDC ? usdcDecimals : wxdcDecimals
        });

        // Deploy pool with initial deposit
        ILenderCommitmentGroup_V2.CommitmentGroupConfig memory config = ILenderCommitmentGroup_V2.CommitmentGroupConfig({
            principalTokenAddress: USDC,
            collateralTokenAddress: WXDC,
            marketId: marketId,
            maxLoanDuration: 604800,
            interestRateLowerBound: 100,
            interestRateUpperBound: 11000,
            liquidityThresholdPercent: 8000,
            collateralRatio: 15000
        });

        deal(USDC, address(this), initialDeposit);
        IERC20(USDC).approve(address(factoryV2), initialDeposit);
        pool = factoryV2.deployLenderCommitmentGroupPool(initialDeposit, config, routes);

        // Lender deposits additional liquidity
        deal(USDC, lender, lenderAmount);
        vm.startPrank(lender);
        IERC20(USDC).approve(pool, lenderAmount);
        IPoolV2_Rollover(pool).addPrincipalToCommitmentGroup(lenderAmount, lender, 0);
        vm.stopPrank();

        console.log("Pool deployed:", pool);
        console.log("Available to borrow:", IPoolV2_Rollover(pool).getPrincipalAmountAvailableToBorrow());
    }

    function _borrowFromPool(
        uint256 marketId,
        address pool,
        uint256 principalAmount,
        uint256 collateralAmount
    ) internal returns (uint256 bidId) {
        deal(WXDC, borrower, collateralAmount);

        vm.startPrank(borrower);
        IERC20(WXDC).approve(collateralManager, collateralAmount);
        tellerV2.approveMarketForwarder(marketId, address(smartCommitmentForwarder));

        bidId = smartCommitmentForwarder.acceptSmartCommitmentWithRecipient(
            pool,
            principalAmount,
            collateralAmount,
            0,
            WXDC,
            borrower,
            1000, // 10% interest
            604800 // 1 week
        );
        vm.stopPrank();

        console.log("Loan created, bid ID:", bidId);
    }

    function _bytecodeContainsSelector(bytes memory code, bytes4 selector) internal pure returns (bool) {
        if (code.length < 4) return false;
        for (uint256 i = 0; i < code.length - 3; i++) {
            if (code[i] == selector[0] &&
                code[i+1] == selector[1] &&
                code[i+2] == selector[2] &&
                code[i+3] == selector[3]) {
                return true;
            }
        }
        return false;
    }

    // ============ Compatibility Tests ============

    function test_uniswapV3_flash_exists() public {
        IUniswapV3Pool_XDC_Rollover pool = IUniswapV3Pool_XDC_Rollover(uniPool);
        (uint160 sqrtPriceX96,,,,,, bool unlocked) = pool.slot0();
        assertGt(sqrtPriceX96, 0, "Pool has valid price");
        assertTrue(unlocked, "Pool is unlocked");
        console.log("Uniswap V3 pool is active, flash() available");
    }

    function test_factory_getPool_works() public {
        IUniswapV3Factory_XDC_Rollover factory = IUniswapV3Factory_XDC_Rollover(UNISWAP_V3_FACTORY);
        address pool = factory.getPool(USDC, WXDC, activeFee);
        assertEq(pool, uniPool, "Should resolve pool via getPool");
    }

    function test_deployed_callback_selectors() public {
        address impl = address(uint160(uint256(vm.load(
            address(swapRolloverLoan),
            bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
        ))));

        bytes memory implCode = impl.code;
        bytes4 uniswapSelector = bytes4(keccak256("uniswapV3FlashCallback(uint256,uint256,bytes)"));
        assertTrue(_bytecodeContainsSelector(implCode, uniswapSelector), "Should have uniswapV3FlashCallback");
    }

    function test_fresh_impl_has_all_callbacks() public {
        SwapRolloverLoan freshImpl = new SwapRolloverLoan(
            address(tellerV2), UNISWAP_V3_FACTORY, WXDC
        );

        bytes memory implCode = address(freshImpl).code;
        bytes4 uniswapSelector = bytes4(keccak256("uniswapV3FlashCallback(uint256,uint256,bytes)"));
        bytes4 pancakeSelector = bytes4(keccak256("pancakeV3FlashCallback(uint256,uint256,bytes)"));
        bytes4 algebraSelector = bytes4(keccak256("algebraFlashCallback(uint256,uint256,bytes)"));

        assertTrue(_bytecodeContainsSelector(implCode, uniswapSelector), "Has uniswapV3FlashCallback");
        assertTrue(_bytecodeContainsSelector(implCode, pancakeSelector), "Has pancakeV3FlashCallback");
        assertTrue(_bytecodeContainsSelector(implCode, algebraSelector), "Has algebraFlashCallback");
    }

    function test_swapRolloverLoan_resolves_pool() public {
        SwapRolloverLoan freshImpl = new SwapRolloverLoan(
            address(tellerV2), UNISWAP_V3_FACTORY, WXDC
        );
        address resolved = freshImpl.getUniswapPoolAddress(USDC, WXDC, activeFee);
        assertEq(resolved, uniPool, "Should resolve Uniswap V3 pool");
    }

    // ============ End-to-End Rollover Test ============

    /**
     * @notice Full rollover flow:
     *   1. Create pool, fund it with USDC
     *   2. Borrower takes loan #1 (USDC principal, WXDC collateral)
     *   3. Time passes (interest accrues)
     *   4. Borrower rollovers loan #1 → loan #2 via flash swap
     *
     * The flash swap:
     *   - Borrows USDC from Uniswap V3 pool
     *   - Repays loan #1 in full
     *   - Accepts new commitment from same pool (loan #2)
     *   - Repays flash loan + fee from new loan proceeds
     *   - Remaining dust goes to borrower
     */
    function test_rollover_end_to_end() public {
        // --- Step 1: Create pool with liquidity ---
        uint256 initialDeposit = 500 * 10**usdcDecimals;
        uint256 lenderDeposit  = 2000 * 10**usdcDecimals;
        (uint256 marketId, address pool) = _createMarketAndPool(initialDeposit, lenderDeposit);

        // --- Step 2: Borrower takes loan #1 ---
        uint256 borrowAmount = 200 * 10**usdcDecimals;
        uint256 collateralAmount = 5000 ether; // WXDC
        uint256 loanId1 = _borrowFromPool(marketId, pool, borrowAmount, collateralAmount);

        assertEq(tellerV2.getLoanBorrower(loanId1), borrower, "Borrower owns loan #1");
        console.log("Loan #1 state:", tellerV2.getBidState(loanId1));

        // --- Step 3: Time passes ---
        vm.warp(block.timestamp + 1 days);

        // --- Step 4: Borrower registers SwapRolloverLoan as extension ---
        vm.prank(borrower);
        smartCommitmentForwarder.addExtension(address(swapRolloverLoan));

        // Deal extra USDC to borrower for flash fee + interest delta
        uint256 borrowerContribution = 50 * 10**usdcDecimals;
        deal(USDC, borrower, borrowerContribution);

        // Need fresh collateral for the new loan
        deal(WXDC, borrower, collateralAmount);

        // --- Step 5: Approve tokens ---
        vm.startPrank(borrower);
        // Approve borrower contribution to SwapRolloverLoan
        IERC20(USDC).approve(address(swapRolloverLoan), borrowerContribution);
        // Approve collateral for new loan
        IERC20(WXDC).approve(collateralManager, collateralAmount);
        vm.stopPrank();

        // --- Step 6: Build rollover args ---
        IUniswapV3Pool_XDC_Rollover uniPoolI = IUniswapV3Pool_XDC_Rollover(uniPool);
        address token0 = uniPoolI.token0();
        address token1 = uniPoolI.token1();

        // Flash borrow USDC to repay old loan
        bool borrowToken1 = (token1 == USDC);
        uint256 flashAmount = 250 * 10**usdcDecimals; // Enough to cover principal + interest

        SwapRolloverLoan_G2.FlashSwapArgs memory flashSwapArgs = SwapRolloverLoan_G2.FlashSwapArgs({
            token0: token0,
            token1: token1,
            fee: activeFee,
            flashAmount: flashAmount,
            borrowToken1: borrowToken1
        });

        SwapRolloverLoan_G2.AcceptCommitmentArgs memory acceptArgs = SwapRolloverLoan_G2.AcceptCommitmentArgs({
            commitmentId: 0,
            smartCommitmentAddress: pool,
            principalAmount: 200 * 10**usdcDecimals,
            collateralAmount: collateralAmount,
            collateralTokenId: 0,
            collateralTokenAddress: WXDC,
            interestRate: 1000,
            loanDuration: 604800,
            merkleProof: new bytes32[](0)
        });

        // --- Step 7: Execute rollover ---
        uint256 borrowerUsdcBefore = IERC20(USDC).balanceOf(borrower);

        vm.prank(borrower);
        swapRolloverLoan.rolloverLoanWithFlashSwap(
            address(smartCommitmentForwarder),
            loanId1,
            borrowerContribution,
            flashSwapArgs,
            acceptArgs
        );

        // --- Step 8: Verify results ---
        uint256 borrowerUsdcAfter = IERC20(USDC).balanceOf(borrower);

        // Old loan should be repaid (state != ACCEPTED)
        uint8 oldLoanState = tellerV2.getBidState(loanId1);
        console.log("Loan #1 state after rollover:", oldLoanState);
        assertTrue(oldLoanState != 4, "Old loan should no longer be ACCEPTED");

        console.log("Borrower USDC before:", borrowerUsdcBefore);
        console.log("Borrower USDC after:", borrowerUsdcAfter);
        console.log("Rollover complete!");
    }
}
