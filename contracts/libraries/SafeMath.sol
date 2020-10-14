// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

// a library for performing overflow-safe math, courtesy of:
// DappHub (https://github.com/dapphub/ds-math)
// OpenZeppelin (https://github.com/OpenZeppelin/openzeppelin-contracts)

library SafeMath {
    function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x, 'ds-math-add-overflow');
    }

    function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x, 'ds-math-sub-underflow');
    }

    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x, 'ds-math-mul-overflow');
    }

    function iadd(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a + b;
        require((b >= 0 && c >= a) || (b < 0 && c < a), 'SignedSafeMath: addition overflow');

        return c;
    }

    function isub(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a - b;
        require((b >= 0 && c <= a) || (b < 0 && c > a), 'SignedSafeMath: subtraction overflow');

        return c;
    }

    int256 private constant _INT256_MIN = -2**255;

    function imul(int256 a, int256 b) internal pure returns (int256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        require(!(a == -1 && b == _INT256_MIN), 'SignedSafeMath: multiplication overflow');

        int256 c = a * b;
        require(c / a == b, 'SignedSafeMath: multiplication overflow');

        return c;
    }

    // TODO check that this is gas efficient as compared to requiring `y <= type(uint112).max`
    function toUint112(uint256 y) internal pure returns (uint112 z) {
        require((z = uint112(y)) == y, 'downcast-overflow');
    }

    // TODO check that this is gas efficient as compared to requiring `y <= type(int112).max`
    function toInt112(uint256 y) internal pure returns (int112 z) {
        require((z = int112(y)) >= 0 && uint256(z) == y, 'downcast-overflow');
    }

    // TODO check that this is gas efficient as compared to requiring `y <= type(int128).max`
    function itoInt112(int256 y) internal pure returns (int112 z) {
        require((z = int112(y)) == y, 'downcast-overflow');
    }

    function addi(uint256 x, int256 y) internal pure returns (uint256 z) {
        z = y < 0 ? sub(x, uint256(-y)) : add(x, uint256(y));
    }

    function subi(uint256 x, int256 y) internal pure returns (uint256 z) {
        z = y < 0 ? add(x, uint256(-y)) : sub(x, uint256(y));
    }
}
