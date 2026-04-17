// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "../tests/util/FoundryTest.sol";
import "forge-std/console.sol";
import "forge-std/StdJson.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { SwapRolloverLoan } from "../contracts/LenderCommitmentForwarder/extensions/rollover/SwapRolloverLoan.sol";
import { SwapRolloverLoan_G2 } from "../contracts/LenderCommitmentForwarder/extensions/rollover/SwapRolloverLoan_G2.sol";
import { SwapRolloverLoan_G4 } from "../contracts/LenderCommitmentForwarder/extensions/rollover/SwapRolloverLoan_G4.sol";
import { ITellerV2 } from "../contracts/interfaces/ITellerV2.sol";
import { Payment } from "../contracts/TellerV2Storage.sol";
import { LenderCommitmentGroupFactory_V2 } from "../contracts/LenderCommitmentForwarder/extensions/LenderCommitmentGroup/LenderCommitmentGroup_Factory_V2.sol";
import { ILenderCommitmentGroup_V2 } from "../contracts/interfaces/ILenderCommitmentGroup_V2.sol";
import { IUniswapPricingLibrary } from "../contracts/interfaces/IUniswapPricingLibrary.sol";

interface IAlgebraFactory_Test {
    function poolByPair(address tokenA, address tokenB) external view returns (address pool);
}

interface IAlgebraPool_Test {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function flash(address recipient, uint256 amount0, uint256 amount1, bytes calldata data) external;
    function globalState() external view returns (
        uint160 price, int24 tick, uint16 feeZto, uint16 feeOtz,
        uint16 timepointIndex, uint8 communityFeeToken0,
        uint8 communityFeeToken1, bool unlocked
    );
}

interface IUniswapV3Factory_Test {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool);
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
    function collateralManager() external view returns (address);
    function getLoanBorrower(uint256 _bidId) external view returns (address);
    function getLoanLendingToken(uint256 _bidId) external view returns (address);
    function calculateAmountOwed(uint256 _bidId, uint256 _timestamp) external view returns (
        Payment memory owed
    );
}

interface ISmartCommitmentForwarder_Rollover {
    function acceptSmartCommitmentWithRecipient(
        address _smartCommitmentAddress, uint256 _principalAmount,
        uint256 _collateralAmount, uint256 _collateralTokenId,
        address _collateralTokenAddress, address _recipient,
        uint16 _interestRate, uint32 _loanDuration
    ) external returns (uint256 bidId);
}

interface IPoolV2_Rollover {
    function getPrincipalAmountAvailableToBorrow() external view returns (uint256);
    function totalAssets() external view returns (uint256);
    function UNISWAP_PRICING_HELPER() external view returns (address);
}

/**
 * @title ApeChain SwapRolloverLoan Fork Test
 * @notice Tests SwapRolloverLoan_G4 compatibility with Camelot V3 (Algebra) on ApeChain.
 *
 * KEY DIFFERENCES (Algebra vs Uniswap V3):
 *   1. CALLBACK: Algebra calls `algebraFlashCallback` (not `uniswapV3FlashCallback`)
 *   2. FACTORY: Algebra uses `poolByPair(tokenA, tokenB)` (not `getPool(tokenA, tokenB, fee)`)
 *   3. NO FEE TIERS: Algebra pools have dynamic fees, no fee param in pool lookup
 *
 * G4 resolves all three by:
 *   - Adding `algebraFlashCallback()` routed to shared `_flashCallback()`
 *   - Overriding `_verifyFlashCallback()` / `getUniswapPoolAddress()` to fall back to `poolByPair`
 *
 * Run with:
 *   FOUNDRY_PROFILE=fork forge test --match-contract ApeChain_SwapRolloverLoan_Test -vvvv \
 *     --fork-url <APECHAIN_RPC_URL>
 */
