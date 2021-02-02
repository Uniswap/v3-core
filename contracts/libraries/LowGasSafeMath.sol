// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0;

/// @title Optimized revert-safe math operations
/// @notice Contains methods for doing revert safe math operations for minimal gas cost
library LowGasSafeMath {
    /// @notice Returns x + y, reverts if overflows uint256
    function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x);
    }

    /// @notice Returns x - y, reverts if underflows
    function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x);
    }

    /// @notice Returns x * y, reverts if overflows
    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(x == 0 || (z = x * y) / x == y);
    }

    /// @notice Returns x + y, reverts if overflows or underflows
    function add(int256 x, int256 y) internal pure returns (int256 z) {
        require((z = x + y) >= x == (y >= 0));
    }

    /// @notice Returns x - y, reverts if overflows or underflows
    function sub(int256 x, int256 y) internal pure returns (int256 z) {
        require((z = x - y) <= x == (y >= 0));
    }

    /// @notice Returns ceil(x / y)
    /// @dev TODO: This method is not safe. It panics on division by zero. In many cases that it is called, we do not
    ///     want to waste gas on a require for the denominator.
    function divRoundingUp(uint256 x, uint256 d) internal pure returns (uint256 z) {
        // addition is safe because (type(uint256).max / 1) + (type(uint256).max % 1 > 0 ? 1 : 0) == type(uint256).max
        z = (x / d) + (x % d > 0 ? 1 : 0);
    }
}
