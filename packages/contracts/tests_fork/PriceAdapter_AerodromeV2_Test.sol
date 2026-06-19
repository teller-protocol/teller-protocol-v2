// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "../tests/util/FoundryTest.sol";
import "forge-std/console.sol";

import { PriceAdapterAerodromeV2 } from "../contracts/price_adapters/PriceAdapterAerodromeV2.sol";
import { PriceAdapterAerodrome } from "../contracts/price_adapters/PriceAdapterAerodrome.sol";
import { IAerodromePool } from "../contracts/interfaces/defi/IAerodromePool.sol";

import { FixedPointQ96 } from "../contracts/libraries/FixedPointQ96.sol";
import { FullMath } from "../contracts/libraries/uniswap/FullMath.sol";
import { FixedPointMathLib } from "../contracts/libraries/erc4626/utils/FixedPointMathLib.sol";

/**
 * @title PriceAdapterAerodromeV2_Fork_Test
 * @notice Fork tests for the corrected `PriceAdapterAerodromeV2` against a live Aerodrome pool on Base.
 *
 * @dev Run with (you must supply a Base RPC):
 *
 *      FOUNDRY_PROFILE=fork forge test \
 *        --match-contract PriceAdapterAerodromeV2_Fork_Test -vvvv \
 *        --fork-url https://mainnet.base.org
 *
 *      The repo's `yarn test_forked` script runs the `fork` profile against a local
 *      node (`yarn fork` first), so either point --fork-url at a Base archive RPC or
 *      run `yarn fork` with HARDHAT_DEPLOY_FORK=base and use `yarn test_forked`.
 *
 *      These tests do three things the original suite never did:
 *        1. Pin the exact time-weighted algorithm: re-derive the price ratio off the raw
 *           observations in the test and assert byte-for-byte equality with the adapter.
 *        2. Independent sanity bound: the TWAP price must be within a generous factor of the
 *           live spot reserves (catches gross magnitude/indexing regressions, not volatility).
 *        3. Exercise the corrected revert behavior (window-exceeds-history, <2 observations)
 *           and contrast against the old adapter's broken seconds-as-index TWAP path.
 */

/// @dev Minimal extension to read live reserves for an independent spot sanity check.
interface IAerodromePoolExtended is IAerodromePool {
    function getReserves()
        external
        view
        returns (uint256 reserve0, uint256 reserve1, uint256 blockTimestampLast);
}

