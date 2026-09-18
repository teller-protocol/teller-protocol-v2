// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Testable.sol";

import { FullMath } from "../contracts/libraries/uniswap/FullMath.sol";
import { SqrtPriceMath } from "../contracts/libraries/uniswap/SqrtPriceMath.sol";

/**
 * FullMath.mulDiv exists to survive a "phantom overflow": an a*b that does not
 * fit in 256 bits even though a*b/denominator does. It does that with a 512-bit
 * path built entirely on wrapping arithmetic.
 *
 * Uniswap wrote that path for Solidity 0.7, where the arithmetic wrapped. This
 * repo compiles it under 0.8, where the same expressions revert with
 * Panic(0x11) - so the branch that handles the overflow became the branch that
 * guarantees a revert, and mulDiv worked only when it was not needed.
 *
 * On chain that showed up as a view-quoter that could not quote any pool whose
 * price was high enough to push liquidity*2**96 * priceDelta over 2**256. On
 * Robinhood Chain that was every pool holding USDG as token0 - SGOV, GLD, QQQ
 * and NVDA - so Loop showed "Receive 0.00" against four of the deepest pools on
 * the chain while the four low-priced ones quoted fine.
 *
 * The numbers below are read off the live USDG/NVDA pool (0xd4eb2120...), so a
 * regression here is the same failure, not a synthetic one.
 */
contract UniswapFullMath_Test is Testable {
    // Live pool state: liquidity, the current sqrt price, and the sqrt price
    // one tick-spacing lower - the nearest target a zeroForOne swap can have.
    uint128 private constant LIQUIDITY = 16951061585915034688;
    uint160 private constant SQRT_CURRENT =
        5344034588767690705447872101095846;
    uint160 private constant SQRT_TARGET =
        5341361495103877093967399877459302;

    function test_mulDiv_survives_phantom_overflow() public {
        uint256 a = uint256(LIQUIDITY) << 96;
        uint256 b = uint256(SQRT_CURRENT) - uint256(SQRT_TARGET);

        // The product genuinely does not fit in 256 bits: this is the case the
        // 512-bit path is for, and the one that used to revert.
        assertGt(a, type(uint256).max / b, "test no longer exercises the 512-bit path");

        uint256 result = FullMath.mulDiv(a, b, uint256(SQRT_CURRENT));
        assertEq(
            result,
            671771231875269761829759462247859158368309802,
            "mulDiv returned the wrong value on the 512-bit path"
        );
    }

    function test_getAmount0Delta_quotes_a_high_priced_pool() public {
        // What the quoter asks first: how much token0 it takes to move this
        // pool one tick-spacing. Reverted before the fix.
        uint256 amount0 = SqrtPriceMath.getAmount0Delta(
            SQRT_TARGET,
            SQRT_CURRENT,
            LIQUIDITY,
            true
        );

        // 125,767.790196 USDG, six decimals.
        assertEq(amount0, 125767790196, "wrong amount0 for the USDG/NVDA pool");
    }

    function test_mulDiv_unchanged_where_it_already_worked() public {
        // prod1 == 0, so this returns through the early assembly divide and
        // never reaches the 512-bit path. Pinned so the fix cannot have moved
        // the answer for the pools that were already quoting.
        assertEq(FullMath.mulDiv(1e6, 2e6, 7), 285714285714);
        assertEq(FullMath.mulDiv(0, 12345, 7), 0);
        assertEq(FullMath.mulDivRoundingUp(1e6, 2e6, 7), 285714285715);
    }

    function test_mulDiv_result_must_still_fit_in_256_bits() public {
        // The guard that makes the 512-bit path correct is a require, and it
        // sits outside the unchecked block. A denominator too small for the
        // result to fit must still be rejected rather than wrapped.
        vm.expectRevert();
        FullMath.mulDiv(type(uint256).max, type(uint256).max, 1);
    }
}
