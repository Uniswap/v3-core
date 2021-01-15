// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

interface IUniswapV3PairDerivedState {
    function scry(uint32 secondsAgo) external view returns (int56 tickCumulative, uint160 liquidityCumulative);
}
