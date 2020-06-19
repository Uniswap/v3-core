pragma solidity >=0.6.0;

// a library for performing overflow-safe math, courtesy of DappHub (https://github.com/dapphub/ds-math)

library SafeMath112 {
    function add(uint112 x, uint112 y) internal pure returns (uint112 z) {
        require((z = x + y) >= x, 'ds-math-add-overflow');
    }

    function sub(uint112 x, uint112 y) internal pure returns (uint112 z) {
        require((z = x - y) <= x, 'ds-math-sub-underflow');
    }

    function mul(uint112 x, uint112 y) internal pure returns (uint112 z) {
        require(y == 0 || (z = x * y) / y == x, 'ds-math-mul-overflow');
    }

    // add an int112 to a uint112
    // revert on overflow or if result would be negative
    function sadd(uint112 x, int112 y) internal pure returns (uint112) {
        return (y >= 0) ? add(x, uint112(y)) : sub(x, uint112(-1 * y));
    }

    function abs(int112 x) internal pure returns (uint112 y) {
        return x > 0 ? uint112(x) : uint112(-1 * x);
    }
}