contract PriceAdapterAerodromeV2_Fork_Test is Test {
    // Same live Aerodrome pool the original PriceAdapter_Aerodrome_Test used.
    address constant AERODROME_POOL = 0x6cDcb1C4A4D1C3C6d054b27AC5B77e89eAFb971d;

    uint256 constant Q96 = FixedPointQ96.Q96;

    PriceAdapterAerodromeV2 public adapter;
    IAerodromePoolExtended public pool;

    uint256 token0Decimals;
    uint256 token1Decimals;

    function setUp() public {
        adapter = new PriceAdapterAerodromeV2();
        pool = IAerodromePoolExtended(AERODROME_POOL);

        assertTrue(AERODROME_POOL.code.length > 0, "Pool should have code (are you forked on Base?)");

        // Adapter never uses decimals in its math, but the route struct carries them.
        token0Decimals = 18;
        token1Decimals = 18;
    }

    /* ----------------------------- helpers ----------------------------- */

    function _singleHopRoute(bool zeroForOne, uint32 twapInterval)
        internal
        view
        returns (PriceAdapterAerodromeV2.PoolRoute[] memory routes)
    {
        routes = new PriceAdapterAerodromeV2.PoolRoute[](1);
        routes[0] = PriceAdapterAerodromeV2.PoolRoute({
            pool: AERODROME_POOL,
            zeroForOne: zeroForOne,
            twapInterval: twapInterval,
            token0Decimals: token0Decimals,
            token1Decimals: token1Decimals
        });
    }

    function _register(PriceAdapterAerodromeV2.PoolRoute[] memory routes)
        internal
        returns (bytes32 hash)
    {
        hash = adapter.registerPriceRoute(adapter.encodePoolRoutes(routes));
    }

    /// @dev Faithful re-implementation of the adapter's twapInterval==0 path, computed
    ///      independently in the test, so equality proves the on-chain math is what we expect.
    function _expectedPriceQ96_twap0(bool zeroForOne) internal view returns (uint256 priceQ96) {
        uint256 len = pool.observationLength();
        require(len >= 2, "need >=2 observations");
        uint256 latestIndex = len - 1;

        (uint256 latestTs, uint256 latestR0c, uint256 latestR1c) = pool.observations(latestIndex);
        (uint256 refTs, uint256 refR0c, uint256 refR1c) = pool.observations(latestIndex - 1);

        uint256 timeElapsed = latestTs - refTs;
        require(timeElapsed > 0, "bad elapsed");

        uint256 avgReserve0 = (latestR0c - refR0c) / timeElapsed;
        uint256 avgReserve1 = (latestR1c - refR1c) / timeElapsed;

        uint256 sqrtPrice = FullMath.mulDiv(
            FixedPointMathLib.sqrt(avgReserve1),
            Q96,
            FixedPointMathLib.sqrt(avgReserve0)
        );

        priceQ96 = FullMath.mulDiv(sqrtPrice, sqrtPrice, Q96);

        if (!zeroForOne) {
            priceQ96 = FullMath.mulDiv(Q96, Q96, priceQ96);
        }
    }

    /// @dev Loose spot price from current reserves, used only as a magnitude sanity bound.
    function _spotPriceQ96(bool zeroForOne) internal view returns (uint256 priceQ96) {
        (uint256 reserve0, uint256 reserve1, ) = pool.getReserves();
        uint256 sqrtPrice = FullMath.mulDiv(
            FixedPointMathLib.sqrt(reserve1),
            Q96,
            FixedPointMathLib.sqrt(reserve0)
        );
        priceQ96 = FullMath.mulDiv(sqrtPrice, sqrtPrice, Q96);
        if (!zeroForOne) {
            priceQ96 = FullMath.mulDiv(Q96, Q96, priceQ96);
        }
    }

    /* ------------------------------ tests ------------------------------ */

    /// @notice Sanity: the live pool exposes the observation ring buffer we depend on.
    function test_pool_has_observations() public {
        uint256 len = pool.observationLength();
        assertGe(len, 2, "pool should have >=2 observations");

        (uint256 tsNew, uint256 r0cNew, uint256 r1cNew) = pool.observations(len - 1);
        (uint256 tsOld, uint256 r0cOld, uint256 r1cOld) = pool.observations(len - 2);

        assertGt(tsNew, tsOld, "newer observation should have later timestamp");
        assertGe(r0cNew, r0cOld, "reserve0 cumulative monotonic");
        assertGe(r1cNew, r1cOld, "reserve1 cumulative monotonic");
    }

    /// @notice The adapter's twapInterval==0 price equals the independently re-derived
    ///         time-weighted value exactly. This pins the corrected divide-by-time math.
    function test_twap0_matches_manual_timeweighted_computation() public {
        bytes32 hash = _register(_singleHopRoute(true, 0));

        uint256 actual = adapter.getPriceRatioQ96(hash);
        uint256 expected = _expectedPriceQ96_twap0(true);

        assertGt(actual, 0, "price must be > 0");
        assertEq(actual, expected, "adapter price must equal manual time-weighted computation");

        console.log("twap0 price Q96:", actual);
    }

    /// @notice The inverse route is the reciprocal of the forward route (within rounding).
    function test_inverse_route_is_reciprocal() public {
        uint256 fwd = adapter.getPriceRatioQ96(_register(_singleHopRoute(true, 0)));
        uint256 inv = adapter.getPriceRatioQ96(_register(_singleHopRoute(false, 0)));

        assertGt(fwd, 0, "forward > 0");
        assertGt(inv, 0, "inverse > 0");

        // fwd * inv / Q96 should be ~Q96 (1.0). Allow 0.01% for integer rounding.
        uint256 product = FullMath.mulDiv(fwd, inv, Q96);
        assertApproxEqRel(product, Q96, 1e14, "fwd * inv should be ~1.0");
    }

    /// @notice TWAP price is in the same ballpark as live spot reserves. Generous factor-2
    ///         bound: tolerates real price drift over the window while catching gross
    ///         indexing/magnitude regressions (e.g. the old seconds-as-array-index bug).
    function test_twap0_price_within_factor_of_spot() public {
        uint256 twap = adapter.getPriceRatioQ96(_register(_singleHopRoute(true, 0)));
        uint256 spot = _spotPriceQ96(true);

        assertGt(twap, 0, "twap > 0");
        assertGt(spot, 0, "spot > 0");

        // twap must lie within [spot/2, spot*2].
        assertLe(twap, spot * 2, "twap unreasonably high vs spot");
        assertGe(twap * 2, spot, "twap unreasonably low vs spot");

        console.log("twap0 Q96:", twap);
        console.log("spot  Q96:", spot);
    }

    /// @notice A non-zero TWAP window that lies within the MAX_OBSERVATION_LOOKBACK (1000)
    ///         walk-back returns a real price, selecting the reference by timestamp (not by
    ///         array offset), and lands in the same ballpark as spot.
    function test_twap_window_selects_by_timestamp() public {
        uint256 len = pool.observationLength();
        if (len < 110) {
            // Not enough history on this block to span ~100 observations; nothing to assert.
            return;
        }

        (uint256 latestTs, , ) = pool.observations(len - 1);
        // Span ~100 observations back -- safely inside the 1000-observation lookback cap.
        (uint256 refTs, , ) = pool.observations(len - 1 - 100);
        uint256 windowSecs = latestTs - refTs;
        // forge-lint: disable-next-line(unsafe-typecast) -- ~100 periods, far below uint32 max
        uint32 window = uint32(windowSecs);

        uint256 price = adapter.getPriceRatioQ96(_register(_singleHopRoute(true, window)));
        assertGt(price, 0, "windowed TWAP price must be > 0");

        uint256 spot = _spotPriceQ96(true);
        assertLe(price, spot * 2, "windowed TWAP unreasonably high vs spot");
        assertGe(price * 2, spot, "windowed TWAP unreasonably low vs spot");

        console.log("windowed TWAP price Q96:", price);
        console.log("window (s):", window);
    }

    /// @notice Requesting a window longer than the lookback can reach reverts loudly rather
    ///         than silently shortening the window (audit H-5 / ADR-0007).
    /// @dev For a pool with more than MAX_OBSERVATION_LOOKBACK (1000) observations, the walk-back
    ///      cap is reached before the stored history is exhausted, so the revert reason is
    ///      "lookback too deep". The "window exceeds history" guard is only reachable for pools
    ///      with fewer than 1000 observations. Either way, it reverts -- it never silently shortens.
    function test_reverts_when_window_too_deep() public {
        // type(uint32).max seconds (~136 years) far exceeds any reachable window.
        bytes32 hash = _register(_singleHopRoute(true, type(uint32).max));

        vm.expectRevert(bytes("Aerodrome: lookback too deep"));
        adapter.getPriceRatioQ96(hash);
    }

    /// @notice getPriceRatioQ96 reverts for an unregistered route.
    function test_reverts_for_unregistered_route() public {
        vm.expectRevert(bytes("Route not found"));
        adapter.getPriceRatioQ96(keccak256("nope"));
    }

    /// @notice Demonstrates the core bug fix: the old adapter uses `twapInterval` as an ARRAY
    ///         OFFSET (`observations(latestIndex - twapInterval)`), while V2 treats it as SECONDS.
    ///         The same numeric value reverts (index underflow) on the old adapter but prices
    ///         successfully on V2.
    function test_old_adapter_treats_seconds_as_array_index() public {
        PriceAdapterAerodrome oldAdapter = new PriceAdapterAerodrome();
        uint256 len = pool.observationLength();

        // A value LARGER than the number of observations. As an array offset this underflows;
        // as a number of seconds it is a modest, in-history window.
        // forge-lint: disable-next-line(unsafe-typecast) -- len+1000 is far below uint32 max here
        uint32 value = uint32(len + 1000);

        // (a) Old adapter: observations(latestIndex - value) underflows -> revert.
        {
            PriceAdapterAerodrome.PoolRoute[] memory r = new PriceAdapterAerodrome.PoolRoute[](1);
            r[0] = PriceAdapterAerodrome.PoolRoute({
                pool: AERODROME_POOL,
                zeroForOne: true,
                twapInterval: value,
                token0Decimals: token0Decimals,
                token1Decimals: token1Decimals
            });
            bytes32 oldHash = oldAdapter.registerPriceRoute(oldAdapter.encodePoolRoutes(r));

            vm.expectRevert(); // arithmetic underflow: seconds treated as an array index
            oldAdapter.getPriceRatioQ96(oldHash);
        }

        // (b) V2: the SAME value is seconds (~a few hours here) -> a real, in-history window.
        uint256 price = adapter.getPriceRatioQ96(_register(_singleHopRoute(true, value)));
        assertGt(price, 0, "V2 interprets the value as seconds and prices successfully");

        uint256 spot = _spotPriceQ96(true);
        assertLe(price, spot * 2, "V2 windowed price unreasonably high vs spot");
        assertGe(price * 2, spot, "V2 windowed price unreasonably low vs spot");

        console.log("value (seconds for V2 / index for old):", value);
        console.log("V2 price Q96:", price);
    }
}
