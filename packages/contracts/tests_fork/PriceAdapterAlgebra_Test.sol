// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "../tests/util/FoundryTest.sol";
import "forge-std/console.sol";

import { PriceAdapterAlgebra } from "../contracts/price_adapters/PriceAdapterAlgebra.sol";
import { IAlgebraPool } from "../contracts/interfaces/defi/IAlgebraPool.sol";

interface IAlgebraFactory {
    function poolByPair(address tokenA, address tokenB) external view returns (address pool);
}

interface IERC20Minimal {
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
}

/**
 * @title PriceAdapterAlgebra_Test
 * @notice Fork test for PriceAdapterAlgebra against ApeChain Camelot V3 (Algebra) pool.
 * @dev Run with: forge test --match-contract PriceAdapterAlgebra -vv --fork-url <apechain-rpc>
 */
contract PriceAdapterAlgebra_Test is Test {

    address constant CAMELOT_V3_FACTORY = 0x10aA510d94E094Bd643677bd2964c3EE085Daffc;
    address constant WAPE = 0x48b62137EdfA95a428D35C09E44256a739F6B557;
    address constant ApeUSD = 0xA2235d059F80e176D931Ef76b6C51953Eb3fBEf4;

    PriceAdapterAlgebra public priceAdapter;
    address public camelotPool;

    address token0;
    address token1;
    uint8 token0Decimals;
    uint8 token1Decimals;

    function setUp() public {
        priceAdapter = new PriceAdapterAlgebra();

        camelotPool = IAlgebraFactory(CAMELOT_V3_FACTORY).poolByPair(WAPE, ApeUSD);
        require(camelotPool != address(0), "No WAPE/ApeUSD Camelot pool");
        assertTrue(camelotPool.code.length > 0, "Pool should have code");

        IAlgebraPool pool = IAlgebraPool(camelotPool);
        token0 = pool.token0();
        token1 = pool.token1();
        token0Decimals = IERC20Minimal(token0).decimals();
        token1Decimals = IERC20Minimal(token1).decimals();

        console.log("Pool address:", camelotPool);
        console.log("Token0:", token0, IERC20Minimal(token0).symbol());
        console.log("Token1:", token1, IERC20Minimal(token1).symbol());
    }

    // ============ Route Registration ============

    function test_register_price_route() public {
        PriceAdapterAlgebra.PoolRoute[] memory routes = new PriceAdapterAlgebra.PoolRoute[](1);
        routes[0] = PriceAdapterAlgebra.PoolRoute({
            pool: camelotPool,
            zeroForOne: true,
            twapInterval: 0,
            token0Decimals: token0Decimals,
            token1Decimals: token1Decimals
        });

        bytes memory encodedRoute = priceAdapter.encodePoolRoutes(routes);
        bytes32 routeHash = priceAdapter.registerPriceRoute(encodedRoute);

        bytes memory storedRoute = priceAdapter.priceRoutes(routeHash);
        assertEq(storedRoute.length, encodedRoute.length, "Route should be stored");

        uint256 priceRatioQ96 = priceAdapter.getPriceRatioQ96(routeHash);
        assertTrue(priceRatioQ96 > 0, "Price should be nonzero");
        console.log("Route registered, priceRatioQ96:", priceRatioQ96);
    }

    // ============ Spot Price (globalState) ============

    function test_spot_price_token0_to_token1() public {
        PriceAdapterAlgebra.PoolRoute[] memory routes = new PriceAdapterAlgebra.PoolRoute[](1);
        routes[0] = PriceAdapterAlgebra.PoolRoute({
            pool: camelotPool,
            zeroForOne: true,
            twapInterval: 0, // spot price via globalState()
            token0Decimals: token0Decimals,
            token1Decimals: token1Decimals
        });

        bytes memory encodedRoute = priceAdapter.encodePoolRoutes(routes);
        bytes32 routeHash = priceAdapter.registerPriceRoute(encodedRoute);

        uint256 priceRatioQ96 = priceAdapter.getPriceRatioQ96(routeHash);
        assertTrue(priceRatioQ96 > 0, "Spot price should be > 0");

        uint256 priceScaled = (priceRatioQ96 * 1e18) / (2 ** 96);
        console.log("Spot price (token0->token1) Q96:", priceRatioQ96);
        console.log("Spot price (scaled 1e18):", priceScaled);
    }

    function test_spot_price_token1_to_token0() public {
        PriceAdapterAlgebra.PoolRoute[] memory routes = new PriceAdapterAlgebra.PoolRoute[](1);
        routes[0] = PriceAdapterAlgebra.PoolRoute({
            pool: camelotPool,
            zeroForOne: false, // inverse
            twapInterval: 0,
            token0Decimals: token0Decimals,
            token1Decimals: token1Decimals
        });

        bytes memory encodedRoute = priceAdapter.encodePoolRoutes(routes);
        bytes32 routeHash = priceAdapter.registerPriceRoute(encodedRoute);

        uint256 priceRatioQ96 = priceAdapter.getPriceRatioQ96(routeHash);
        assertTrue(priceRatioQ96 > 0, "Inverse spot price should be > 0");

        uint256 priceScaled = (priceRatioQ96 * 1e18) / (2 ** 96);
        console.log("Spot price (token1->token0) Q96:", priceRatioQ96);
        console.log("Spot price (scaled 1e18):", priceScaled);
    }

    // ============ TWAP Price (getTimepoints) ============

    function test_twap_price() public {
        PriceAdapterAlgebra.PoolRoute[] memory routes = new PriceAdapterAlgebra.PoolRoute[](1);
        routes[0] = PriceAdapterAlgebra.PoolRoute({
            pool: camelotPool,
            zeroForOne: true,
            twapInterval: 5, // 5 second TWAP via getTimepoints()
            token0Decimals: token0Decimals,
            token1Decimals: token1Decimals
        });

        bytes memory encodedRoute = priceAdapter.encodePoolRoutes(routes);
        bytes32 routeHash = priceAdapter.registerPriceRoute(encodedRoute);

        uint256 priceRatioQ96 = priceAdapter.getPriceRatioQ96(routeHash);
        assertTrue(priceRatioQ96 > 0, "TWAP price should be > 0");

        uint256 priceScaled = (priceRatioQ96 * 1e18) / (2 ** 96);
        console.log("TWAP price Q96:", priceRatioQ96);
        console.log("TWAP price (scaled 1e18):", priceScaled);
    }

    function test_compare_spot_vs_twap() public {
        // Spot
        PriceAdapterAlgebra.PoolRoute[] memory spotRoutes = new PriceAdapterAlgebra.PoolRoute[](1);
        spotRoutes[0] = PriceAdapterAlgebra.PoolRoute({
            pool: camelotPool,
            zeroForOne: true,
            twapInterval: 0,
            token0Decimals: token0Decimals,
            token1Decimals: token1Decimals
        });
        bytes32 spotHash = priceAdapter.registerPriceRoute(priceAdapter.encodePoolRoutes(spotRoutes));
        uint256 spotPrice = priceAdapter.getPriceRatioQ96(spotHash);

        // TWAP
        PriceAdapterAlgebra.PoolRoute[] memory twapRoutes = new PriceAdapterAlgebra.PoolRoute[](1);
        twapRoutes[0] = PriceAdapterAlgebra.PoolRoute({
            pool: camelotPool,
            zeroForOne: true,
            twapInterval: 5,
            token0Decimals: token0Decimals,
            token1Decimals: token1Decimals
        });
        bytes32 twapHash = priceAdapter.registerPriceRoute(priceAdapter.encodePoolRoutes(twapRoutes));
        uint256 twapPrice = priceAdapter.getPriceRatioQ96(twapHash);

        assertTrue(spotPrice > 0, "Spot price should be positive");
        assertTrue(twapPrice > 0, "TWAP price should be positive");

        uint256 diff = spotPrice > twapPrice ? spotPrice - twapPrice : twapPrice - spotPrice;
        uint256 percentDiff = (diff * 100) / spotPrice;

        console.log("Spot price Q96:", spotPrice);
        console.log("TWAP price Q96:", twapPrice);
        console.log("Difference:", percentDiff, "%");
    }

    // ============ Multi-hop ============

    function test_two_hop_route() public {
        PriceAdapterAlgebra.PoolRoute[] memory routes = new PriceAdapterAlgebra.PoolRoute[](2);
        routes[0] = PriceAdapterAlgebra.PoolRoute({
            pool: camelotPool,
            zeroForOne: true,
            twapInterval: 0,
            token0Decimals: token0Decimals,
            token1Decimals: token1Decimals
        });
        routes[1] = PriceAdapterAlgebra.PoolRoute({
            pool: camelotPool,
            zeroForOne: false, // go back
            twapInterval: 0,
            token0Decimals: token0Decimals,
            token1Decimals: token1Decimals
        });

        bytes memory encodedRoute = priceAdapter.encodePoolRoutes(routes);
        bytes32 routeHash = priceAdapter.registerPriceRoute(encodedRoute);

        uint256 priceRatioQ96 = priceAdapter.getPriceRatioQ96(routeHash);
        assertTrue(priceRatioQ96 > 0, "Two-hop price should be > 0");

        uint256 priceScaled = (priceRatioQ96 * 1e18) / (2 ** 96);
        console.log("Two-hop Price Q96:", priceRatioQ96);
        console.log("Two-hop Price (scaled 1e18):", priceScaled);
        console.log("Expected ~1e18 (roundtrip should be ~1.0)");
    }

    function test_two_hop_route_twap() public {
        PriceAdapterAlgebra.PoolRoute[] memory routes = new PriceAdapterAlgebra.PoolRoute[](2);
        routes[0] = PriceAdapterAlgebra.PoolRoute({
            pool: camelotPool,
            zeroForOne: true,
            twapInterval: 5,
            token0Decimals: token0Decimals,
            token1Decimals: token1Decimals
        });
        routes[1] = PriceAdapterAlgebra.PoolRoute({
            pool: camelotPool,
            zeroForOne: false,
            twapInterval: 5,
            token0Decimals: token0Decimals,
            token1Decimals: token1Decimals
        });

        bytes memory encodedRoute = priceAdapter.encodePoolRoutes(routes);
        bytes32 routeHash = priceAdapter.registerPriceRoute(encodedRoute);

        uint256 priceRatioQ96 = priceAdapter.getPriceRatioQ96(routeHash);
        assertTrue(priceRatioQ96 > 0, "Two-hop TWAP price should be > 0");

        uint256 priceScaled = (priceRatioQ96 * 1e18) / (2 ** 96);
        console.log("Two-hop TWAP Price Q96:", priceRatioQ96);
        console.log("Two-hop TWAP Price (scaled 1e18):", priceScaled);
    }

    // ============ Edge Cases ============

    function test_decode_rejects_invalid_route_length() public {
        PriceAdapterAlgebra.PoolRoute[] memory routes = new PriceAdapterAlgebra.PoolRoute[](3);
        routes[0] = PriceAdapterAlgebra.PoolRoute({
            pool: camelotPool,
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

    function test_get_price_reverts_for_unregistered_route() public {
        bytes32 fakeRouteHash = keccak256("fake route");

        vm.expectRevert("Route not found");
        priceAdapter.getPriceRatioQ96(fakeRouteHash);
    }
}
