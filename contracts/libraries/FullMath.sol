// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.0;

/// @title Contains 512-bit math functions
/// @notice This library facilitates multiplication and division that can have overflow of an intermediate value without any loss of precision
/// @dev Addresses "phantom overflow", i.e. allows multiplication and division where an intermediate value overflows 256 bits
library FullMath {
    /// @notice Calculates (x*y) two 256-bit unsigned integers, and returns the result as a 512-bit uint split into two 256-bit parts
    /// @param x The multiplicand
    /// @param y The multiplier
    /// @return l The least significant 256 bits of the 512 bit result
    /// @return h The most significant 256 bits of the 512 bit result
    /// @dev Credit to Remco Bloemen https://xn--2-umb.com/17/full-mul/index.html
    function fullMul(uint256 x, uint256 y) internal pure returns (uint256 l, uint256 h) {
        assembly {
            let mm := mulmod(x, y, not(0))
            l := mul(x, y)
            h := sub(sub(mm, l), lt(mm, l))
        }
    }

    /// @notice Calculates floor(x×y÷d) with full precision. Throws if result overflows a uint256 or d == 0
    /// @param x The multiplicand
    /// @param y The multiplier
    /// @param d The divisor
    /// @return The result
    /// @dev Credit to https://medium.com/coinmonks/math-in-solidity-part-3-percents-and-proportions-4db014e080b1
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 d
    ) internal pure returns (uint256) {
        uint256 z = x * y;
        if (x == 0 || z / x == y) {
            // todo: this will panic if d == 0, rather than revert
            return (z / d);
        }

        (uint256 l, uint256 h) = fullMul(x, y);
        // this reverts if the result overflows OR d == 0
        // todo: this behavior is inconsistent with the short circuit above
        require(h < d);

        // subtract remainder
        uint256 mm = mulmod(x, y, d);
        if (mm > l) h -= 1;
        l -= mm;

        // begin division
        uint256 pow2 = d & -d;
        d /= pow2;
        l /= pow2;
        l += h * ((-pow2) / pow2 + 1);
        uint256 r = 1;
        r *= 2 - d * r;
        r *= 2 - d * r;
        r *= 2 - d * r;
        r *= 2 - d * r;
        r *= 2 - d * r;
        r *= 2 - d * r;
        r *= 2 - d * r;
        r *= 2 - d * r;
        return l * r;
    }

    /// @notice Calculates ceil(x×y÷d) with full precision. Throws if result overflows a uint256 or d == 0
    /// @param x The multiplicand
    /// @param y The multiplier
    /// @param d The divisor
    /// @return The result
    function mulDivRoundingUp(
        uint256 x,
        uint256 y,
        uint256 d
    ) internal pure returns (uint256) {
        // todo: this mulmod is duplicate work, already computed in mulDiv
        return mulDiv(x, y, d) + (mulmod(x, y, d) > 0 ? 1 : 0);
    }
}
