// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

// a library for performing overflow-safe math, courtesy of:
// DappHub (https://github.com/dapphub/ds-math)
// OpenZeppelin (https://github.com/OpenZeppelin/openzeppelin-contracts)

library SafeMath {
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, "ds-math-add-overflow");
    }

    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x, "ds-math-sub-underflow");
    }

    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, "ds-math-mul-overflow");
    }

    function iadd(int a, int b) internal pure returns (int) {
        int c = a + b;
        require((b >= 0 && c >= a) || (b < 0 && c < a), "SignedSafeMath: addition overflow");

        return c;
    }

    function isub(int a, int b) internal pure returns (int) {
        int c = a - b;
        require((b >= 0 && c <= a) || (b < 0 && c > a), "SignedSafeMath: subtraction overflow");

        return c;
    }

    int constant private _INT256_MIN = -2**255;
    function imul(int a, int b) internal pure returns (int) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        require(!(a == -1 && b == _INT256_MIN), "SignedSafeMath: multiplication overflow");

        int c = a * b;
        require(c / a == b, "SignedSafeMath: multiplication overflow");

        return c;
    }

    // TODO check that this is gas efficient as compared to requiring `y <= type(uint112).max`
    function toUint112(uint y) internal pure returns (uint112 z) {
        require((z = uint112(y)) == y, "downcast-overflow");
    }

    // TODO check that this is gas efficient as compared to requiring `y <= type(int112).max`
    function toInt112(uint y) internal pure returns (int112 z) {
        require((z = int112(y)) >= 0 && uint(z) == y, "downcast-overflow");
    }

    // TODO check that this is gas efficient as compared to requiring `y <= type(int128).max`
    function toInt128(uint y) internal pure returns (int128 z) {
        require((z = int128(y)) >= 0 && uint(z) == y, "downcast-overflow");
    }

    // TODO check that this is gas efficient as compared to requiring `y <= type(int128).max`
    function itoInt112(int y) internal pure returns (int112 z) {
        require((z = int112(y)) == y, "downcast-overflow");
    }

    // TODO check that this is gas efficient as compared to requiring `y <= type(int128).max`
    function itoInt128(int y) internal pure returns (int128 z) {
        require((z = int128(y)) == y, "downcast-overflow");
    }

    function addi(uint x, int y) internal pure returns (uint z) {
        z = y < 0 ? sub(x, uint(-y)) : add(x, uint(y));
    }

    function subi(uint x, int y) internal pure returns (uint z) {
        z = y < 0 ? add(x, uint(-y)) : sub(x, uint(y));
    }
}
