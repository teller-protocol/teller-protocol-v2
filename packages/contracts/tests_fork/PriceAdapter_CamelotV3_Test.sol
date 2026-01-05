// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "../tests/util/FoundryTest.sol";
import "forge-std/console.sol";

// Import the PriceAdapterAerodrome contract
import { PriceAdapterCamelotV3 } from "../contracts/price_adapters/PriceAdapterCamelotV3.sol";
import { IUniswapV3Pool } from "../contracts/interfaces/uniswap/IUniswapV3Pool.sol";

/**
 * @title PoolsV3_Aerodrome_Fork_Test
 * @notice Tests for PriceAdapterAerodrome using a live Aerodrome pool on Base
 * @dev This test suite validates the price adapter's functionality with real pool data
 */
contract CamelotPriceAdapter_Fork_Test is Test {

    string constant NETWORK_NAME = "arbitrum";

    // Aerodrome pool address on Base with .observe and .slot0 support
    address constant CAMELOT_V3_POOL = 0xB1026b8e7276e7AC75410F1fcbbe21796e8f7526;

    PriceAdapterCamelotV3 public priceAdapter;
    IAerodromePool public pool;

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
        priceAdapter = new PriceAdapterCamelotV3();

        // Connect to the pool
        pool = IUniswapV3Pool(CAMELOT_V3_POOL);

        // Verify the pool has code
        assertTrue(CAMELOT_V3_POOL.code.length > 0, "Pool should have code");

        // Get token addresses from the pool
        token0 = pool.token0();
        token1 = pool.token1();

        console.log("Pool address:", CAMELOT_V3_POOL);
        console.log("Token0:", token0);
        console.log("Token1:", token1);

        // Get token decimals (would need ERC20 interface to get these properly)
        // For now, assuming standard 18 decimals
        token0Decimals = 18;
        token1Decimals = 18;
    }

    /**
     * @notice Test that the pool has observations data
     * @dev This verifies the pool supports observations() for TWAP calculations
     */
    function test_pool_has_observations() public {
        // Try to get observation at index 0 (most recent)
        (uint256 timestamp0, uint256 reserve0Cumulative0, uint256 reserve1Cumulative0) =
            pool.observations(0);

        // Verify we got valid data
        assertTrue(timestamp0 > 0, "Timestamp should be greater than 0");
        console.log("Observation 0 - Timestamp:", timestamp0);
        console.log("Observation 0 - Reserve0 Cumulative:", reserve0Cumulative0);
        console.log("Observation 0 - Reserve1 Cumulative:", reserve1Cumulative0);

        // Try to get observation at index 1
        (uint256 timestamp1, uint256 reserve0Cumulative1, uint256 reserve1Cumulative1) =
            pool.observations(1);

        console.log("Observation 1 - Timestamp:", timestamp1);
        console.log("Observation 1 - Reserve0 Cumulative:", reserve0Cumulative1);
        console.log("Observation 1 - Reserve1 Cumulative:", reserve1Cumulative1);

        // The cumulative reserves should increase over time, so observation 0 (newer)
        // should have higher or equal cumulative values than observation 1 (older)
        assertTrue(reserve0Cumulative1 >= reserve0Cumulative0, "Reserve0 cumulative should increase over time");
        assertTrue(reserve1Cumulative1 >= reserve1Cumulative0, "Reserve1 cumulative should increase over time");
    }

   
    /**
     * @notice Test registering a price route with the Aerodrome pool
     */
    function test_register_price_route() public {
        // Create a single-hop route (token0 -> token1)
        PriceAdapterCamelotV3.PoolRoute[] memory routes = new PriceAdapterCamelotV3.PoolRoute[](1);
        routes[0] = PriceAdapterCamelotV3.PoolRoute({
            pool: CAMELOT_V3_POOL,
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
        PriceAdapterCamelotV3.PoolRoute[] memory routes = new PriceAdapterCamelotV3.PoolRoute[](1);
        routes[0] = PriceAdapterCamelotV3.PoolRoute({
            pool: CAMELOT_V3_POOL,
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
        PriceAdapterCamelotV3.PoolRoute[] memory routes = new PriceAdapterCamelotV3.PoolRoute[](1);
        routes[0] = PriceAdapterCamelotV3.PoolRoute({
            pool: CAMELOT_V3_POOL,
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
        PriceAdapterCamelotV3.PoolRoute[] memory routes = new PriceAdapterCamelotV3.PoolRoute[](1);
        routes[0] = PriceAdapterCamelotV3.PoolRoute({
            pool: CAMELOT_V3_POOL,
            zeroForOne: true,
            twapInterval: 5, // 1 hour TWAP
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
  
}
