// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Interfaces
import "../interfaces/IPriceAdapter.sol";
import "../interfaces/defi/IAerodromePool.sol";

import {FixedPointQ96} from "../libraries/FixedPointQ96.sol";
import {FullMath} from "../libraries/uniswap/FullMath.sol";
import {TickMath} from "../libraries/uniswap/TickMath.sol";
import {FixedPointMathLib} from "../libraries/erc4626/utils/FixedPointMathLib.sol";

/**
 * @title PriceAdapterAerodromeV2
 * @notice Corrected Aerodrome (Velodrome-V2 style) TWAP price adapter.
 *
 * @dev This replaces `PriceAdapterAerodrome`, which contained two confirmed defects in
 *      `getSqrtTwapX96`:
 *        1. It divided the cumulative-reserve delta by `observationLength()-1` (the observation
 *           COUNT) instead of by the elapsed TIME between the two observations. `timeElapsed` was
 *           computed and require()'d, then never used. With a small observation count this produced
 *           reserve magnitudes far larger than the true average, risking silent `uint160` overflow
 *           in the sqrt-price cast and a wrong price.
 *        2. It indexed the observation ring buffer by a *seconds* value
 *           (`observations(latestIndex - twapInterval)`), treating `twapInterval` as an array offset.
 *           Aerodrome writes at most one observation per ~30-min period, so for any realistic
 *           `twapInterval` this underflowed (revert / pricing DoS), and for tiny values it read an
 *           arbitrary slot that was NOT "twapInterval seconds ago".
 *
 *      This version selects the reference observation by ELAPSED TIME and divides cumulative deltas
 *      by `timeElapsed`, yielding a correct time-weighted average reserve. It reverts rather than
 *      silently shortening the window when the stored history does not span `twapInterval`
 *      (per ADR-0007 / audit H-5). The adapter is non-upgradeable and standalone; deploy a fresh
 *      instance and point pools at it (existing pools must be redeployed or upgraded to re-point).
 */
