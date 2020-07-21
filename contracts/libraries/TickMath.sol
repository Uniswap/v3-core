// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import '@uniswap/lib/contracts/libraries/FixedPoint.sol';
import 'abdk-libraries-solidity/ABDKMathQuad.sol';

// calculates prices, encoded as uq112x112 fixed points, corresponding to reserves ratios of 1.01**tick
library TickMath {
    // the minimum price that can be represented by a uq112x112 fixed point (excluding 0) is 1 / (2**112 - 1)
    // therefore, the smallest possible tick that corresponds to a representable price is -7802, because:
    // 1.01**tick >= 1 / (2**112 - 1)
    // tick >= log_1.01(1 / (2**112 - 1))
    // tick = ceil(log_1.01(1 / (2**112 - 1))) = -7802
    int16 public constant MIN_TICK = -7802;
    // the minimum price that can be represented by a uq112x112 fixed point is (2**112 - 1) / 1 = 2**112 - 1
    // therefore, the largest possible tick that corresponds to a representable price is 7802, because:
    // 1.01**tick <= 2**112 - 1
    // tick <= log_1.01(2**112 - 1)
    // tick = floor(log_1.01(2**112 - 1)) = 7802
    int16 public constant MAX_TICK = 7802;
    // log_2(1.01) represented in 128-bit floating point
    // ABDKMathQuad.log_2(ABDKMathQuad.from64x64(int128(101 << 64) / 100));
    bytes16 private constant TICK_MULTIPLIER = 0x3ff8d664ecee35b77e6334057c6a534f;
    // 1 represented in uq112x122 fixed point
    uint224 private constant ONE = 1 << 112;

    // given a tick index, return the corresponding price as a uq112x112 fixed point
    function getPrice(int16 tick) internal pure returns (FixedPoint.uq112x112 memory) {
        if (tick == 0) {
            return FixedPoint.uq112x112(ONE);
        }

        require(tick >= MIN_TICK, 'TickMath: UNDERFLOW_UQ112x112'); // too small for a uq112x112
        require(tick <= MAX_TICK, 'TickMath: OVERFLOW_UQ112x112');  // too large for a uq112x112

        // 2**(log_2(1.01) * tick)
        // (2**log_2(1.01))**tick
        // 1.01**tick
        bytes16 result = ABDKMathQuad.pow_2(ABDKMathQuad.mul(TICK_MULTIPLIER, ABDKMathQuad.fromInt(tick)));

        int256 converted = ABDKMathQuad.to128x128(result);
        return FixedPoint.uq112x112(uint224(converted >> 16));
    }
}
