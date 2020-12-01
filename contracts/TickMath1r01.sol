// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import './interfaces/ITickMath.sol';

// 1% ticks
// min tick is -7351
// max tick is 7351
contract TickMath1r01 is ITickMath {
    int24 public constant override MIN_TICK = -7351;
    int24 public constant override MAX_TICK = -MIN_TICK;

    function getRatioAtTick(int24 tick) public pure override returns (uint256 ratio) {
        require(tick >= MIN_TICK && tick <= MAX_TICK, 'TickMath1r01::getRatioAtTick: invalid tick');

        uint256 absTick = uint256(tick < 0 ? -tick : tick);

        ratio = absTick & 0x1 != 0 ? 0xfd7720f353a4c0a237c32b16cfd7720f : 0x100000000000000000000000000000000;
        if (absTick & 0x2 != 0) ratio = (ratio * 0xfaf4ae9099c9241ccf4a1b745e424d72) >> 128;
        if (absTick & 0x4 != 0) ratio = (ratio * 0xf602cecfa70ae4afe789b849b8ba756d) >> 128;
        if (absTick & 0x8 != 0) ratio = (ratio * 0xec69657ef75a64f2bc647042cf997b9b) >> 128;
        if (absTick & 0x10 != 0) ratio = (ratio * 0xda527e868273006c1a1a2faf830951f8) >> 128;
        if (absTick & 0x20 != 0) ratio = (ratio * 0xba309a1262e01d7a68fd2cf1bd98bbe8) >> 128;
        if (absTick & 0x40 != 0) ratio = (ratio * 0x876aa91cdb4cdf289fa30a8cd1d4bc37) >> 128;
        if (absTick & 0x80 != 0) ratio = (ratio * 0x47a1aacceae7cbd1d95338b2354be7f2) >> 128;
        if (absTick & 0x100 != 0) ratio = (ratio * 0x140b12d5f200d69fd82ba1b225ef0175) >> 128;
        if (absTick & 0x200 != 0) ratio = (ratio * 0x191bb6c0d95b67023dc9b2e7f36d979) >> 128;
        if (absTick & 0x400 != 0) ratio = (ratio * 0x2766cb1b99879bae2a835f8b53197) >> 128;
        if (absTick & 0x800 != 0) ratio = (ratio * 0x6107b28e3ea71f5ef5255e1a7) >> 128;
        if (absTick & 0x1000 != 0) ratio = (ratio * 0x24c6d58b0bcc3113a5) >> 128;

        if (tick > 0) ratio = uint256(-1) / ratio;
        return ratio;
    }

    // get the ratio from the tick as a 128x128 represented as a uint256
    function getTickAtRatio(uint256 ratio) public pure override returns (int24 tick) {
        // the ratio must be gte the ratio at MIN_TICK and lt the ratio at MAX_TICK
        require(
            ratio >= 5826674 && ratio < 19872759182565593239568746253641083721737304106191725165927866224867416,
            'TickMath1r01::getTickAtRatio: invalid ratio'
        );

        uint256 r = ratio;
        uint256 msb = 0;

        assembly {
            let f := shl(7, gt(r, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF))
            msb := or(msb, f)
            r := shr(f, r)
        }
        assembly {
            let f := shl(6, gt(r, 0xFFFFFFFFFFFFFFFF))
            msb := or(msb, f)
            r := shr(f, r)
        }
        assembly {
            let f := shl(5, gt(r, 0xFFFFFFFF))
            msb := or(msb, f)
            r := shr(f, r)
        }
        assembly {
            let f := shl(4, gt(r, 0xFFFF))
            msb := or(msb, f)
            r := shr(f, r)
        }
        assembly {
            let f := shl(3, gt(r, 0xFF))
            msb := or(msb, f)
            r := shr(f, r)
        }
        assembly {
            let f := shl(2, gt(r, 0xF))
            msb := or(msb, f)
            r := shr(f, r)
        }
        assembly {
            let f := shl(1, gt(r, 0x3))
            msb := or(msb, f)
            r := shr(f, r)
        }
        assembly {
            let f := gt(r, 0x1)
            msb := or(msb, f)
        }

        if (msb >= 128) r = ratio >> (msb - 127);
        else r = ratio << (127 - msb);

        int256 log_2 = (int256(msb) - 128) << 64;

        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(63, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(62, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(61, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(60, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(59, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(58, f))
            r := shr(f, r)
        }
        assembly {
            r := shr(127, mul(r, r))
            let f := shr(128, r)
            log_2 := or(log_2, shl(57, f))
        }

        int256 log_101 = log_2 * 1285013416526911433821; // 128.128 number

        int256 tickLow = (log_101 - 3419638592504137712958323430774557703) >> 128;
        int256 tickHi = (log_101 + 188609930776236967625146103726555653720) >> 128;

        return int24(tickLow == tickHi ? tickLow : getRatioAtTick(int24(tickHi)) <= ratio ? tickHi : tickLow);
    }
}
