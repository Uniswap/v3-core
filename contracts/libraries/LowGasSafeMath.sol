// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0;

library LowGasSafeMath {
    function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x);
    }

    function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x);
    }

    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(x == 0 || (z = x * y) / x == y);
    }

    function add(int256 x, int256 y) internal pure returns (int256 z) {
        require((z = x + y) >= x == (y >= 0));
    }

    function sub(int256 x, int256 y) internal pure returns (int256 z) {
        require((z = x - y) <= x == (y >= 0));
    }

    // todo: this isn't 'safe' because it panics on div by zero, but in many cases that it's called we don't
    //      want to waste gas on a require (e.g. dividing by non-zero constant 1<<32)
    function divRoundingUp(uint256 x, uint256 d) internal pure returns (uint256 z) {
        // addition is safe because (type(uint256).max / 1) + (type(uint256).max % 1 > 0 ? 1 : 0) == type(uint256).max
        z = (x / d) + (x % d > 0 ? 1 : 0);
    }
}
