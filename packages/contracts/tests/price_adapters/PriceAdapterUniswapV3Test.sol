// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Testable } from "../Testable.sol";
import {PriceAdapterUniswapV3} from "../../contracts/price_adapters/PriceAdapterUniswapV3.sol";
import { UniswapV3PoolMock } from "../../contracts/mock/uniswap/UniswapV3PoolMock.sol";
import { FixedPointQ96 } from "../../contracts/libraries/FixedPointQ96.sol";
import "forge-std/console.sol";

contract PriceAdapterUniswapV3Test is Testable {

    PriceAdapterUniswapV3 public adapter;
    UniswapV3PoolMock public mockPool1;
    UniswapV3PoolMock public mockPool2;

    function setUp() public {
        adapter = new PriceAdapterUniswapV3();
        mockPool1 = new UniswapV3PoolMock();
        mockPool2 = new UniswapV3PoolMock();
    }

    // ========== ENCODE/DECODE TESTS ==========

    function test_encodeDecodePoolRoutes_single() public {
        PriceAdapterUniswapV3.PoolRoute[] memory routes = new PriceAdapterUniswapV3.PoolRoute[](1);
        routes[0] = PriceAdapterUniswapV3.PoolRoute({
            pool: address(mockPool1),
            zeroForOne: true,
            twapInterval: 0,
            token0Decimals: 18,
            token1Decimals: 18
        });

        bytes memory encoded = adapter.encodePoolRoutes(routes);
        PriceAdapterUniswapV3.PoolRoute[] memory decoded = adapter.decodePoolRoutes(encoded);

        assertEq(decoded.length, 1, "Decoded length mismatch");
        assertEq(decoded[0].pool, address(mockPool1), "Pool address mismatch");
        assertEq(decoded[0].zeroForOne, true, "zeroForOne mismatch");
        assertEq(decoded[0].twapInterval, 0, "twapInterval mismatch");
        assertEq(decoded[0].token0Decimals, 18, "token0Decimals mismatch");
        assertEq(decoded[0].token1Decimals, 18, "token1Decimals mismatch");
    }

    function test_encodeDecodePoolRoutes_double() public {
        PriceAdapterUniswapV3.PoolRoute[] memory routes = new PriceAdapterUniswapV3.PoolRoute[](2);
        routes[0] = PriceAdapterUniswapV3.PoolRoute({
            pool: address(mockPool1),
            zeroForOne: true,
            twapInterval: 0,
            token0Decimals: 18,
            token1Decimals: 6
        });
        routes[1] = PriceAdapterUniswapV3.PoolRoute({
            pool: address(mockPool2),
            zeroForOne: false,
            twapInterval: 300,
            token0Decimals: 6,
            token1Decimals: 18
        });

        bytes memory encoded = adapter.encodePoolRoutes(routes);
        PriceAdapterUniswapV3.PoolRoute[] memory decoded = adapter.decodePoolRoutes(encoded);

        assertEq(decoded.length, 2, "Decoded length mismatch");
        assertEq(decoded[0].pool, address(mockPool1), "Pool1 address mismatch");
        assertEq(decoded[1].pool, address(mockPool2), "Pool2 address mismatch");
        assertEq(decoded[1].zeroForOne, false, "zeroForOne mismatch");
        assertEq(decoded[1].twapInterval, 300, "twapInterval mismatch");
    }

    function test_decodePoolRoutes_revert_empty() public {
        PriceAdapterUniswapV3.PoolRoute[] memory routes = new PriceAdapterUniswapV3.PoolRoute[](0);
        bytes memory encoded = adapter.encodePoolRoutes(routes);

        vm.expectRevert("Route must have 1 or 2 pools");
        adapter.decodePoolRoutes(encoded);
    }

    function test_decodePoolRoutes_revert_tooMany() public {
        PriceAdapterUniswapV3.PoolRoute[] memory routes = new PriceAdapterUniswapV3.PoolRoute[](3);
        routes[0] = PriceAdapterUniswapV3.PoolRoute({
            pool: address(mockPool1),
            zeroForOne: true,
            twapInterval: 0,
            token0Decimals: 18,
            token1Decimals: 18
        });
        routes[1] = PriceAdapterUniswapV3.PoolRoute({
            pool: address(mockPool2),
            zeroForOne: true,
            twapInterval: 0,
            token0Decimals: 18,
            token1Decimals: 18
        });
        routes[2] = PriceAdapterUniswapV3.PoolRoute({
            pool: address(mockPool1),
            zeroForOne: true,
            twapInterval: 0,
            token0Decimals: 18,
            token1Decimals: 18
        });

        bytes memory encoded = adapter.encodePoolRoutes(routes);

        vm.expectRevert("Route must have 1 or 2 pools");
        adapter.decodePoolRoutes(encoded);
    }

    // ========== REGISTER PRICE ROUTE TESTS ==========

    function test_registerPriceRoute_single() public {
        PriceAdapterUniswapV3.PoolRoute[] memory routes = new PriceAdapterUniswapV3.PoolRoute[](1);
        routes[0] = PriceAdapterUniswapV3.PoolRoute({
            pool: address(mockPool1),
            zeroForOne: true,
            twapInterval: 0,
            token0Decimals: 18,
            token1Decimals: 18
        });

        bytes memory encoded = adapter.encodePoolRoutes(routes);
        bytes32 expectedHash = keccak256(encoded);

        vm.expectEmit(true, true, true, true);
        emit IPriceAdapter.RouteRegistered(expectedHash, encoded);

        bytes32 returnedHash = adapter.registerPriceRoute(encoded);

        assertEq(returnedHash, expectedHash, "Hash mismatch");

        // Verify route is stored
        bytes memory storedRoute = adapter.priceRoutes(expectedHash);
        assertEq(storedRoute, encoded, "Stored route mismatch");
    }

    function test_registerPriceRoute_double() public {
        PriceAdapterUniswapV3.PoolRoute[] memory routes = new PriceAdapterUniswapV3.PoolRoute[](2);
        routes[0] = PriceAdapterUniswapV3.PoolRoute({
            pool: address(mockPool1),
            zeroForOne: true,
            twapInterval: 0,
            token0Decimals: 18,
            token1Decimals: 6
        });
        routes[1] = PriceAdapterUniswapV3.PoolRoute({
            pool: address(mockPool2),
            zeroForOne: false,
            twapInterval: 0,
            token0Decimals: 6,
            token1Decimals: 18
        });

        bytes memory encoded = adapter.encodePoolRoutes(routes);
        bytes32 hash = adapter.registerPriceRoute(encoded);

        assertTrue(hash != bytes32(0), "Hash should not be zero");

        bytes memory storedRoute = adapter.priceRoutes(hash);
        assertEq(storedRoute, encoded, "Stored route mismatch");
    }

    function test_registerPriceRoute_revert_invalid() public {
        PriceAdapterUniswapV3.PoolRoute[] memory routes = new PriceAdapterUniswapV3.PoolRoute[](3);
        routes[0] = PriceAdapterUniswapV3.PoolRoute({
            pool: address(mockPool1),
            zeroForOne: true,
            twapInterval: 0,
            token0Decimals: 18,
            token1Decimals: 18
        });
        routes[1] = PriceAdapterUniswapV3.PoolRoute({
            pool: address(mockPool2),
            zeroForOne: true,
            twapInterval: 0,
            token0Decimals: 18,
            token1Decimals: 18
        });
        routes[2] = PriceAdapterUniswapV3.PoolRoute({
            pool: address(mockPool1),
            zeroForOne: true,
            twapInterval: 0,
            token0Decimals: 18,
            token1Decimals: 18
        });

        bytes memory encoded = adapter.encodePoolRoutes(routes);

        vm.expectRevert("Route must have 1 or 2 pools");
        adapter.registerPriceRoute(encoded);
    }

    // ========== GET PRICE RATIO TESTS ==========

    function test_getPriceRatioQ96_single_equalPrice() public {
        // Set up pool with price = 1.0 (sqrtPriceX96 = 2^96)
        mockPool1.set_mockSqrtPriceX96(uint160(2**96));

        PriceAdapterUniswapV3.PoolRoute[] memory routes = new PriceAdapterUniswapV3.PoolRoute[](1);
        routes[0] = PriceAdapterUniswapV3.PoolRoute({
            pool: address(mockPool1),
            zeroForOne: true,
            twapInterval: 0,
            token0Decimals: 18,
            token1Decimals: 18
        });

        bytes memory encoded = adapter.encodePoolRoutes(routes);
        bytes32 hash = adapter.registerPriceRoute(encoded);

        uint256 priceRatioQ96 = adapter.getPriceRatioQ96(hash);

        // Price should be 1.0 in Q96 format
        assertEq(priceRatioQ96, FixedPointQ96.Q96, "Price should be Q96 for 1:1 ratio");
    }

    function test_getPriceRatioQ96_single_highPrice() public {
        // Set up pool with a high price
        // For price = 100, sqrtPrice = 10, so sqrtPriceX96 = 10 * 2^96
        uint160 sqrtPriceX96 = uint160(10 * uint256(2**96));
        mockPool1.set_mockSqrtPriceX96(sqrtPriceX96);

        PriceAdapterUniswapV3.PoolRoute[] memory routes = new PriceAdapterUniswapV3.PoolRoute[](1);
        routes[0] = PriceAdapterUniswapV3.PoolRoute({
            pool: address(mockPool1),
            zeroForOne: true,
            twapInterval: 0,
            token0Decimals: 18,
            token1Decimals: 18
        });

        bytes memory encoded = adapter.encodePoolRoutes(routes);
        bytes32 hash = adapter.registerPriceRoute(encoded);

        uint256 priceRatioQ96 = adapter.getPriceRatioQ96(hash);

        // Price should be 100 * Q96 (price = 100.0)
        uint256 expectedPrice = 100 * FixedPointQ96.Q96;
        assertEq(priceRatioQ96, expectedPrice, "Price should be 100.0 in Q96");
    }

    function test_getPriceRatioQ96_single_invertedPrice() public {
        // Set up pool with price = 1.0, but inverted
        mockPool1.set_mockSqrtPriceX96(uint160(2**96));

        PriceAdapterUniswapV3.PoolRoute[] memory routes = new PriceAdapterUniswapV3.PoolRoute[](1);
        routes[0] = PriceAdapterUniswapV3.PoolRoute({
            pool: address(mockPool1),
            zeroForOne: false, // inverted
            twapInterval: 0,
            token0Decimals: 18,
            token1Decimals: 18
        });

        bytes memory encoded = adapter.encodePoolRoutes(routes);
        bytes32 hash = adapter.registerPriceRoute(encoded);

        uint256 priceRatioQ96 = adapter.getPriceRatioQ96(hash);

        // When inverted, price of 1.0 should still be 1.0
        assertEq(priceRatioQ96, FixedPointQ96.Q96, "Inverted price of 1.0 should still be Q96");
    }

    function test_getPriceRatioQ96_double_equalPrices() public {
        // Both pools with price = 1.0
        mockPool1.set_mockSqrtPriceX96(uint160(2**96));
        mockPool2.set_mockSqrtPriceX96(uint160(2**96));

        PriceAdapterUniswapV3.PoolRoute[] memory routes = new PriceAdapterUniswapV3.PoolRoute[](2);
        routes[0] = PriceAdapterUniswapV3.PoolRoute({
            pool: address(mockPool1),
            zeroForOne: true,
            twapInterval: 0,
            token0Decimals: 18,
            token1Decimals: 6
        });
        routes[1] = PriceAdapterUniswapV3.PoolRoute({
            pool: address(mockPool2),
            zeroForOne: true,
            twapInterval: 0,
            token0Decimals: 6,
            token1Decimals: 18
        });

        bytes memory encoded = adapter.encodePoolRoutes(routes);
        bytes32 hash = adapter.registerPriceRoute(encoded);

        uint256 priceRatioQ96 = adapter.getPriceRatioQ96(hash);

        // 1.0 * 1.0 = 1.0
        assertEq(priceRatioQ96, FixedPointQ96.Q96, "Combined price should be Q96");
    }

    function test_getPriceRatioQ96_double_multipliedPrices() public {
        // Pool1: price = 4.0 (sqrtPrice = 2 * 2^96)
        // Pool2: price = 0.25 (sqrtPrice = 0.5 * 2^96)
        // Combined: 4.0 * 0.25 = 1.0

        mockPool1.set_mockSqrtPriceX96(uint160(2 * 2**96));
        mockPool2.set_mockSqrtPriceX96(uint160(2**95)); // 0.5 * 2^96

        PriceAdapterUniswapV3.PoolRoute[] memory routes = new PriceAdapterUniswapV3.PoolRoute[](2);
        routes[0] = PriceAdapterUniswapV3.PoolRoute({
            pool: address(mockPool1),
            zeroForOne: true,
            twapInterval: 0,
            token0Decimals: 18,
            token1Decimals: 6
        });
        routes[1] = PriceAdapterUniswapV3.PoolRoute({
            pool: address(mockPool2),
            zeroForOne: true,
            twapInterval: 0,
            token0Decimals: 6,
            token1Decimals: 18
        });

        bytes memory encoded = adapter.encodePoolRoutes(routes);
        bytes32 hash = adapter.registerPriceRoute(encoded);

        uint256 priceRatioQ96 = adapter.getPriceRatioQ96(hash);

        // 4.0 * 0.25 = 1.0
        assertEq(priceRatioQ96, FixedPointQ96.Q96, "Combined price should be Q96");
    }

    function test_getPriceRatioQ96_revert_routeNotFound() public {
        bytes32 nonExistentHash = keccak256("nonexistent");

        vm.expectRevert("Route not found");
        adapter.getPriceRatioQ96(nonExistentHash);
    }

    // ========== Q96 ARITHMETIC VERIFICATION TESTS ==========

    function test_Q96_multiplication_preservesPrecision() public {
        // Set up a known price: sqrt(2) * 2^96 ≈ 1.414 price ratio
        // Calculate: 2^96 * 141421356 / 100000000
        // To avoid overflow, do: (2^96 / 100000000) * 141421356
        uint256 q96 = uint256(2**96);
        uint160 sqrtPriceX96 = uint160((q96 * 141421356) / 100000000); // ~sqrt(2)
        mockPool1.set_mockSqrtPriceX96(sqrtPriceX96);

        PriceAdapterUniswapV3.PoolRoute[] memory routes = new PriceAdapterUniswapV3.PoolRoute[](1);
        routes[0] = PriceAdapterUniswapV3.PoolRoute({
            pool: address(mockPool1),
            zeroForOne: true,
            twapInterval: 0,
            token0Decimals: 18,
            token1Decimals: 18
        });

        bytes memory encoded = adapter.encodePoolRoutes(routes);
        bytes32 hash = adapter.registerPriceRoute(encoded);

        uint256 priceRatioQ96 = adapter.getPriceRatioQ96(hash);

        // Verify it's in Q96 format (should be around 2 * Q96 for sqrt(2)^2)
        uint256 expectedPrice = 2 * FixedPointQ96.Q96; // sqrt(2)^2 = 2

        // Allow for small rounding error (within 0.1%)
        uint256 diff = priceRatioQ96 > expectedPrice ? priceRatioQ96 - expectedPrice : expectedPrice - priceRatioQ96;
        assertLt(diff, expectedPrice / 1000, "Price should be close to 2.0 in Q96");
    }

    function test_Q96_conversion_fromFixedPoint() public {
        // Test that we can convert Q96 values back to human-readable format
        uint256 oneInQ96 = FixedPointQ96.Q96;
        uint256 twoInQ96 = 2 * FixedPointQ96.Q96;
        uint256 halfInQ96 = FixedPointQ96.Q96 / 2;

        assertEq(FixedPointQ96.fromFixedPoint96(oneInQ96), 1, "1.0 in Q96 should convert to 1");
        assertEq(FixedPointQ96.fromFixedPoint96(twoInQ96), 2, "2.0 in Q96 should convert to 2");
        assertEq(FixedPointQ96.fromFixedPoint96(halfInQ96), 0, "0.5 in Q96 should convert to 0 (integer division)");
    }
}

// Need to add event declaration for testing
interface IPriceAdapter {
    event RouteRegistered(bytes32 hash, bytes route);
}