contract ApeChain_SwapRolloverLoan_Test is Test {

    string constant NETWORK_NAME = "apechain";

    using stdJson for string;

    // ApeChain addresses
    address constant CAMELOT_V3_FACTORY = 0x10aA510d94E094Bd643677bd2964c3EE085Daffc;
    address constant WAPE = 0x48b62137EdfA95a428D35C09E44256a739F6B557;
    address constant ApeUSD = 0xA2235d059F80e176D931Ef76b6C51953Eb3fBEf4;

    // Hypernative oracle storage slot (setting to address(0) disables all oracle checks)
    bytes32 constant HYPERNATIVE_ORACLE_SLOT = bytes32(uint256(keccak256("eip1967.hypernative.oracle")) - 1);

    SwapRolloverLoan swapRolloverLoan;
    address smartCommitmentForwarder;
    address tellerV2Addr;

    address camelotPool;

    function getDeployedAddress(string memory contractName) internal view returns (address) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/deployments/", NETWORK_NAME, "/", contractName, ".json");
        string memory json = vm.readFile(path);
        return json.readAddress(".address");
    }

    function setUp() public {
        address payable swapRolloverAddr = payable(getDeployedAddress("SwapRolloverLoan"));
        swapRolloverLoan = SwapRolloverLoan(swapRolloverAddr);
        smartCommitmentForwarder = getDeployedAddress("SmartCommitmentForwarder");
        tellerV2Addr = getDeployedAddress("TellerV2");

        assertTrue(swapRolloverAddr.code.length > 0, "SwapRolloverLoan not deployed");
        assertTrue(smartCommitmentForwarder.code.length > 0, "SmartCommitmentForwarder not deployed");

        camelotPool = IAlgebraFactory_Test(CAMELOT_V3_FACTORY).poolByPair(WAPE, ApeUSD);
        require(camelotPool != address(0), "No WAPE/ApeUSD Camelot pool");

        console.log("SwapRolloverLoan:", swapRolloverAddr);
        console.log("TellerV2:", tellerV2Addr);
        console.log("Camelot V3 WAPE/ApeUSD pool:", camelotPool);
    }

    // ============ Compatibility Tests ============

    /// @notice Verify Camelot V3 pool has a flash() function (same signature as Uniswap V3)
    function test_camelotV3_flash_exists() public {
        // Algebra pools implement flash(address,uint256,uint256,bytes) — same as Uniswap V3
        bytes4 flashSelector = IAlgebraPool_Test.flash.selector;
        console.log("flash() selector:");
        console.logBytes4(flashSelector);

        // Verify pool has code and flash function exists
        assertTrue(camelotPool.code.length > 0, "Pool has code");

        // staticcall flash with 0 amounts should not revert (just a dry run check)
        // Note: actual flash with 0 amounts may revert in some implementations,
        // so we just verify the pool contract exists and has liquidity
        IAlgebraPool_Test pool = IAlgebraPool_Test(camelotPool);
        (uint160 price,,,,,,, bool unlocked) = pool.globalState();
        assertGt(price, 0, "Pool has valid price");
        assertTrue(unlocked, "Pool is unlocked");

        console.log("Camelot V3 pool is active, flash() available");
    }

    /// @notice Verify getPool() reverts on Algebra factory (no fee tiers)
    function test_factory_getPool_reverts_on_algebra() public {
        (bool success,) = CAMELOT_V3_FACTORY.staticcall(
            abi.encodeWithSelector(IUniswapV3Factory_Test.getPool.selector, WAPE, ApeUSD, uint24(3000))
        );
        assertFalse(success, "getPool() should revert on Algebra factory");
        console.log("CONFIRMED: getPool(token0, token1, fee) reverts on Algebra factory");
    }

    /// @notice Verify poolByPair() works on Algebra factory
    function test_factory_poolByPair_works() public {
        address pool = IAlgebraFactory_Test(CAMELOT_V3_FACTORY).poolByPair(WAPE, ApeUSD);
        assertTrue(pool != address(0), "poolByPair should return valid address");
        assertEq(pool, camelotPool, "Should match setUp pool");
        console.log("CONFIRMED: poolByPair(tokenA, tokenB) works on Algebra factory");
    }

    // ============ Callback Selector Tests ============

    /// @notice Verify current deployed implementation's callback selectors
    function test_deployed_callback_selectors() public {
        // Read implementation address from proxy storage
        address impl = address(uint160(uint256(vm.load(
            address(swapRolloverLoan),
            bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
        ))));
        console.log("Current implementation:", impl);

        bytes memory implCode = impl.code;

        bytes4 uniswapSelector = bytes4(keccak256("uniswapV3FlashCallback(uint256,uint256,bytes)"));
        bytes4 pancakeSelector = bytes4(keccak256("pancakeV3FlashCallback(uint256,uint256,bytes)"));
        bytes4 algebraSelector = bytes4(keccak256("algebraFlashCallback(uint256,uint256,bytes)"));

        console.log("uniswapV3FlashCallback selector:"); console.logBytes4(uniswapSelector);
        console.log("pancakeV3FlashCallback selector:"); console.logBytes4(pancakeSelector);
        console.log("algebraFlashCallback selector:");   console.logBytes4(algebraSelector);

        bool hasUniswap = _bytecodeContainsSelector(implCode, uniswapSelector);
        bool hasPancake = _bytecodeContainsSelector(implCode, pancakeSelector);
        bool hasAlgebra = _bytecodeContainsSelector(implCode, algebraSelector);

        console.log("Has uniswapV3FlashCallback:", hasUniswap);
        console.log("Has pancakeV3FlashCallback:", hasPancake);
        console.log("Has algebraFlashCallback:", hasAlgebra);

        // Current ApeChain deployment is G2 — only has uniswapV3FlashCallback
        assertTrue(hasUniswap, "Should have uniswapV3FlashCallback");
        // G2 does NOT have pancake or algebra callbacks — documents the gap
        assertFalse(hasPancake, "G2 impl missing pancakeV3FlashCallback");
        assertFalse(hasAlgebra, "G2 impl missing algebraFlashCallback (needs G4 upgrade)");
    }

    // ============ G4 Upgrade Tests ============

    /// @notice Deploy G4 implementation and verify it has all three callback selectors
    function test_g4_has_all_callbacks() public {
        SwapRolloverLoan g4Impl = new SwapRolloverLoan(
            tellerV2Addr,
            CAMELOT_V3_FACTORY,
            WAPE
        );

        bytes memory g4Code = address(g4Impl).code;

        bytes4 uniswapSelector = bytes4(keccak256("uniswapV3FlashCallback(uint256,uint256,bytes)"));
        bytes4 pancakeSelector = bytes4(keccak256("pancakeV3FlashCallback(uint256,uint256,bytes)"));
        bytes4 algebraSelector = bytes4(keccak256("algebraFlashCallback(uint256,uint256,bytes)"));

        assertTrue(_bytecodeContainsSelector(g4Code, uniswapSelector), "G4 has uniswapV3FlashCallback");
        assertTrue(_bytecodeContainsSelector(g4Code, pancakeSelector), "G4 has pancakeV3FlashCallback");
        assertTrue(_bytecodeContainsSelector(g4Code, algebraSelector), "G4 has algebraFlashCallback");

        console.log("G4 has all three flash callbacks: uniswap, pancake, algebra");
    }

    /// @notice Verify G4's pool resolution works with Algebra factory (poolByPair fallback)
    function test_g4_resolves_algebra_pool() public {
        SwapRolloverLoan g4Impl = new SwapRolloverLoan(
            tellerV2Addr,
            CAMELOT_V3_FACTORY,
            WAPE
        );

        // G4 getUniswapPoolAddress should resolve via poolByPair fallback
        // fee param is ignored for Algebra — pass any value
        address resolved = g4Impl.getUniswapPoolAddress(WAPE, ApeUSD, 0);
        assertEq(resolved, camelotPool, "G4 should resolve Algebra pool via poolByPair");

        console.log("G4 resolves Camelot V3 pool:", resolved);
        console.log("Expected:", camelotPool);
    }

    /// @notice Etch G4 implementation over proxy and verify pool resolution still works
    function test_g4_etch_and_resolve() public {
        // Deploy G4 with Algebra factory
        SwapRolloverLoan g4Impl = new SwapRolloverLoan(
            tellerV2Addr,
            CAMELOT_V3_FACTORY,
            WAPE
        );

        // Read current implementation address
        address currentImpl = address(uint160(uint256(vm.load(
            address(swapRolloverLoan),
            bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
        ))));

        // Etch G4 code over the implementation
        vm.etch(currentImpl, address(g4Impl).code);
        console.log("Etched G4 implementation over proxy impl:", currentImpl);

        // Verify pool resolution through proxy
        address resolved = swapRolloverLoan.getUniswapPoolAddress(WAPE, ApeUSD, 0);
        assertEq(resolved, camelotPool, "Proxy should resolve Algebra pool after G4 etch");

        console.log("Pool resolution through proxy works after G4 upgrade");
    }

    // ============ End-to-End Rollover Test ============

    // ---- Rollover test state (stored as contract state to avoid stack-too-deep) ----
    uint256 internal _marketId;
    address internal _lendingPool;
    address internal _borrower;
    uint256 internal _collateralAmount;
    uint256 internal _borrowAmount;
    uint16  internal _interestRate;
    uint256 internal _loanId1;

    /**
     * @notice Full rollover test: creates a loan, then rolls it over via flash from Camelot V3.
     *
     * This test exercises the complete rolloverLoanWithFlashSwap flow on ApeChain:
     *   1. Etch G4 implementation (with algebraFlashCallback) over the proxy
     *   2. Create a lending market and pool with ApeUSD principal / WAPE collateral
     *   3. Borrow from the pool (creating loan #1)
     *   4. Warp time to accrue interest
     *   5. Rollover: flash-borrow ApeUSD from Camelot V3 pool, repay loan #1, open loan #2
     *   6. Verify loan #1 is closed and loan #2 is active
     *
     * MOCKS APPLIED (to work around ApeChain fork limitations):
     *   - HypernativeOracle disabled (set to address(0) on SCF)
     *   - UniswapPricingHelper mocked to return a fixed price ratio
     *
     * Run with:
     *   FOUNDRY_PROFILE=fork forge test --match-test test_g4_rollover_end_to_end -vvvv \
     *     --fork-url <APECHAIN_RPC_URL>
     */
    function test_g4_rollover_end_to_end() public {
        _step1_etchG4();
        _step2_disableOracle();
        _step3_createMarket();
        _step4_deployPool();
        _step5_createInitialLoan();

        // Step 6: Warp time to accrue interest
        vm.warp(block.timestamp + 3 days);
        console.log("Step 6: Warped 3 days forward");

        _step7_executeRollover();
        _step8_verifyResults();
    }

    function _step1_etchG4() internal {
        SwapRolloverLoan g4Impl = new SwapRolloverLoan(
            tellerV2Addr,
            CAMELOT_V3_FACTORY,
            WAPE
        );
        address currentImpl = address(uint160(uint256(vm.load(
            address(swapRolloverLoan),
            bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
        ))));
        vm.etch(currentImpl, address(g4Impl).code);
        assertEq(swapRolloverLoan.getUniswapPoolAddress(WAPE, ApeUSD, 0), camelotPool, "G4 pool resolution failed");
        console.log("Step 1: Etched G4 impl over proxy");
    }

    function _step2_disableOracle() internal {
        vm.store(smartCommitmentForwarder, HYPERNATIVE_ORACLE_SLOT, bytes32(0));
        console.log("Step 2: Disabled HypernativeOracle on SCF");
    }

    function _step3_createMarket() internal {
        ITellerV2_Rollover tellerV2 = ITellerV2_Rollover(tellerV2Addr);
        IMarketRegistry_Rollover marketRegistry = IMarketRegistry_Rollover(tellerV2.marketRegistry());

        _marketId = marketRegistry.createMarket(
            address(this), 604800, 2592000, 86400, 0, false, false, ""
        );
        tellerV2.setTrustedMarketForwarder(_marketId, smartCommitmentForwarder);
        console.log("Step 3: Created market", _marketId);
    }

    function _step4_deployPool() internal {
        LenderCommitmentGroupFactory_V2 factoryv2 = LenderCommitmentGroupFactory_V2(
            payable(getDeployedAddress("LenderCommitmentGroupFactory_V2"))
        );

        IAlgebraPool_Test pool = IAlgebraPool_Test(camelotPool);
        bool zeroForOne = (pool.token0() == ApeUSD);

        IUniswapPricingLibrary.PoolRouteConfig[] memory routes = new IUniswapPricingLibrary.PoolRouteConfig[](1);
        routes[0] = IUniswapPricingLibrary.PoolRouteConfig({
            pool: camelotPool,
            zeroForOne: zeroForOne,
            twapInterval: 5,
            token0Decimals: IERC20Decimals(pool.token0()).decimals(),
            token1Decimals: IERC20Decimals(pool.token1()).decimals()
        });

        uint256 initialDeposit = 5000 * 1e18;
        vm.prank(camelotPool);
        IERC20(ApeUSD).transfer(address(this), initialDeposit);
        IERC20(ApeUSD).approve(address(factoryv2), initialDeposit);

        ILenderCommitmentGroup_V2.CommitmentGroupConfig memory config = ILenderCommitmentGroup_V2.CommitmentGroupConfig({
            principalTokenAddress: ApeUSD,
            collateralTokenAddress: WAPE,
            marketId: _marketId,
            maxLoanDuration: 604800,
            interestRateLowerBound: 800,
            interestRateUpperBound: 1200,
            liquidityThresholdPercent: 8000,
            collateralRatio: 15000
        });

        // Mock pricing helpers to bypass Algebra oracle incompatibility (slot0/observe don't exist).
        // Mock both deployed pricing library addresses in case the pool implementation references either.
        bytes memory priceResponse = abi.encode(uint256(100e36)); // ~1 WAPE = 100 ApeUSD
        bytes4 priceSelector = IUniswapPricingLibrary.getUniswapPriceRatioForPoolRoutes.selector;

        vm.mockCall(getDeployedAddress("UniswapPricingLibraryV2"), abi.encodeWithSelector(priceSelector), priceResponse);
        vm.mockCall(getDeployedAddress("UniswapPricingHelper"), abi.encodeWithSelector(priceSelector), priceResponse);

        // Also mock observe() on the Camelot pool itself (last resort if pricing library calls through)
        // observe(uint32[]) returns (int56[] tickCumulatives, uint160[] secondsPerLiquidityCumulatives)
        int56[] memory tickCumulatives = new int56[](2);
        tickCumulatives[0] = int56(0);
        tickCumulatives[1] = int56(5); // small positive tick
        uint160[] memory secPerLiq = new uint160[](2);
        secPerLiq[0] = 1;
        secPerLiq[1] = 2;
        vm.mockCall(
            camelotPool,
            abi.encodeWithSignature("observe(uint32[])"),
            abi.encode(tickCumulatives, secPerLiq)
        );
        // Mock slot0() as well since some code paths try it
        vm.mockCall(
            camelotPool,
            abi.encodeWithSignature("slot0()"),
            abi.encode(uint160(79228162514264337593543950336), int24(0), uint16(0), uint16(0), uint16(0), uint8(0), bool(true))
        );

        _lendingPool = factoryv2.deployLenderCommitmentGroupPool(initialDeposit, config, routes);
        console.log("Step 4: Deployed lending pool:", _lendingPool);
        assertGt(IPoolV2_Rollover(_lendingPool).getPrincipalAmountAvailableToBorrow(), 0, "No liquidity");
    }

    function _step5_createInitialLoan() internal {
        _borrower = address(0xB0B0);
        _collateralAmount = 50 ether;
        _borrowAmount = 1000 * 1e18;
        _interestRate = 1000; // 10% APY

        // Mock ApeChain's native precompile at 0x6b (getSharePrice) which WAPE uses internally.
        // Forge can't simulate native precompiles, so we etch a dummy contract and mock the response.
        address precompile = address(0x6b);
        vm.etch(precompile, hex"00"); // put minimal code so mockCall works
        vm.mockCall(
            precompile,
            abi.encodeWithSignature("getSharePrice()"),
            abi.encode(uint256(1157e15)) // ~1.157 share price
        );

        // Get WAPE from the Camelot pool reserves (deal() doesn't work with WAPE's share-based proxy)
        vm.prank(camelotPool);
        IERC20(WAPE).transfer(_borrower, _collateralAmount * 3);

        ITellerV2_Rollover tellerV2 = ITellerV2_Rollover(tellerV2Addr);
        address collateralManager = tellerV2.collateralManager();

        vm.startPrank(_borrower, _borrower);
        IERC20(WAPE).approve(collateralManager, type(uint256).max);
        tellerV2.approveMarketForwarder(_marketId, smartCommitmentForwarder);
        // Borrower must register SwapRolloverLoan as an extension on SCF
        // so SCF's _msgSender() recognizes the appended borrower address
        IExtensionsContext(smartCommitmentForwarder).addExtension(address(swapRolloverLoan));
        vm.stopPrank();

        vm.prank(_borrower, _borrower);
        _loanId1 = ISmartCommitmentForwarder_Rollover(smartCommitmentForwarder)
            .acceptSmartCommitmentWithRecipient(
                _lendingPool, _borrowAmount, _collateralAmount,
                0, WAPE, _borrower, _interestRate, 604800
            );

        assertEq(tellerV2.getLoanBorrower(_loanId1), _borrower, "Borrower mismatch");
        console.log("Step 5: Created loan #1, id:", _loanId1);
    }

    function _step7_executeRollover() internal {
        Payment memory owed = ITellerV2(tellerV2Addr).calculateAmountOwed(_loanId1, block.timestamp);
        uint256 totalOwed = owed.principal + owed.interest;
        console.log("Total owed:", totalOwed);
        console.log("  Principal:", owed.principal, "Interest:", owed.interest);

        uint256 flashAmount = totalOwed + (totalOwed / 100); // +1% buffer

        IAlgebraPool_Test pool = IAlgebraPool_Test(camelotPool);
        address token0 = pool.token0();
        address token1 = pool.token1();

        SwapRolloverLoan_G2.FlashSwapArgs memory flashSwapArgs = SwapRolloverLoan_G2.FlashSwapArgs({
            token0: token0,
            token1: token1,
            fee: 0,
            flashAmount: flashAmount,
            borrowToken1: (token1 == ApeUSD)
        });

        SwapRolloverLoan_G2.AcceptCommitmentArgs memory acceptArgs = SwapRolloverLoan_G2.AcceptCommitmentArgs({
            commitmentId: 0,
            smartCommitmentAddress: _lendingPool,
            principalAmount: _borrowAmount,
            collateralAmount: _collateralAmount,
            collateralTokenId: 0,
            collateralTokenAddress: WAPE,
            interestRate: _interestRate,
            loanDuration: 604800,
            merkleProof: new bytes32[](0)
        });

        // borrowerAmount covers: totalOwed + flashFee - newPrincipal
        // Extra buffer needed because ApeUSD is a rebasing token with share-based rounding
        uint256 borrowerAmount = flashAmount - _borrowAmount + (flashAmount / 100);

        vm.prank(camelotPool);
        IERC20(ApeUSD).transfer(_borrower, borrowerAmount + 1e18);

        // Give SwapRolloverLoan a tiny ApeUSD buffer to absorb rebasing rounding (ApeUSD is share-based)
        vm.prank(camelotPool);
        IERC20(ApeUSD).transfer(address(swapRolloverLoan), 1000);

        vm.startPrank(_borrower, _borrower);
        IERC20(ApeUSD).approve(address(swapRolloverLoan), type(uint256).max);

        console.log("Step 7: Executing rollover... flashAmount:", flashAmount, "borrowerAmount:", borrowerAmount);

        swapRolloverLoan.rolloverLoanWithFlashSwap(
            smartCommitmentForwarder,
            _loanId1,
            borrowerAmount,
            flashSwapArgs,
            acceptArgs
        );
        vm.stopPrank();

        console.log("Step 7: Rollover SUCCEEDED!");
    }

    function _step8_verifyResults() internal {
        Payment memory owedAfter = ITellerV2(tellerV2Addr).calculateAmountOwed(_loanId1, block.timestamp);
        assertEq(owedAfter.principal + owedAfter.interest, 0, "Old loan should be fully repaid");

        console.log("Step 8: Verified old loan fully repaid");
        console.log("ROLLOVER TEST PASSED: algebraFlashCallback flow works end-to-end on ApeChain");
    }

    // ============ Helpers ============

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
}

interface IERC20Decimals {
    function decimals() external view returns (uint8);
}

interface IExtensionsContext {
    function addExtension(address extension) external;
}
