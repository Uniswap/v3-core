// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

// the interface for a pluggable tick math implementation, e.g. for different tick sizes
interface ITickMath {
    // the minimum tick. must be less than max tick. the pair tick can never be less than this tick.
    function MIN_TICK() external view returns (int24);

    // the maximum tick. must be greater than min tick. the pair tick can never be equal to or greater than this tick.
    function MAX_TICK() external view returns (int24);

    // get the ratio from the tick as a fixed point 128x128 in a uint256 container
    // this function must be able to accept any integer between MIN_TICK and MAX_TICK, inclusive
    // must satisfy the following invariant for any tick gt MIN_TICK and lt MAX_TICK:
    // getRatioAtTick(tick - 1) < getRatioAtTick(tick) < getRatioAtTick(tick + 1)
    function getRatioAtTick(int24 tick) external pure returns (uint256 ratio);

    // get the tick from a ratio.
    // this function must be able to accept any ratio greater than or equal to getRatioAtTick(MIN_TICK),
    // and less than getRatioAtTick(MAX_TICK).
    // must satisfy the invariant for all inputs:
    // tick := getTickAtRatio(ratio)
    // getRatioAtTick(tick) <= ratio < getRatioAtTick(tick + 1)
    function getTickAtRatio(uint256 ratio) external pure returns (int24 tick);
}
