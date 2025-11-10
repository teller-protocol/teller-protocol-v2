// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "../tests/util/FoundryTest.sol";
import "forge-std/console.sol";

// Import the PriceAdapterAerodrome contract
import { PriceAdapterAerodrome } from "../contracts/price_adapters/PriceAdapterAerodrome.sol";
import { IUniswapV3Pool } from "../contracts/interfaces/uniswap/IUniswapV3Pool.sol";

/**
 * @title PoolsV3_Aerodrome_Fork_Test
 * @notice Tests for PriceAdapterAerodrome using a live Aerodrome pool on Base
 * @dev This test suite validates the price adapter's functionality with real pool data
 */
contract PoolsV3_Aerodrome_Fork_Test is Test {

    string constant NETWORK_NAME = "base";

    // Aerodrome pool address on Base with .observe and .slot0 support
    address constant AERODROME_POOL = 0x6cDcb1C4A4D1C3C6d054b27AC5B77e89eAFb971d;

    PriceAdapterAerodrome public priceAdapter;
    IUniswapV3Pool public pool;

    // Variables to store pool info
    address token0;
    address token1;
    uint8 token0Decimals;
    uint8 token1Decimals;

    function setUp() public {
        // Fork Base network (Aerodrome is on Base)
      //  string memory baseRpcUrl = vm.envOr("BASE_RPC_URL", string("https://mainnet.base.org"));
     //   vm.createSelectFork(baseRpcUrl);

        // Deploy the PriceAdapterAerodrome contract
        priceAdapter = new PriceAdapterAerodrome();

        // Connect to the pool
        pool = IUniswapV3Pool(AERODROME_POOL);

        // Verify the pool has code
        assertTrue(AERODROME_POOL.code.length > 0, "Pool should have code");

        // Get token addresses from the pool
        token0 = pool.token0();
        token1 = pool.token1();

        console.log("Pool address:", AERODROME_POOL);
        console.log("Token0:", token0);
        console.log("Token1:", token1);

        // Get token decimals (would need ERC20 interface to get these properly)
        // For now, assuming standard 18 decimals
        token0Decimals = 18;
        token1Decimals = 18;
    }

    /**
     * @notice Test that the pool supports slot0() function
     * @dev This is required for getting current price without TWAP
     */
    function test_pool_has_slot0() public   {
        (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        ) = pool.slot0();

        assertTrue(sqrtPriceX96 > 0, "sqrtPriceX96 should be greater than 0");
        console.log("Current sqrtPriceX96:", sqrtPriceX96);
        console.log("Current tick:", uint256(int256(tick)));
        console.log("Observation cardinality:", observationCardinality);
    }

    /**
     * @notice Test that the pool supports observe() function
     * @dev This is required for TWAP price calculations
     */
    function test_pool_has_observe() public   {
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = 3600; // 1 hour ago
        secondsAgos[1] = 0;    // now

        (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s) = pool.observe(secondsAgos);

        assertEq(tickCumulatives.length, 2, "Should return 2 tick cumulatives");
        assertEq(secondsPerLiquidityCumulativeX128s.length, 2, "Should return 2 liquidity cumulatives");

        console.log("Tick cumulative (1h ago):", uint256(int256(tickCumulatives[0])));
        console.log("Tick cumulative (now):", uint256(int256(tickCumulatives[1])));
    }

    /**
     * @notice Test registering a price route with the Aerodrome pool
     */
    function test_register_price_route() public {
        // Create a single-hop route (token0 -> token1)
        PriceAdapterAerodrome.PoolRoute[] memory routes = new PriceAdapterAerodrome.PoolRoute[](1);
        routes[0] = PriceAdapterAerodrome.PoolRoute({
            pool: AERODROME_POOL,
            zeroForOne: true,
            twapInterval: 0,
            token0Decimals: token0Decimals,
            token1Decimals: token1Decimals
        });

        // Encode the route
        bytes memory encodedRoute = priceAdapter.encodePoolRoutes(routes);

        // Register the route
        bytes32 routeHash = priceAdapter.registerPriceRoute(encodedRoute);

        // Verify the route was stored
        bytes memory storedRoute = priceAdapter.priceRoutes(routeHash);
        assertEq(storedRoute.length, encodedRoute.length, "Route should be stored");

        console.log("Route hash:");
        console.logBytes32(routeHash);
    }

    /**
     * @notice Test getting current price (slot0, no TWAP)
     * @dev Tests with twapInterval = 0 which uses slot0()
     */
    function test_get_current_price_token0_to_token1() public {
        // Create route for token0 -> token1
        PriceAdapterAerodrome.PoolRoute[] memory routes = new PriceAdapterAerodrome.PoolRoute[](1);
        routes[0] = PriceAdapterAerodrome.PoolRoute({
            pool: AERODROME_POOL,
            zeroForOne: true,
            twapInterval: 0, // Use current price via slot0
            token0Decimals: token0Decimals,
            token1Decimals: token1Decimals
        });

        bytes memory encodedRoute = priceAdapter.encodePoolRoutes(routes);
        bytes32 routeHash = priceAdapter.registerPriceRoute(encodedRoute);

        // Get the price
        uint256 priceRatioQ96 = priceAdapter.getPriceRatioQ96(routeHash);

        assertTrue(priceRatioQ96 > 0, "Price should be greater than 0");

        // Convert Q96 to human readable (divide by 2^96)
        uint256 priceQ96Divisor = 2 ** 96;
        uint256 priceScaled = (priceRatioQ96 * 1e18) / priceQ96Divisor;

        console.log("Price (token0/token1) Q96:", priceRatioQ96);
        console.log("Price (scaled by 1e18):", priceScaled);
    }

    /**
     * @notice Test getting current price in reverse direction (token1 -> token0)
     */
    function test_get_current_price_token1_to_token0() public {
        // Create route for token1 -> token0 (inverse)
        PriceAdapterAerodrome.PoolRoute[] memory routes = new PriceAdapterAerodrome.PoolRoute[](1);
        routes[0] = PriceAdapterAerodrome.PoolRoute({
            pool: AERODROME_POOL,
            zeroForOne: false, // Inverse direction
            twapInterval: 0,
            token0Decimals: token0Decimals,
            token1Decimals: token1Decimals
        });

        bytes memory encodedRoute = priceAdapter.encodePoolRoutes(routes);
        bytes32 routeHash = priceAdapter.registerPriceRoute(encodedRoute);

        uint256 priceRatioQ96 = priceAdapter.getPriceRatioQ96(routeHash);

        assertTrue(priceRatioQ96 > 0, "Price should be greater than 0");

        uint256 priceQ96Divisor = 2 ** 96;
        uint256 priceScaled = (priceRatioQ96 * 1e18) / priceQ96Divisor;

        console.log("Price (token1/token0) Q96:", priceRatioQ96);
        console.log("Price (scaled by 1e18):", priceScaled);
    }

    /**
     * @notice Test getting TWAP price
     * @dev Tests with twapInterval > 0 which uses observe()
     */
    function test_get_twap_price() public {
        // Create route with 1 hour TWAP
        PriceAdapterAerodrome.PoolRoute[] memory routes = new PriceAdapterAerodrome.PoolRoute[](1);
        routes[0] = PriceAdapterAerodrome.PoolRoute({
            pool: AERODROME_POOL,
            zeroForOne: true,
            twapInterval: 3600, // 1 hour TWAP
            token0Decimals: token0Decimals,
            token1Decimals: token1Decimals
        });

        bytes memory encodedRoute = priceAdapter.encodePoolRoutes(routes);
        bytes32 routeHash = priceAdapter.registerPriceRoute(encodedRoute);

        uint256 priceRatioQ96 = priceAdapter.getPriceRatioQ96(routeHash);

        assertTrue(priceRatioQ96 > 0, "TWAP price should be greater than 0");

        uint256 priceQ96Divisor = 2 ** 96;
        uint256 priceScaled = (priceRatioQ96 * 1e18) / priceQ96Divisor;

        console.log("TWAP Price (1h) Q96:", priceRatioQ96);
        console.log("TWAP Price (scaled by 1e18):", priceScaled);
    }

    /**
     * @notice Test two-hop route (chaining two pools)
     * @dev This tests the multi-hop pricing functionality
     */
    function test_two_hop_route() public {
        // Create a two-hop route using the same pool twice (just for testing)
        PriceAdapterAerodrome.PoolRoute[] memory routes = new PriceAdapterAerodrome.PoolRoute[](2);
        routes[0] = PriceAdapterAerodrome.PoolRoute({
            pool: AERODROME_POOL,
            zeroForOne: true,
            twapInterval: 0,
            token0Decimals: token0Decimals,
            token1Decimals: token1Decimals
        });
        routes[1] = PriceAdapterAerodrome.PoolRoute({
            pool: AERODROME_POOL,
            zeroForOne: false, // Go back
            twapInterval: 0,
            token0Decimals: token0Decimals,
            token1Decimals: token1Decimals
        });

        bytes memory encodedRoute = priceAdapter.encodePoolRoutes(routes);
        bytes32 routeHash = priceAdapter.registerPriceRoute(encodedRoute);

        uint256 priceRatioQ96 = priceAdapter.getPriceRatioQ96(routeHash);

        assertTrue(priceRatioQ96 > 0, "Two-hop price should be greater than 0");

        // This should be close to 2^96 (1.0) since we go there and back
        uint256 priceQ96Divisor = 2 ** 96;
        uint256 priceScaled = (priceRatioQ96 * 1e18) / priceQ96Divisor;

        console.log("Two-hop Price Q96:", priceRatioQ96);
        console.log("Two-hop Price (scaled by 1e18):", priceScaled);
        console.log("Expected ~1e18 (should be close)");
    }

    /**
     * @notice Test that decoding validates route length
     */
    function test_decode_rejects_invalid_route_length() public {
        // Try to create a route with 3 pools (should fail)
        PriceAdapterAerodrome.PoolRoute[] memory routes = new PriceAdapterAerodrome.PoolRoute[](3);
        routes[0] = PriceAdapterAerodrome.PoolRoute({
            pool: AERODROME_POOL,
            zeroForOne: true,
            twapInterval: 0,
            token0Decimals: token0Decimals,
            token1Decimals: token1Decimals
        });
        routes[1] = routes[0];
        routes[2] = routes[0];

        bytes memory encodedRoute = abi.encode(routes);

        vm.expectRevert("Route must have 1 or 2 pools");
        priceAdapter.decodePoolRoutes(encodedRoute);
    }

    /**
     * @notice Test that getPriceRatioQ96 reverts for unregistered route
     */
    function test_get_price_reverts_for_unregistered_route() public {
        bytes32 fakeRouteHash = keccak256("fake route");

        vm.expectRevert("Route not found");
        priceAdapter.getPriceRatioQ96(fakeRouteHash);
    }

    /**
     * @notice Test price comparison between current and TWAP
     */
    function test_compare_current_vs_twap_price() public {
        // Get current price
        PriceAdapterAerodrome.PoolRoute[] memory currentRoute = new PriceAdapterAerodrome.PoolRoute[](1);
        currentRoute[0] = PriceAdapterAerodrome.PoolRoute({
            pool: AERODROME_POOL,
            zeroForOne: true,
            twapInterval: 0,
            token0Decimals: token0Decimals,
            token1Decimals: token1Decimals
        });

        bytes memory encodedCurrentRoute = priceAdapter.encodePoolRoutes(currentRoute);
        bytes32 currentRouteHash = priceAdapter.registerPriceRoute(encodedCurrentRoute);
        uint256 currentPrice = priceAdapter.getPriceRatioQ96(currentRouteHash);

        // Get TWAP price
        PriceAdapterAerodrome.PoolRoute[] memory twapRoute = new PriceAdapterAerodrome.PoolRoute[](1);
        twapRoute[0] = PriceAdapterAerodrome.PoolRoute({
            pool: AERODROME_POOL,
            zeroForOne: true,
            twapInterval: 3600,
            token0Decimals: token0Decimals,
            token1Decimals: token1Decimals
        });

        bytes memory encodedTwapRoute = priceAdapter.encodePoolRoutes(twapRoute);
        bytes32 twapRouteHash = priceAdapter.registerPriceRoute(encodedTwapRoute);
        uint256 twapPrice = priceAdapter.getPriceRatioQ96(twapRouteHash);

        console.log("Current price Q96:", currentPrice);
        console.log("TWAP price Q96:", twapPrice);

        // Both should be positive
        assertTrue(currentPrice > 0, "Current price should be positive");
        assertTrue(twapPrice > 0, "TWAP price should be positive");

        // Calculate percentage difference
        uint256 diff = currentPrice > twapPrice
            ? currentPrice - twapPrice
            : twapPrice - currentPrice;
        uint256 percentDiff = (diff * 100) / currentPrice;

        console.log("Percentage difference:", percentDiff, "%");
    }
}
