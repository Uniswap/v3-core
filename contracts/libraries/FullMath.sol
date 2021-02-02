// SPDX-License-Identifier: CC-BY-4.0
pragma solidity >=0.4.0;

/// @title FullMath
/// @notice This library facilitates multiplication and division that can have overflow of an intermediate value without any loss of precision
/// @dev Addresses the dynamic of "phantom overflow" where an intermediary multiplication step inside of a larger calculation may trigger overflow of uint256
/// @dev taken from https://medium.com/coinmonks/math-in-solidity-part-3-percents-and-proportions-4db014e080b1
library FullMath {
    /// @notice Multiplies two 256-bit uints, and returns the result as a 512-bit uint split into two 256-bit parts
    /// @param x The multiplicand
    /// @param y The multiplier
    /// @return l The least significant portion of an emulated 512 bit width integer
    /// @return h The most significant portion of an emulated 512 bit width integer
    function fullMul(uint256 x, uint256 y) internal pure returns (uint256 l, uint256 h) {
        uint256 mm = mulmod(x, y, type(uint256).max);
        l = x * y;
        h = mm - l;
        if (mm < l) h -= 1;
    }

    /// @notice Calculates x×y÷z, rounds the result down, and throws in case z is zero or if the result
    ///      does not fit into uint256. Allows math to resolve to a uint256 despite a potential intermediate product that overflows 256 bits
    /// @param x The multiplicand
    /// @param y The multiplier
    /// @param d The divisor
    /// @return The result
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 d
    ) internal pure returns (uint256) {
        if (x == 0 || (x * y) / x == y) return ((x * y) / d);

        (uint256 l, uint256 h) = fullMul(x, y);
        require(h < d);

        // subtract remainder
        uint256 mm = mulmod(x, y, d);
        if (mm > l) h -= 1;
        l -= mm;

        // early return for gas optimization
        if (h == 0) return l / d;

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

    /// @notice Calculates x×y÷z, rounds the result up, and throws in case z is zero or if the result
    ///      does not fit into uint256.
    /// @param x The multiplicand
    /// @param y The multiplier
    /// @param d The divisor
    /// @return The result
    function mulDivRoundingUp(
        uint256 x,
        uint256 y,
        uint256 d
    ) internal pure returns (uint256) {
        return mulDiv(x, y, d) + (mulmod(x, y, d) > 0 ? 1 : 0);
    }
}