contract PriceAdapterAerodromeV2 is IPriceAdapter {
    struct PoolRoute {
        address pool;
        bool zeroForOne;
        uint32 twapInterval;
        uint256 token0Decimals;
        uint256 token1Decimals;
    }

    /// @notice Safety bound on the observation walk-back loop. With Aerodrome's ~30-min period
    ///         size this covers many days of TWAP window before the cap is reached.
    uint256 internal constant MAX_OBSERVATION_LOOKBACK = 1000;

    mapping(bytes32 => bytes) public priceRoutes;

    /* Events */

    event RouteRegistered(bytes32 hash, bytes route);

    /* External Functions */

    function registerPriceRoute(bytes memory route)
        external
        returns (bytes32 hash)
    {
        PoolRoute[] memory route_array = decodePoolRoutes(route);

        // hash the route with keccak256
        bytes32 poolRouteHash = keccak256(route);

        // store the route by its hash in the priceRoutes mapping
        priceRoutes[poolRouteHash] = route;

        emit RouteRegistered(poolRouteHash, route);

        return poolRouteHash;
    }

    function getPriceRatioQ96(bytes32 route)
        external
        view
        returns (uint256 priceRatioQ96)
    {
        // lookup the route from the mapping
        bytes memory routeData = priceRoutes[route];
        require(routeData.length > 0, "Route not found");

        // decode the route
        PoolRoute[] memory poolRoutes = decodePoolRoutes(routeData);

        // start with Q96 = 1.0 in Q96 format
        priceRatioQ96 = FixedPointQ96.Q96;

        // iterate through each pool and multiply prices
        for (uint256 i = 0; i < poolRoutes.length; i++) {
            uint256 poolPriceQ96 = getUniswapPriceRatioForPool(poolRoutes[i]);
            // multiply using Q96 arithmetic
            priceRatioQ96 = FixedPointQ96.multiplyFixedPoint96(
                priceRatioQ96,
                poolPriceQ96
            );
        }
    }

    // -------

    function encodePoolRoutes(PoolRoute[] memory routes)
        public
        pure
        returns (bytes memory encoded)
    {
        encoded = abi.encode(routes);
    }

    // validate the route for length, other restrictions
    // must be length 1 or 2
    function decodePoolRoutes(bytes memory data)
        public
        pure
        returns (PoolRoute[] memory route_array)
    {
        route_array = abi.decode(data, (PoolRoute[]));

        require(
            route_array.length == 1 || route_array.length == 2,
            "Route must have 1 or 2 pools"
        );
    }

    // -------

    function getUniswapPriceRatioForPool(PoolRoute memory _poolRoute)
        internal
        view
        returns (uint256 priceRatioQ96)
    {
        // this is expanded by 2**96
        uint160 sqrtPriceX96 = getSqrtTwapX96(
            _poolRoute.pool,
            _poolRoute.twapInterval
        );

        // Convert sqrtPriceX96 to priceQ96
        // sqrtPriceX96^2 / 2^96 gives us the price in Q96 format
        priceRatioQ96 = getPriceQ96FromSqrtPriceX96(sqrtPriceX96);

        // If we need the inverse (token0 in terms of token1), invert
        bool invert = !_poolRoute.zeroForOne;
        if (invert) {
            // To invert a Q96 number: (Q96 * Q96) / value
            priceRatioQ96 = FullMath.mulDiv(
                FixedPointQ96.Q96,
                FixedPointQ96.Q96,
                priceRatioQ96
            );
        }
    }

    /**
     * @notice Computes the sqrt price (Q96) as a time-weighted average over `twapInterval` seconds
     *         using the pool's cumulative-reserve observations.
     * @dev Reference observation is chosen by ELAPSED TIME (not array offset), and the cumulative
     *      delta is divided by the actual `timeElapsed`. Reverts if the stored history does not span
     *      `twapInterval` rather than silently using a shorter window.
     * @param poolAddress Aerodrome pool address.
     * @param twapInterval Minimum TWAP window in seconds. If 0, the most recent complete period
     *        (the two newest observations) is used — still a real averaged read, never spot.
     */
    function getSqrtTwapX96(address poolAddress, uint32 twapInterval)
        internal
        view
        returns (uint160 sqrtPriceX96)
    {
        IAerodromePool pool = IAerodromePool(poolAddress);

        uint256 observationLength = pool.observationLength();
        require(observationLength >= 2, "Aerodrome: not enough observations");

        uint256 latestIndex = observationLength - 1;

        // Newest stored cumulative snapshot.
        (
            uint256 latestTimestamp,
            uint256 latestReserve0Cumulative,
            uint256 latestReserve1Cumulative
        ) = pool.observations(latestIndex);

        // Default reference: the observation immediately preceding the latest one
        // (i.e. the most recent complete period). Used directly when twapInterval == 0.
        uint256 referenceIndex = latestIndex - 1;

        if (twapInterval > 0) {
            // Walk backwards to the newest observation that is at least `twapInterval`
            // seconds older than the latest one.
            bool found = false;
            uint256 steps = 0;
            for (uint256 i = latestIndex; i > 0; ) {
                i--;
                (uint256 ts, , ) = pool.observations(i);
                if (latestTimestamp - ts >= twapInterval) {
                    referenceIndex = i;
                    found = true;
                    break;
                }
                steps++;
                require(
                    steps <= MAX_OBSERVATION_LOOKBACK,
                    "Aerodrome: lookback too deep"
                );
            }
            // History does not span the requested window: revert, do NOT silently shorten.
            require(found, "Aerodrome: window exceeds history");
        }

        (
            uint256 referenceTimestamp,
            uint256 referenceReserve0Cumulative,
            uint256 referenceReserve1Cumulative
        ) = pool.observations(referenceIndex);

        uint256 timeElapsed = latestTimestamp - referenceTimestamp;
        require(timeElapsed > 0, "Aerodrome: invalid time elapsed");

        // Time-weighted average reserves over [referenceTimestamp, latestTimestamp].
        // Dividing by timeElapsed (not the observation count) yields true reserve-magnitude
        // averages, which keeps the subsequent sqrt-price cast within uint160 range.
        uint256 avgReserve0 = (latestReserve0Cumulative -
            referenceReserve0Cumulative) / timeElapsed;
        uint256 avgReserve1 = (latestReserve1Cumulative -
            referenceReserve1Cumulative) / timeElapsed;

        sqrtPriceX96 = getSqrtPriceQ96FromReserves(avgReserve0, avgReserve1);
    }

    function getSqrtPriceQ96FromReserves(uint256 reserve0, uint256 reserve1)
        internal
        pure
        returns (uint160 sqrtPriceX96)
    {
        require(reserve0 > 0, "Aerodrome: reserve0 is zero");

        uint256 sqrtReserve1 = FixedPointMathLib.sqrt(reserve1);
        uint256 sqrtReserve0 = FixedPointMathLib.sqrt(reserve0);

        uint256 sqrtPrice = FullMath.mulDiv(
            sqrtReserve1,
            FixedPointQ96.Q96,
            sqrtReserve0
        );

        // Explicit bound: silent uint160 truncation here would produce a wrong price.
        require(sqrtPrice <= type(uint160).max, "Aerodrome: sqrtPrice overflow");

        sqrtPriceX96 = uint160(sqrtPrice);
    }

    function getPriceQ96FromSqrtPriceX96(uint160 sqrtPriceX96)
        internal
        pure
        returns (uint256 priceQ96)
    {
        // sqrtPriceX96^2 / 2^96 = priceQ96
        return FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, FixedPointQ96.Q96);
    }
}
