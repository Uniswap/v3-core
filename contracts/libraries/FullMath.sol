// SPDX-License-Identifier: CC-BY-4.0
pragma solidity >=0.4.0;

/// @title FullMath
/// @notice This library provides solutions for securely handling percents and proportions in solidity.
/// @dev taken from https://medium.com/coinmonks/math-in-solidity-part-3-percents-and-proportions-4db014e080b1

library FullMath {
    /// @notice Multiplies two 256-bit uint's, and returns the result as a 512-bit uint split into two 256-bit parts.
    /// @param x
    /// @param y
    /// @return l The lower portion of an emulated 512 bit width integer
    /// @return h The higher portion of an emulated 512 bit width integer
    function fullMul(uint256 x, uint256 y) private pure returns (uint256 l, uint256 h) {
        uint256 mm = mulmod(x, y, uint256(-1));
        l = x * y;
        h = mm - l;
        if (mm < l) h -= 1;
    }

    /// @dev That calculates x×y÷z, rounds the result down, and throws in case z is zero or if the result 
    ///      does not fit into uint256.
    /// @param x
    /// @param y
    /// @param d 
    /// @return  
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 d
    ) internal pure returns (uint256) {
        if (x == 0 || (x * y) / x == y) return ((x * y) / d);

        (uint256 l, uint256 h) = fullMul(x, y);
        require(h < d, 'FMD');

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
}
