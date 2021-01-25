// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

interface IUniswapV3PairDerivedState {
    // returns the seconds inside a tick range. both ticks must be initialized, and this value is only relative.
    function secondsInside(int24 tickLower, int24 tickUpper) external view returns (uint32);

    function scry(uint32 secondsAgo) external view returns (int56 tickCumulative, uint160 liquidityCumulative);
}
