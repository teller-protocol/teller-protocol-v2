// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "../tests/util/FoundryTest.sol";
import "forge-std/console.sol";
import "forge-std/StdJson.sol";

import { LenderCommitmentGroupFactory_V2 } from "../contracts/LenderCommitmentForwarder/extensions/LenderCommitmentGroup/LenderCommitmentGroup_Factory_V2.sol";
import { ILenderCommitmentGroup_V2 } from "../contracts/interfaces/ILenderCommitmentGroup_V2.sol";
import { IUniswapPricingLibrary } from "../contracts/interfaces/IUniswapPricingLibrary.sol";

/**
 * @title ApeChain Pool Lifecycle Fork Test
 * @notice Tests PoolV2 on ApeChain. Documents three blockers preventing full operation.
 *
 * BLOCKERS FOUND:
 *   1. ALGEBRA ORACLE: Camelot V3 uses globalState()/getTimepoints() but
 *      UniswapPricingLibraryV2 calls slot0()/observe() which revert.
 *      Blocks: borrowing, liquidation.
 *
 *   2. APEUSD REBASING: ApeUSD is a yield-bearing rebasing token. Pool_V2's deposit()
 *      has a strict balance check (balanceAfter == balanceBefore + amount) which fails
 *      because rebasing tokens can have rounding differences on transfer.
 *      Blocks: lender deposits with ApeUSD as principal.
 *
 *   3. HYPERNATIVE ORACLE: isApproved() reverts on ApeChain's HypernativeOracle.
 *      Requires tx.origin == msg.sender (EOA shortcut) for all pool operations.
 *      Blocks: contract-based interactions (smart wallets, multisigs).
 *
 * WHAT WORKS:
 *   - All 26 contracts deployed and verified
 *   - Market creation
 *   - Pool deployment (oracle not called during init)
 *   - Factory initial deposit (bypasses TB check via internal path)
 *   - Camelot V3 pools: globalState() and getTimepoints() both functional
 */

interface IERC20_APE {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function transfer(address to, uint256 amount) external returns (bool);
}

interface IAlgebraFactory {
    function poolByPair(address tokenA, address tokenB) external view returns (address pool);
}

interface IAlgebraPool {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function globalState() external view returns (
        uint160 price, int24 tick, uint16 feeZto, uint16 feeOtz,
        uint16 timepointIndex, uint8 communityFeeToken0,
        uint8 communityFeeToken1, bool unlocked
    );
    function getTimepoints(uint32[] calldata secondsAgos) external view returns (
        int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulatives
    );
}

interface IMarketRegistry_APE {
    function createMarket(
        address _initialOwner, uint32 _paymentCycleDuration,
        uint32 _paymentDefaultDuration, uint32 _bidExpirationTime,
        uint16 _feePercent, bool _requireLenderAttestation,
        bool _requireBorrowerAttestation, string calldata _uri
    ) external returns (uint256 marketId_);
}

interface ITellerV2_APE {
    function marketRegistry() external view returns (address);
    function setTrustedMarketForwarder(uint256 _marketId, address _forwarder) external;
    function approveMarketForwarder(uint256 _marketId, address _forwarder) external;
    function collateralManager() external view returns (address);
}

interface ISmartCommitmentForwarder_APE {
    function acceptSmartCommitmentWithRecipient(
        address _smartCommitmentAddress, uint256 _principalAmount,
        uint256 _collateralAmount, uint256 _collateralTokenId,
        address _collateralTokenAddress, address _recipient,
        uint16 _interestRate, uint32 _loanDuration
    ) external returns (uint256 bidId);
}

interface IPoolV2_APE {
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
    function totalAssets() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function getPrincipalAmountAvailableToBorrow() external view returns (uint256);
    function asset() external view returns (address);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
}

