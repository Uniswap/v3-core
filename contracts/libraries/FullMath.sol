// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.0;

/// @title Contains 512-bit math functions
/// @notice This library facilitates multiplication and division that can have overflow of an intermediate value without any loss of precision
/// @dev Addresses "phantom overflow", i.e. allows multiplication and division where an intermediate value overflows 256 bits
library FullMath {
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
        uint256 l;
        uint256 h;
        assembly {
            let mm := mulmod(x, y, not(0))
            l := mul(x, y)
            h := sub(sub(mm, l), lt(mm, l))
        }

        // this reverts if the result overflows OR d == 0
        require(h < d);

        if (h == 0) return l / d;

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
