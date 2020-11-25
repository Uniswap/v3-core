// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import './FixedPoint128.sol';

// calculates prices, encoded as uq112x112 fixed points, corresponding to reserves ratios of 1.01**tick
library TickMath {
    // this is the smallest tick s.t. all ticks have unique representations as uq112x112 fixed point numbers
    int24 public constant MIN_TICK = -7351;
    int24 public constant MAX_TICK = -MIN_TICK;

    function getRatioAtTick(int24 tick) internal pure returns (FixedPoint128.uq128x128 memory) {
        uint256 absTick = uint256(tick < 0 ? -tick : tick);
        assert(absTick <= uint256(MAX_TICK));

        uint256 ratio = absTick & 0x1 != 0 ? 0xfd7720f353a4c0a237c32b16cfd7720f : 0x100000000000000000000000000000000;
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
        return FixedPoint128.uq128x128(ratio);
    }
}
