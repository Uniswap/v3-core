// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import '../libraries/FullMath.sol';

contract FullMathEchidnaTest {
    // if the mul doesn't overflow in 256-bit space, h should be 0
    function checkFullMulH(uint256 x, uint256 y) external pure {
        require(x == 0 || ((x * y) / x == y));
        (, uint256 h) = FullMath.fullMul(x, y);
        assert(h == 0);
    }

    function checkMulDivRounding(
        uint256 x,
        uint256 y,
        uint256 d
    ) external pure {
        require(d > 0);

        uint256 ceiled = FullMath.mulDivRoundingUp(x, y, d);
        uint256 floored = FullMath.mulDiv(x, y, d);

        if (mulmod(x, y, d) > 0) {
            assert(ceiled - floored == 1);
        } else {
            assert(ceiled == floored);
        }
    }
}