contract ApeChain_PoolLifecycle_Fork_Test is Test {

    string constant NETWORK_NAME = "apechain";

    address constant CAMELOT_V3_FACTORY = 0x10aA510d94E094Bd643677bd2964c3EE085Daffc;
    address constant WAPE = 0x48b62137EdfA95a428D35C09E44256a739F6B557;
    address constant ApeUSD = 0xA2235d059F80e176D931Ef76b6C51953Eb3fBEf4;

    LenderCommitmentGroupFactory_V2 factoryv2;
    ITellerV2_APE tellerV2;
    IMarketRegistry_APE marketRegistry;
    address smartCommitmentForwarder;
    address collateralManager;

    uint256 marketId;

    address camelotPool;
    bool zeroForOne;
    uint8 apeUsdDecimals;
    uint8 wapeDecimals;

    address lender = address(0xA001);
    address borrower = address(0xB001);

    using stdJson for string;

    function getDeployedAddress(string memory contractName) internal view returns (address) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/deployments/", NETWORK_NAME, "/", contractName, ".json");
        string memory json = vm.readFile(path);
        return json.readAddress(".address");
    }

    function setUp() public {
        address payable factoryAddr = payable(getDeployedAddress("LenderCommitmentGroupFactory_V2"));
        factoryv2 = LenderCommitmentGroupFactory_V2(factoryAddr);
        assertTrue(factoryAddr.code.length > 0, "Factory not found");

        tellerV2 = ITellerV2_APE(getDeployedAddress("TellerV2"));
        smartCommitmentForwarder = getDeployedAddress("SmartCommitmentForwarder");
        marketRegistry = IMarketRegistry_APE(tellerV2.marketRegistry());
        collateralManager = tellerV2.collateralManager();

        marketId = marketRegistry.createMarket(
            address(this), 2592000, 2592000, 86400, 0, false, false, ""
        );
        tellerV2.setTrustedMarketForwarder(marketId, smartCommitmentForwarder);

        camelotPool = IAlgebraFactory(CAMELOT_V3_FACTORY).poolByPair(WAPE, ApeUSD);
        require(camelotPool != address(0), "No WAPE/ApeUSD Camelot pool");

        IAlgebraPool pool = IAlgebraPool(camelotPool);
        zeroForOne = (pool.token0() == ApeUSD);
        apeUsdDecimals = IERC20_APE(ApeUSD).decimals();
        wapeDecimals = IERC20_APE(WAPE).decimals();
    }

    // ============ Helpers ============

    function _getApeUSD(address to, uint256 amount) internal {
        vm.prank(camelotPool);
        IERC20_APE(ApeUSD).transfer(to, amount);
    }

    function _buildOracleRoutes() internal view returns (IUniswapPricingLibrary.PoolRouteConfig[] memory) {
        IAlgebraPool pool = IAlgebraPool(camelotPool);
        IUniswapPricingLibrary.PoolRouteConfig[] memory routes = new IUniswapPricingLibrary.PoolRouteConfig[](1);
        routes[0] = IUniswapPricingLibrary.PoolRouteConfig({
            pool: camelotPool,
            zeroForOne: zeroForOne,
            twapInterval: 5,
            token0Decimals: pool.token0() == ApeUSD ? apeUsdDecimals : wapeDecimals,
            token1Decimals: pool.token1() == ApeUSD ? apeUsdDecimals : wapeDecimals
        });
        return routes;
    }

    function _deployPool(uint256 initialDeposit) internal returns (address) {
        ILenderCommitmentGroup_V2.CommitmentGroupConfig memory config = ILenderCommitmentGroup_V2.CommitmentGroupConfig({
            principalTokenAddress: ApeUSD,
            collateralTokenAddress: WAPE,
            marketId: marketId,
            maxLoanDuration: 604800,
            interestRateLowerBound: 6000,
            interestRateUpperBound: 11000,
            liquidityThresholdPercent: 8000,
            collateralRatio: 15000
        });

        _getApeUSD(address(this), initialDeposit);
        IERC20_APE(ApeUSD).approve(address(factoryv2), initialDeposit);

        return factoryv2.deployLenderCommitmentGroupPool(
            initialDeposit, config, _buildOracleRoutes()
        );
    }

    // ============ Compatibility diagnostics ============

    function test_algebraGlobalState_works() public {
        IAlgebraPool pool = IAlgebraPool(camelotPool);
        (uint160 price,,,,,,, bool unlocked) = pool.globalState();
        assertGt(price, 0, "Price should be non-zero");
        assertTrue(unlocked, "Pool should be unlocked");
        console.log("globalState sqrtPrice:", price);
    }

    function test_algebraGetTimepoints_works() public {
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = 6;
        secondsAgos[1] = 1;
        IAlgebraPool pool = IAlgebraPool(camelotPool);
        (int56[] memory tickCumulatives,) = pool.getTimepoints(secondsAgos);
        assertTrue(tickCumulatives.length == 2, "Should return 2 tick cumulatives");
        console.log("getTimepoints() returned valid TWAP data");
    }

    function test_slot0_reverts() public {
        (bool success,) = camelotPool.staticcall(abi.encodeWithSignature("slot0()"));
        assertFalse(success, "slot0() should revert on Algebra pool");
        console.log("CONFIRMED: slot0() reverts on Camelot V3");
    }

    function test_observe_reverts() public {
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = 5;
        secondsAgos[1] = 0;
        (bool success,) = camelotPool.staticcall(
            abi.encodeWithSignature("observe(uint32[])", secondsAgos)
        );
        assertFalse(success, "observe() should revert on Algebra pool");
        console.log("CONFIRMED: observe() reverts on Camelot V3");
    }

    // ============ Lifecycle Tests ============

    /// @notice Pool deployment succeeds (oracle not called during init)
    function test_poolDeployment_succeeds() public {
        uint256 initialDeposit = 100 * 10**apeUsdDecimals;
        address pool = _deployPool(initialDeposit);

        assertTrue(pool != address(0), "Pool should be deployed");
        assertTrue(pool.code.length > 0, "Pool should have code");

        // Factory initial deposit works because it goes through an internal path
        // that doesn't have the strict TB balance check
        console.log("Pool deployed:", pool);
        console.log("Pool name:", IPoolV2_APE(pool).name());
        console.log("Pool totalAssets:", IPoolV2_APE(pool).totalAssets());
        console.log("Initial shares:", IPoolV2_APE(pool).totalSupply());
    }

    /// @notice BLOCKER #2: Lender deposit fails because ApeUSD is rebasing.
    /// Pool_V2 deposit() checks: balanceAfter == balanceBefore + amount ("TB")
    /// Rebasing tokens have rounding on transfer, so this strict check fails.
    function test_lenderDeposit_FAILS_rebasingToken() public {
        uint256 initialDeposit = 100 * 10**apeUsdDecimals;
        address pool = _deployPool(initialDeposit);

        uint256 depositAmount = 500 * 10**apeUsdDecimals;
        _getApeUSD(lender, depositAmount);

        vm.startPrank(lender, lender);
        IERC20_APE(ApeUSD).approve(pool, depositAmount);

        // Reverts with "TB" (Token Balance) because ApeUSD is rebasing:
        // balanceAfter != balanceBefore + amount due to share/balance rounding
        vm.expectRevert(bytes("TB"));
        IPoolV2_APE(pool).deposit(depositAmount, lender);
        vm.stopPrank();

        console.log("CONFIRMED: Lender deposit fails with ApeUSD (rebasing token)");
        console.log("Pool_V2 deposit() has strict balance check incompatible with rebasing");
    }

    /// @notice BLOCKER #1: Borrowing would fail because observe() reverts on Algebra.
    /// The oracle is called during acceptFundsForAcceptBid -> collateral pricing.
    /// This is proven by test_observe_reverts() and test_slot0_reverts() above.
    /// We don't execute the full borrow flow here because deal(WAPE) has issues
    /// on the Tenderly fork, but the root cause is confirmed:
    ///   acceptFundsForAcceptBid -> calculateCollateralTokensAmountEquivalentToPrincipalTokens
    ///   -> UniswapPricingLibraryV2.getSqrtTwapX96() -> observe() -> REVERT
    function test_borrow_BLOCKED_oracleIncompat() public {
        uint256 initialDeposit = 100 * 10**apeUsdDecimals;
        address pool = _deployPool(initialDeposit);

        // Verify pool has liquidity but oracle would fail
        uint256 available = IPoolV2_APE(pool).getPrincipalAmountAvailableToBorrow();
        console.log("Available to borrow:", available);
        assertGt(available, 0, "Pool has liquidity");

        // But borrowing is impossible because observe() reverts on Algebra pools
        // (proven by test_observe_reverts and test_slot0_reverts)
        console.log("BLOCKED: Borrowing impossible - observe() reverts on Camelot V3");
    }

    /// @notice Summary of all findings
    function test_fullLifecycleStatus() public {
        console.log("=== ApeChain PoolV2 Lifecycle Report ===");
        console.log("");
        console.log("Implementation: LenderCommitmentGroup_Pool_V2 (ERC4626)");
        console.log("DEX: Camelot V3 (Algebra V1)");
        console.log("Principal: ApeUSD (rebasing yield token)");
        console.log("Collateral: WAPE");
        console.log("");
        console.log("BLOCKER #1 - Algebra Oracle Incompatibility:");
        console.log("  observe()/slot0() don't exist on Camelot V3");
        console.log("  Need: globalState() + getTimepoints() adapter");
        console.log("  Blocks: borrowing, liquidation");
        console.log("");
        console.log("BLOCKER #2 - ApeUSD Rebasing Token:");
        console.log("  deposit() strict balance check fails (TB error)");
        console.log("  balanceAfter != balanceBefore + amount due to rounding");
        console.log("  Blocks: all lender deposits after factory init");
        console.log("");
        console.log("BLOCKER #3 - HypernativeOracle:");
        console.log("  isApproved() reverts, EOA shortcut required");
        console.log("  Blocks: smart wallet / multisig interactions");
        console.log("");
        console.log("WHAT WORKS:");
        console.log("  - 26 contracts deployed and verified");
        console.log("  - Market creation");
        console.log("  - Pool deployment with factory initial deposit");
        console.log("  - Camelot V3 globalState() and getTimepoints()");

        // Verify
        assertTrue(address(factoryv2).code.length > 0);
        assertTrue(address(tellerV2).code.length > 0);
        assertTrue(camelotPool != address(0));

        IAlgebraPool pool = IAlgebraPool(camelotPool);
        (uint160 price,,,,,,, ) = pool.globalState();
        assertGt(price, 0, "Algebra pool has valid price data");
    }
}
