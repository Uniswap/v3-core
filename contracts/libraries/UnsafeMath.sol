// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

/// @title Math functions that do not check inputs or outputs
/// @notice Contains methods that perform common math functions but do not do any overflow or underflow checks
library UnsafeMath {
    /// @notice Returns ceil(x / y)
    /// @dev panics if y == 0
    function divRoundingUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
        // addition is safe because (type(uint256).max / 1) + (type(uint256).max % 1 > 0 ? 1 : 0) == type(uint256).max
        z = (x / y) + (x % y > 0 ? 1 : 0);
    }
}
