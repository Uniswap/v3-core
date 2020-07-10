// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

// a library for performing overflow-safe math, courtesy of DappHub (https://github.com/dapphub/ds-math)
// and OpenZeppelin (https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/math/SignedSafeMath.sol)

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
}

library SafeMathUint112 {
    function add(uint112 x, uint112 y) internal pure returns (uint112 z) {
        require((z = x + y) >= x, 'SafeMath: ADD_OVERFLOW');
    }

    function sub(uint112 x, uint112 y) internal pure returns (uint112 z) {
        require((z = x - y) <= x, 'SafeMath: SUB_UNDERFLOW');
    }

    function mul(uint112 x, uint112 y) internal pure returns (uint112 z) {
        require(y == 0 || (z = x * y) / y == x, 'SafeMath: MUL_OVERFLOW');
    }

    // add an int112 to a uint112
    // revert on overflow or if result would be negative
    // TODO: rename?
    function add(uint112 x, int112 y) internal pure returns (uint112) {
        return (y >= 0) ? add(x, uint112(y)) : sub(x, uint112(-1 * y));
    }
}

library SafeMathInt112 {
    function abs(int112 x) internal pure returns (uint112 y) {
        return x > 0 ? uint112(x) : uint112(-1 * x);
    }

    function add(int112 a, int112 b) internal pure returns (int112 c) {
        c = a + b;
        require((b >= 0 && c >= a) || (b < 0 && c < a), "SignedSafeMath: ADD_OVERFLOW");
    }

    function sub(int112 a, int112 b) internal pure returns (int112 c) {
        c = a - b;
        require((b >= 0 && c <= a) || (b < 0 && c > a), "SignedSafeMath: SUB_OVERFLOW");
    }

    // TODO: this is our own implementation and needs to be checked
    function mul(int112 a, int112 b) internal pure returns (int112 c) {
        int _c = int(a) * int(b);
        require(_c < type(int112).max && _c > type(int112).min, "SignedSafeMath: MUL_OVERFLOW");
        c = int112(_c);
    }

}
