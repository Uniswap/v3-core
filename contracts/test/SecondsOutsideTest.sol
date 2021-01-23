// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import '../libraries/SecondsOutside.sol';

contract SecondsOutsideTest {
    using SecondsOutside for mapping(int24 => uint256);

    mapping(int24 => uint256) public secondsOutside;

    function initialize(
        int24 tick,
        int24 tickCurrent,
        int24 tickSpacing,
        uint32 time
    ) external {
        secondsOutside.initialize(tick, tickCurrent, tickSpacing, time);
    }

    function cross(
        int24 tick,
        int24 tickSpacing,
        uint32 time
    ) external {
        secondsOutside.cross(tick, tickSpacing, time);
    }

    function clear(int24 tick, int24 tickSpacing) external {
        secondsOutside.clear(tick, tickSpacing);
    }

    function get(int24 tick, int24 tickSpacing) external view returns (uint32) {
        return secondsOutside.get(tick, tickSpacing);
    }

    function secondsInside(
        int24 tickLower,
        int24 tickUpper,
        int24 tickCurrent,
        int24 tickSpacing,
        uint32 time
    ) external view returns (uint32) {
        return secondsOutside.secondsInside(tickLower, tickUpper, tickCurrent, tickSpacing, time);
    }
}
