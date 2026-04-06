// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "../tests/util/FoundryTest.sol";
import "forge-std/console.sol";
import "forge-std/StdJson.sol";

import { LenderCommitmentGroup_Pool_V3 } from "../contracts/LenderCommitmentForwarder/extensions/LenderCommitmentGroup/LenderCommitmentGroup_Pool_V3.sol";
import { LenderCommitmentGroupFactory_V3 } from "../contracts/LenderCommitmentForwarder/extensions/LenderCommitmentGroup/LenderCommitmentGroup_Factory_V3.sol";
import { ILenderCommitmentGroup_V3 } from "../contracts/interfaces/ILenderCommitmentGroup_V3.sol";
import { PriceAdapterAlgebra } from "../contracts/price_adapters/PriceAdapterAlgebra.sol";

import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

/**
 * @title ApeChain Pool V3 Fork Test
 * @notice End-to-end test of Pool V3 + PriceAdapterAlgebra + Camelot V3.
 *
 * Proves that Blocker #1 (Algebra oracle incompatibility) is resolved:
 *   Pool V3 → IPriceAdapter → PriceAdapterAlgebra → globalState()/getTimepoints() → Camelot V3
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

interface IAlgebraPool_V3Test {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function globalState() external view returns (
        uint160 price, int24 tick, uint16 feeZto, uint16 feeOtz,
        uint16 timepointIndex, uint8 communityFeeToken0,
        uint8 communityFeeToken1, bool unlocked
    );
}

interface IMarketRegistry_V3 {
    function createMarket(
        address _initialOwner, uint32 _paymentCycleDuration,
        uint32 _paymentDefaultDuration, uint32 _bidExpirationTime,
        uint16 _feePercent, bool _requireLenderAttestation,
        bool _requireBorrowerAttestation, string calldata _uri
    ) external returns (uint256 marketId_);
}

interface ITellerV2_V3 {
    function marketRegistry() external view returns (address);
    function setTrustedMarketForwarder(uint256 _marketId, address _forwarder) external;
    function approveMarketForwarder(uint256 _marketId, address _forwarder) external;
}

interface IERC4626_Simple {
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    function totalAssets() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
}

contract ApeChain_PoolsV3_Fork_Test is Test {

    string constant NETWORK_NAME = "apechain";

    address constant CAMELOT_V3_FACTORY = 0x10aA510d94E094Bd643677bd2964c3EE085Daffc;
    address constant WAPE = 0x48b62137EdfA95a428D35C09E44256a739F6B557;
    address constant ApeUSD = 0xA2235d059F80e176D931Ef76b6C51953Eb3fBEf4;

    ITellerV2_V3 tellerV2;
    IMarketRegistry_V3 marketRegistry;
    address smartCommitmentForwarder;

    PriceAdapterAlgebra priceAdapter;
    LenderCommitmentGroupFactory_V3 factoryV3;
    address beaconAddress;

    uint256 marketId;

    address camelotPool;
    bool zeroForOne;
    uint8 apeUsdDecimals;
    uint8 wapeDecimals;

    using stdJson for string;

    function getDeployedAddress(string memory contractName) internal view returns (address) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/deployments/", NETWORK_NAME, "/", contractName, ".json");
        string memory json = vm.readFile(path);
        return json.readAddress(".address");
    }

    function setUp() public {
        // Load already-deployed TellerV2 and SmartCommitmentForwarder
        tellerV2 = ITellerV2_V3(getDeployedAddress("TellerV2"));
        smartCommitmentForwarder = getDeployedAddress("SmartCommitmentForwarder");
        marketRegistry = IMarketRegistry_V3(tellerV2.marketRegistry());

        assertTrue(address(tellerV2).code.length > 0, "TellerV2 not found");
        assertTrue(smartCommitmentForwarder.code.length > 0, "SCF not found");

        // Deploy PriceAdapterAlgebra fresh
        priceAdapter = new PriceAdapterAlgebra();

        // Deploy Pool V3 implementation
        LenderCommitmentGroup_Pool_V3 poolImpl = new LenderCommitmentGroup_Pool_V3(
            address(tellerV2),
            smartCommitmentForwarder
        );

        // Deploy UpgradeableBeacon
        UpgradeableBeacon beacon = new UpgradeableBeacon(address(poolImpl));
        beaconAddress = address(beacon);

        // Deploy Factory V3 (use a minimal proxy pattern — deploy and initialize)
        factoryV3 = new LenderCommitmentGroupFactory_V3();
        factoryV3.initialize(beaconAddress);

        // Create market and set trusted forwarder
        marketId = marketRegistry.createMarket(
            address(this), 2592000, 2592000, 86400, 0, false, false, ""
        );
        tellerV2.setTrustedMarketForwarder(marketId, smartCommitmentForwarder);

        // Look up Camelot V3 WAPE/ApeUSD pool
        camelotPool = IAlgebraFactory(CAMELOT_V3_FACTORY).poolByPair(WAPE, ApeUSD);
        require(camelotPool != address(0), "No WAPE/ApeUSD Camelot pool");

        IAlgebraPool_V3Test pool = IAlgebraPool_V3Test(camelotPool);
        zeroForOne = (pool.token0() == ApeUSD);
        apeUsdDecimals = IERC20_APE(ApeUSD).decimals();
        wapeDecimals = IERC20_APE(WAPE).decimals();
    }

    // ============ Helpers ============

    function _getApeUSD(address to, uint256 amount) internal {
        vm.prank(camelotPool);
        IERC20_APE(ApeUSD).transfer(to, amount);
    }

    function _buildPriceAdapterRoute() internal view returns (bytes memory) {
        IAlgebraPool_V3Test pool = IAlgebraPool_V3Test(camelotPool);

        PriceAdapterAlgebra.PoolRoute[] memory routes = new PriceAdapterAlgebra.PoolRoute[](1);
        routes[0] = PriceAdapterAlgebra.PoolRoute({
            pool: camelotPool,
            zeroForOne: zeroForOne,
            twapInterval: 5,
            token0Decimals: pool.token0() == ApeUSD ? apeUsdDecimals : wapeDecimals,
            token1Decimals: pool.token1() == ApeUSD ? apeUsdDecimals : wapeDecimals
        });

        return priceAdapter.encodePoolRoutes(routes);
    }

    function _deployPoolV3(uint256 initialDeposit) internal returns (address) {
        ILenderCommitmentGroup_V3.CommitmentGroupConfig memory config = ILenderCommitmentGroup_V3.CommitmentGroupConfig({
            principalTokenAddress: ApeUSD,
            collateralTokenAddress: WAPE,
            marketId: marketId,
            maxLoanDuration: 604800,
            interestRateLowerBound: 6000,
            interestRateUpperBound: 11000,
            liquidityThresholdPercent: 8000,
            collateralRatio: 15000
        });

        bytes memory route = _buildPriceAdapterRoute();

        _getApeUSD(address(this), initialDeposit);
        IERC20_APE(ApeUSD).approve(address(factoryV3), initialDeposit);

        return factoryV3.deployLenderCommitmentGroupPool(
            initialDeposit,
            config,
            address(priceAdapter),
            route
        );
    }

    // ============ Tests ============

    /// @notice PriceAdapterAlgebra can register route and return a nonzero price
    function test_priceAdapterAlgebra_works() public {
        bytes memory route = _buildPriceAdapterRoute();
        bytes32 routeHash = priceAdapter.registerPriceRoute(route);

        uint256 priceRatioQ96 = priceAdapter.getPriceRatioQ96(routeHash);
        assertGt(priceRatioQ96, 0, "Price ratio should be nonzero");

        console.log("PriceAdapterAlgebra priceRatioQ96:", priceRatioQ96);
        console.log("Route hash:", uint256(routeHash));
    }

    /// @notice Deploy pool via Factory V3 with PriceAdapterAlgebra + initial deposit
    function test_deployPool_succeeds() public {
        uint256 initialDeposit = 100 * 10**apeUsdDecimals;
        address pool = _deployPoolV3(initialDeposit);

        assertTrue(pool != address(0), "Pool should be deployed");
        assertTrue(pool.code.length > 0, "Pool should have code");

        console.log("Pool V3 deployed:", pool);
        console.log("Pool totalAssets:", IERC4626_Simple(pool).totalAssets());
        console.log("Pool totalSupply:", IERC4626_Simple(pool).totalSupply());
    }

    /// @notice Full pricing path: Pool V3 -> IPriceAdapter -> PriceAdapterAlgebra -> Camelot V3
    function test_pool_collateralCalculation_works() public {
        uint256 initialDeposit = 100 * 10**apeUsdDecimals;
        address pool = _deployPoolV3(initialDeposit);

        LenderCommitmentGroup_Pool_V3 poolV3 = LenderCommitmentGroup_Pool_V3(payable(pool));

        uint256 principalAmount = 10 * 10**apeUsdDecimals;
        uint256 collateralNeeded = poolV3.calculateCollateralTokensAmountEquivalentToPrincipalTokens(principalAmount);

        assertGt(collateralNeeded, 0, "Collateral calculation should be nonzero");

        console.log("Principal amount:", principalAmount);
        console.log("Collateral needed:", collateralNeeded);
        console.log("Full pricing path works: Pool V3 -> IPriceAdapter -> PriceAdapterAlgebra -> Camelot V3");
    }

    /// @notice Pool reports available liquidity after initial deposit
    function test_pool_getPrincipalAvailableToBorrow() public {
        uint256 initialDeposit = 100 * 10**apeUsdDecimals;
        address pool = _deployPoolV3(initialDeposit);

        LenderCommitmentGroup_Pool_V3 poolV3 = LenderCommitmentGroup_Pool_V3(payable(pool));

        uint256 available = poolV3.getPrincipalAmountAvailableToBorrow();
        assertGt(available, 0, "Pool should have liquidity available");

        console.log("Available to borrow:", available);
        console.log("Total assets:", IERC4626_Simple(pool).totalAssets());
    }
}
