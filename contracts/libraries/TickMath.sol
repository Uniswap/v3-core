// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import '@uniswap/lib/contracts/libraries/FixedPoint.sol';

import 'abdk-libraries-solidity/ABDKMathQuad.sol';

library TickMath {
    int16 public constant MAX_TICK = 7802;
    int16 public constant MIN_TICK = -7802;
    // quad tick multiplier
    // ABDKMathQuad.log_2(ABDKMathQuad.from64x64(int128(101 << 64) / 100))
    bytes16 public constant TICK_MULTIPLIER = 0x3ff8d664ecee35b77e6334057c6a534f;
    uint224 public constant ONE = 1 << 112;

    // given a tick index, return the corresponding price in a FixedPoint.uq112x112 struct
    // a tick represents a reserves ratio of 1.01^tick
    function getPrice(int16 tick) internal pure returns (FixedPoint.uq112x112 memory) {
        if (tick == 0) {
            return FixedPoint.uq112x112(ONE);
        }

        require(tick <= MAX_TICK, 'TickMath: OVERFLOW_UQ112x112'); // too large for a uq112x112
        require(tick >= MIN_TICK, 'TickMath: UNDERFLOW_UQ112x112'); // too small for a uq112x112

        bytes16 power = ABDKMathQuad.mul(TICK_MULTIPLIER, ABDKMathQuad.fromInt(tick));

        int256 result = ABDKMathQuad.to128x128(ABDKMathQuad.pow_2(power));

        uint224 converted = uint224(result >> 16);

        return FixedPoint.uq112x112(converted);
    }
}
