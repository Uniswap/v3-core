// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

// the interface for a pluggable tick math implementation, e.g. for different tick sizes
interface ITickMath {
    // the minimum tick. must be less than max tick.
    function MIN_TICK() external view returns (int24);

    // the maximum tick. must be greater than min tick.
    function MAX_TICK() external view returns (int24);

    // get the ratio from the tick as a fixed point 128x128 in a uint256 container
    // must satisfy the following invariant for any tick gt MIN_TICK and lt MAX_TICK:
    // getRatioAtTick(tick - 1) < getRatioAtTick(tick) < getRatioAtTick(tick + 1)
    function getRatioAtTick(int24 tick) external pure returns (uint256 ratio);

    // get the tick from a ratio. must satisfy the invariant:
    // tick := getTickAtRatio(ratio)
    // getRatioAtTick(tick) <= ratio < getRatioAtTick(tick + 1)
    function getTickAtRatio(uint256 ratio) external pure returns (int24 tick);
}
