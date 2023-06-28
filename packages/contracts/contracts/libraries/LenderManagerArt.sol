/**
 *Submitted for verification at Etherscan.io on 2023-06-21
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;




/**
 * @dev Provides a set of functions to operate with Base64 strings.
 *
 * _Available since v4.5._
 */
library Base64 {
    /**
     * @dev Base64 Encoding/Decoding Table
     */
    string internal constant _TABLE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    /**
     * @dev Converts a `bytes` to its Bytes64 `string` representation.
     */
    function encode(bytes memory data) internal pure returns (string memory) {
        /**
         * Inspired by Brecht Devos (Brechtpd) implementation - MIT licence
         * https://github.com/Brechtpd/base64/blob/e78d9fd951e7b0977ddca77d92dc85183770daf4/base64.sol
         */
        if (data.length == 0) return "";

        // Loads the table into memory
        string memory table = _TABLE;

        // Encoding takes 3 bytes chunks of binary data from `bytes` data parameter
        // and split into 4 numbers of 6 bits.
        // The final Base64 length should be `bytes` data length multiplied by 4/3 rounded up
        // - `data.length + 2`  -> Round up
        // - `/ 3`              -> Number of 3-bytes chunks
        // - `4 *`              -> 4 characters for each chunk
        string memory result = new string(4 * ((data.length + 2) / 3));

        /// @solidity memory-safe-assembly
        assembly {
            // Prepare the lookup table (skip the first "length" byte)
            let tablePtr := add(table, 1)

            // Prepare result pointer, jump over length
            let resultPtr := add(result, 32)

            // Run over the input, 3 bytes at a time
            for {
                let dataPtr := data
                let endPtr := add(data, mload(data))
            } lt(dataPtr, endPtr) {

            } {
                // Advance 3 bytes
                dataPtr := add(dataPtr, 3)
                let input := mload(dataPtr)

                // To write each character, shift the 3 bytes (18 bits) chunk
                // 4 times in blocks of 6 bits for each character (18, 12, 6, 0)
                // and apply logical AND with 0x3F which is the number of
                // the previous character in the ASCII table prior to the Base64 Table
                // The result is then added to the table to get the character to write,
                // and finally write it in the result pointer but with a left shift
                // of 256 (1 byte) - 8 (1 ASCII char) = 248 bits

                mstore8(resultPtr, mload(add(tablePtr, and(shr(18, input), 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance

                mstore8(resultPtr, mload(add(tablePtr, and(shr(12, input), 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance

                mstore8(resultPtr, mload(add(tablePtr, and(shr(6, input), 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance

                mstore8(resultPtr, mload(add(tablePtr, and(input, 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance
            }

            // When data `bytes` is not exactly 3 bytes long
            // it is padded with `=` characters at the end
            switch mod(mload(data), 3)
            case 1 {
                mstore8(sub(resultPtr, 1), 0x3d)
                mstore8(sub(resultPtr, 2), 0x3d)
            }
            case 2 {
                mstore8(sub(resultPtr, 1), 0x3d)
            }
        }

        return result;
    }
}
 

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    /**
     * @dev Muldiv operation overflow.
     */
    error MathOverflowedMulDiv();

    enum Rounding {
        Down, // Toward negative infinity
        Up, // Toward infinity
        Zero // Toward zero
    }

    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v5.0._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v5.0._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v5.0._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v5.0._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v5.0._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds up instead
     * of rounding down.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        if (b == 0) {
            // Guarantee the same behavior as in a regular Solidity division.
            return a / b;
        }

        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a == 0 ? 0 : (a - 1) / b + 1;
    }

    /**
     * @notice Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
     * @dev Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv)
     * with further edits by Uniswap Labs also under MIT license.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
            // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2^256 + prod0.
            uint256 prod0; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(x, y, not(0))
                prod0 := mul(x, y)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Handle non-overflow cases, 256 by 256 division.
            if (prod1 == 0) {
                // Solidity will revert if denominator == 0, unlike the div opcode on its own.
                // The surrounding unchecked block does not change this fact.
                // See https://docs.soliditylang.org/en/latest/control-structures.html#checked-or-unchecked-arithmetic.
                return prod0 / denominator;
            }

            // Make sure the result is less than 2^256. Also prevents denominator == 0.
            if (denominator <= prod1) {
                revert MathOverflowedMulDiv();
            }

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [prod1 prod0].
            uint256 remainder;
            assembly {
                // Compute remainder using mulmod.
                remainder := mulmod(x, y, denominator)

                // Subtract 256 bit number from 512 bit number.
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator. Always >= 1.
            // See https://cs.stackexchange.com/q/138556/92363.

            // Does not overflow because the denominator cannot be zero at this stage in the function.
            uint256 twos = denominator & (~denominator + 1);
            assembly {
                // Divide denominator by twos.
                denominator := div(denominator, twos)

                // Divide [prod1 prod0] by twos.
                prod0 := div(prod0, twos)

                // Flip twos such that it is 2^256 / twos. If twos is zero, then it becomes one.
                twos := add(div(sub(0, twos), twos), 1)
            }

            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * twos;

            // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
            // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv = 1 mod 2^4.
            uint256 inverse = (3 * denominator) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also works
            // in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2^8
            inverse *= 2 - denominator * inverse; // inverse mod 2^16
            inverse *= 2 - denominator * inverse; // inverse mod 2^32
            inverse *= 2 - denominator * inverse; // inverse mod 2^64
            inverse *= 2 - denominator * inverse; // inverse mod 2^128
            inverse *= 2 - denominator * inverse; // inverse mod 2^256

            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
            // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inverse;
            return result;
        }
    }

    /**
     * @notice Calculates x * y / denominator with full precision, following the selected rounding direction.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator, Rounding rounding) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (rounding == Rounding.Up && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded down.
     *
     * Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        // For our first guess, we get the biggest power of 2 which is smaller than the square root of the target.
        //
        // We know that the "msb" (most significant bit) of our target number `a` is a power of 2 such that we have
        // `msb(a) <= a < 2*msb(a)`. This value can be written `msb(a)=2**k` with `k=log2(a)`.
        //
        // This can be rewritten `2**log2(a) <= a < 2**(log2(a) + 1)`
        // → `sqrt(2**k) <= sqrt(a) < sqrt(2**(k+1))`
        // → `2**(k/2) <= sqrt(a) < 2**((k+1)/2) <= 2**(k/2 + 1)`
        //
        // Consequently, `2**(log2(a) / 2)` is a good first approximation of `sqrt(a)` with at least 1 correct bit.
        uint256 result = 1 << (log2(a) >> 1);

        // At this point `result` is an estimation with one bit of precision. We know the true value is a uint128,
        // since it is the square root of a uint256. Newton's method converges quadratically (precision doubles at
        // every iteration). We thus need at most 7 iteration to turn our partial result with one bit of precision
        // into the expected uint128 result.
        unchecked {
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            return min(result, a / result);
        }
    }

    /**
     * @notice Calculates sqrt(a), following the selected rounding direction.
     */
    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = sqrt(a);
            return result + (rounding == Rounding.Up && result * result < a ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 2, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 128;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 64;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 32;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 16;
            }
            if (value >> 8 > 0) {
                value >>= 8;
                result += 8;
            }
            if (value >> 4 > 0) {
                value >>= 4;
                result += 4;
            }
            if (value >> 2 > 0) {
                value >>= 2;
                result += 2;
            }
            if (value >> 1 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 2, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log2(value);
            return result + (rounding == Rounding.Up && 1 << result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 10, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10 ** 64) {
                value /= 10 ** 64;
                result += 64;
            }
            if (value >= 10 ** 32) {
                value /= 10 ** 32;
                result += 32;
            }
            if (value >= 10 ** 16) {
                value /= 10 ** 16;
                result += 16;
            }
            if (value >= 10 ** 8) {
                value /= 10 ** 8;
                result += 8;
            }
            if (value >= 10 ** 4) {
                value /= 10 ** 4;
                result += 4;
            }
            if (value >= 10 ** 2) {
                value /= 10 ** 2;
                result += 2;
            }
            if (value >= 10 ** 1) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log10(value);
            return result + (rounding == Rounding.Up && 10 ** result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 256, rounded down, of a positive value.
     * Returns 0 if given 0.
     *
     * Adding one to the result gives the number of pairs of hex symbols needed to represent `value` as a hex string.
     */
    function log256(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 16;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 8;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 4;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 2;
            }
            if (value >> 8 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 256, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + (rounding == Rounding.Up && 1 << (result << 3) < value ? 1 : 0);
        }
    }
}


/**
 * @dev Standard signed math utilities missing in the Solidity language.
 */
library SignedMath {
    /**
     * @dev Returns the largest of two signed numbers.
     */
    function max(int256 a, int256 b) internal pure returns (int256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two signed numbers.
     */
    function min(int256 a, int256 b) internal pure returns (int256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two signed numbers without overflow.
     * The result is rounded towards zero.
     */
    function average(int256 a, int256 b) internal pure returns (int256) {
        // Formula from the book "Hacker's Delight"
        int256 x = (a & b) + ((a ^ b) >> 1);
        return x + (int256(uint256(x) >> 255) & (a ^ b));
    }

    /**
     * @dev Returns the absolute unsigned value of a signed value.
     */
    function abs(int256 n) internal pure returns (uint256) {
        unchecked {
            // must be unchecked in order to support `n = type(int256).min`
            return uint256(n >= 0 ? n : -n);
        }
    }
}


/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev The `value` string doesn't fit in the specified `length`.
     */
    error StringsInsufficientHexLength(uint256 value, uint256 length);

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = Math.log10(value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;
            /// @solidity memory-safe-assembly
            assembly {
                ptr := add(buffer, add(32, length))
            }
            while (true) {
                ptr--;
                /// @solidity memory-safe-assembly
                assembly {
                    mstore8(ptr, byte(mod(value, 10), _SYMBOLS))
                }
                value /= 10;
                if (value == 0) break;
            }
            return buffer;
        }
    }

    /**
     * @dev Converts a `int256` to its ASCII `string` decimal representation.
     */
    /*function toStringSigned(int256 value) internal pure returns (string memory) {
        return string.concat(value < 0 ? "-" : "", toString(SignedMath.abs(value)));
    }*/

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        unchecked {
            return toHexString(value, Math.log256(value) + 1);
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        uint256 localValue = value;
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _SYMBOLS[localValue & 0xf];
            localValue >>= 4;
        }
        if (localValue != 0) {
            revert StringsInsufficientHexLength(value, length);
        }
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }

    /**
     * @dev Returns true if the two strings are equal.
     */
    function equal(string memory a, string memory b) internal pure returns (bool) {
        return bytes(a).length == bytes(b).length && keccak256(bytes(a)) == keccak256(bytes(b));
    }
}

 

library LenderManagerArt {
 


bytes constant _bg_defs_filter = abi.encodePacked (


    "<filter id='f1'>",
      "<feImage result='p0' xlink:href='data:image/svg+xml;base64,PHN2ZyB3aWR0aD0nMjkwJyBoZWlnaHQ9JzUwMCcgdmlld0JveD0nMCAwIDI5MCA1MDAnIHhtbG5zPSdodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2Zyc+PHJlY3Qgd2lkdGg9JzI5MHB4JyBoZWlnaHQ9JzUwMHB4JyBmaWxsPScjMEQyQjI4Jy8+PC9zdmc+' />",
      "<feImage result='p1' xlink:href='data:image/svg+xml;base64,PHN2ZyB3aWR0aD0nMjkwJyBoZWlnaHQ9JzUwMCcgdmlld0JveD0nMCAwIDI5MCA1MDAnIHhtbG5zPSdodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2Zyc+PGNpcmNsZSBjeD0nMTknIGN5PScyNzEnIHI9JzEyMHB4JyBmaWxsPScjMjdFNkUyJy8+PC9zdmc+' />",
      "<feImage result='p2' xlink:href='data:image/svg+xml;base64,PHN2ZyB3aWR0aD0nMjkwJyBoZWlnaHQ9JzUwMCcgdmlld0JveD0nMCAwIDI5MCA1MDAnIHhtbG5zPSdodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2Zyc+PGNpcmNsZSBjeD0nMTA0JyBjeT0nNDYyJyByPScxMjBweCcgZmlsbD0nIzAwQzVDMScvPjwvc3ZnPg==' />",
      "<feImage result='p3' xlink:href='data:image/svg+xml;base64,PHN2ZyB3aWR0aD0nMjkwJyBoZWlnaHQ9JzUwMCcgdmlld0JveD0nMCAwIDI5MCA1MDAnIHhtbG5zPSdodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2Zyc+PGNpcmNsZSBjeD0nMjU4JyBjeT0nNDQzJyByPScxMDBweCcgZmlsbD0nI0EzREZFMCcvPjwvc3ZnPg==' />",
      "<feBlend mode='overlay' in='p0' in2='p1' />",
      "<feBlend mode='exclusion' in2='p2' />",
      "<feBlend mode='overlay' in2='p3' result='blendOut' />"
      "<feGaussianBlur in='blendOut' stdDeviation='42' />",
    "</filter>"

);
 

bytes constant _bg_defs_clip_path = abi.encodePacked (


     "<clipPath id='corners'>",
      "<rect width='290' height='500' rx='6' ry='6' />",
    "</clipPath>",
    
    "<path id='minimap' d='M234 444C234 457.949 242.21 463 253 463' />",
    "<filter id='top-region-blur'>",
      "<feGaussianBlur in='SourceGraphic' stdDeviation='24' />",
    "</filter>",
    "<linearGradient id='grad-up' x1='1' x2='0' y1='1' y2='0'>",
      "<stop offset='0.0' stop-color='white' stop-opacity='1' />",
      "<stop offset='.9' stop-color='white' stop-opacity='0' />",
    "</linearGradient>",
    "<linearGradient id='grad-down' x1='0' x2='1' y1='0' y2='1'>",
      "<stop offset='0.0' stop-color='white' stop-opacity='1' />",
      "<stop offset='0.9' stop-color='white' stop-opacity='0' />",
    "</linearGradient>"

);
 

bytes constant _bg_defs_mask = abi.encodePacked (
  "<mask id='fade-up' maskContentUnits='objectBoundingBox'>",
      "<rect width='1' height='1' fill='url(#grad-up)' />",
    "</mask>",
    "<mask id='fade-down' maskContentUnits='objectBoundingBox'>",
      "<rect width='1' height='1' fill='url(#grad-down)' />",
    "</mask>",
    "<mask id='none' maskContentUnits='objectBoundingBox'>",
      "<rect width='1' height='1' fill='white' />",
    "</mask>",

    "<linearGradient id='grad-symbol'>",
      "<stop offset='0.7' stop-color='white' stop-opacity='1' />",
      "<stop offset='.95' stop-color='white' stop-opacity='0' />",
    "</linearGradient>",
    "<mask id='fade-symbol' maskContentUnits='userSpaceOnUse'>",
      "<rect width='290px' height='200px' fill='url(#grad-symbol)' />",
    "</mask>"
);

bytes constant _bg_defs =  abi.encodePacked(
    "<defs>",

  
    _bg_defs_filter,

    _bg_defs_clip_path,

    _bg_defs_mask,
   
  


"</defs>"

);


bytes constant _clip_path_corners = abi.encodePacked(  

     "<g clip-path='url(#corners)'>",
    "<rect fill='83843f' x='0px' y='0px' width='290px' height='500px' />",
    "<rect style='filter: url(#f1)' x='0px' y='0px' width='290px' height='500px' />",
    "<g style='filter:url(#top-region-blur); transform:scale(1.5); transform-origin:center top;'>",
    "<rect fill='none' x='0px' y='0px' width='290px' height='500px'/>",
    "<ellipse cx='50%' cy='0px' rx='180px' ry='120px' fill='#000' opacity='0.85'/>",
    "</g>",
    "<rect x='0' y='0' width='290' height='500' rx='0' ry='0' fill='rgba(0,0,0,0)' stroke='rgba(255,255,255,0.2)'/>",
    "</g>"


);

 

bytes constant _teller_logo_path_1 = abi.encodePacked( 
"<path class='st0' d='M151.4,221.5l6.6,15.1l-2.5,4.2L124,226.5l0.8-11.4l3.1-3.9M130.4,182.3l15,28.8l8.6-6.7L130.4,182.3zM145.5,211.1l-16.6-6.7l1.6-22.1l-3.3,3.3l-1.3,22.4l16.7,7.8L145.5,211.1zM128.8,204.4l-3,3.5M142.5,215.7l11.5-11.3'/>",
"<path class='st0' d='M128,211.1l23.5,10.4l11.1-9.5l11.3,11l-15.7,13.7L127.5,223L128,211.1z'/>",
"<path class='st1' d='M156.2,239.7l-31.3-14.2l0.8-11.5'/>",
"<path class='st1' d='M156.8,238.7l-31.1-14l0.7-11.6'/>",
"<path class='st1' d='M157.4,237.6l-30.9-13.8l0.7-11.7'/>",
"<path class='st0' d='M127.3,222.9l-3.3,3.5M155.5,240.8l18.3-17.8M126.5,231l37.4,16.4l18.4-17.2l11.7,11.2c0,0-13.6,1.5-20.1,17.9c0,0-0.8,2.3-2.6,2.4s-4.7-1.7-6-2.6s-20.4-13.8-39.1-16.8L126.5,231L126.5,231z'/>",
"<path class='st0' d='M126.5,231l-3.2,3.1l-0.8,12.5c0,0,16.3,2.3,34.6,13.4c1.4,0.9,2.8,1.9,4.1,2.9c2.1,1.7,6.2,4.3,8.4,1.9l3.3-4M126.2,242.3l-3.7,4.3M164,247.3l7.4,14.3M175.8,255.3c0,0,5.6-8,14.8-9.4l3.4-4.5'/>",
"<path class='st1' d='M175.8,255.3c4.6-8.4,14-11.9,17.1-12.4'/>"

);


bytes constant _teller_logo_path_2 = abi.encodePacked( 

"<path class='st1' d='M175.8,255.3c2.3-4.2,9.8-10,15.9-10.9M125.9,231.6l-0.4,11.5c15,2.4,33.6,13.1,38.2,16.1c1.3,0.9,3.9,2.3,5.6,2.7c1,0.2,2.2,0.5,3-0.3'/>",
"<path class='st1' d='M125.3,232.2l-0.5,11.8c11.3,1.8,29.3,10.3,37.3,15.4c1.4,0.9,3.7,2.2,5.2,2.7c1.3,0.5,3.2,1.5,4.4,0.2'/>",
"<path class='st1' d='M124.6,232.8l-0.6,12c7.5,1.2,25,7.6,36.4,14.7c1.4,0.9,3.4,2,4.9,2.8c1.6,0.8,4.2,2.4,5.7,0.8'/>",
"<path class='st1' d='M124,233.5l-0.7,12.2c3.8,0.6,20.7,5,35.5,14.1c1.4,0.9,3.1,1.9,4.5,2.8c1.9,1.2,5.2,3.4,7.1,1.3M129.7,183l-1.5,22.2l16.6,6.9'/>",
"<path class='st1' d='M129.1,183.6l-1.5,22.2l16.7,7.1'/>",
"<path class='st1' d='M128.4,184.3l-1.4,22.3l16.7,7.3'/>",
"<path class='st1' d='M127.8,184.9l-1.4,22.3l16.7,7.6M143.4,214.4l8.3-8.1M144.1,213l4.6-4.3M156.8,238.7l13.2-12.2'/>",
"<ellipse transform='matrix(0.6384 -0.7697 0.7697 0.6384 -121.0959 193.8277)' class='st2' cx='145.7' cy='225.8' rx='57.9' ry='97.9'/>",
"<ellipse transform='matrix(0.6384 -0.7697 0.7697 0.6384 -118.098 194.5624)' class='st2' cx='148' cy='223' rx='61.5' ry='105.9'/>",
"<path class='st2' d='M62.9,160.5l-7.2,11.2c-16.1,27.3,3.1,75,45.6,110.3c30.3,25.1,64.6,37.4,90.5,34.9c14.1-1.4,26.7-9.1,34.5-20.9l3.7-5.8'/>"


    
);

bytes constant _teller_logo = abi.encodePacked( 


"<svg id='Layer_2' xmlns='http://www.w3.org/2000/svg' viewBox='-5 130 300 236.73'>",
  "<style type='text/css'>",
  ".st0{fill:none;stroke:#FFFFFF;stroke-width:0.3021;stroke-linejoin:round;stroke-miterlimit:1.2083;}",
  ".st1{fill:none;stroke:#FFFFFF;stroke-width:0.151;stroke-linejoin:round;stroke-miterlimit:1.2083;}",
  ".st2{fill:none;stroke:#FFFFFF;stroke-width:0.3021;stroke-miterlimit:3.0208;}",
"</style>",
"<g id='Layer_7'>",
 _teller_logo_path_1,
 _teller_logo_path_2,
"</g></svg>"


);
 


function _generate_large_title( 
    string memory amount,
    string memory symbol
) public pure returns (string memory) {


    return string(abi.encodePacked(

 "<g mask='url(#fade-symbol)'>",
"<rect fill='none' x='0px' y='0px' width='290px' height='200px'/>",
"<text y='50px' x='32px' fill='white' font-family='Courier New, monospace' font-weight='200' font-size='12px'>AMOUNT</text>",
"<text y='90px' x='32px' fill='white' font-family='Courier New, monospace' font-weight='200' font-size='12px'><tspan font-size='36px'>",amount,"</tspan> ",symbol,"</text>",
"</g>",
"<rect x='16' y='16' width='258' height='468' rx='4' ry='4' fill='rgba(0,0,0,0)' stroke='rgba(255,255,255,0.2)'/>"

 

  
  ));
}


function _generate_text_label( 
    string memory label,
    string memory value, 
    
    uint256 y_offset
) public pure returns (string memory) {


    return string(abi.encodePacked(
       "<g style='transform:translate(29px,", Strings.toString(y_offset) , "px)'>",
            "<rect width='232' height='26' rx='4' ry='4' fill='rgba(0,0,0,0.6)'/>",
            "<text x='12' y='17' font-family='Courier New, monospace' font-size='12' fill='#fff'>",
                "<tspan fill='rgba(255,255,255,0.6)'>", label, "</tspan>",value,
            "</text>",
        "</g>"
    ));
}

/*
Not working quite right yet 
*/
function _get_token_amount_formatted( 
    uint256 amount,
    uint256 decimals,
    uint256 precision
) public pure returns (string memory) { 

     uint256 before_decimal = amount / 10 ** decimals;

     uint256 after_decimal = amount % 10 ** decimals;
  
        return string(abi.encodePacked( 
             Strings.toString(before_decimal),
            ".",
             Strings.toString(after_decimal)

         ));
        
      

}


function generateSVG(
        uint256 tokenId,
        uint256 bidId,
        uint256 principalAmount,
        address principalTokenAddress,
        uint256 collateralAmount,
        address collateralTokenAddress,
        uint16 interestRate,
        uint32 duration
        ) public pure returns (string memory) {




string memory principal_amount_formatted = _get_token_amount_formatted( 
    12540000000000000000,
    18 ,
    5
);

string memory principal_token_symbol = "USDC";


string memory collateral_amount_formatted = _get_token_amount_formatted( 
    2000000000000000000000,
    18 ,
    3
);

string memory collateral_token_symbol = "WMATIC";




    string memory svgData = string(abi.encodePacked(

"<svg width='290' height='500' viewBox='0 0 290 500' xmlns='http://www.w3.org/2000/svg' xmlns:xlink='http://www.w3.org/1999/xlink'>",

_bg_defs,


_clip_path_corners,
 

_generate_large_title( 
 principal_amount_formatted,
 principal_token_symbol
),

_teller_logo,


_generate_text_label(
    "Loan ID:",
    Strings.toString(bidId),
    354
),


_generate_text_label(
    "Collateral:",
    string(abi.encodePacked(collateral_amount_formatted," ",collateral_token_symbol)), 
    384
),


_generate_text_label(
    "APR:",
    "30 %",
    414
),


_generate_text_label(
    "Duration:",
    "7 days",
    444
),

 
"</svg>"
    ));

    return svgData;
}

 



}



