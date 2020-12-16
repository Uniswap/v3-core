// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;
pragma abicoder v2;

import '../UniswapV3Pair.sol';

// used for testing time dependent behavior
contract MockTimeUniswapV3Pair is UniswapV3Pair {
    uint32 public time;

    constructor(
        address factory,
        address tokenA,
        address tokenB,
        uint24 fee,
        int24 tickSpacing
    ) UniswapV3Pair(factory, tokenA, tokenB, fee, tickSpacing) {}

    function setTime(uint32 _time) external {
        require(_time > time, 'MockTimeUniswapV3Pair::setTime: time can only be advanced');
        time = _time;
    }

    function _blockTimestamp() internal view override returns (uint32) {
        return time;
    }
}
