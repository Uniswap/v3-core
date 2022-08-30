pragma solidity ^0.8.0;

import './libraries/TickMath.sol';

contract TestTickMath {

    function f(uint160 x) external pure returns (int24) {
        int24 y = TickMath.getTickAtSqrtRatio(x);
        return y;
    }
}