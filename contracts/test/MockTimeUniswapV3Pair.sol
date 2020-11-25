// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.12;
pragma experimental ABIEncoderV2;

import '../UniswapV3Pair.sol';

// used for testing time dependent behavior
contract MockTimeUniswapV3Pair is UniswapV3Pair {
    uint64 public time;

    constructor(
        address factory,
        address tokenA,
        address tokenB,
        uint8 feeOption
    ) public UniswapV3Pair(factory, tokenA, tokenB, feeOption) {}

    function setTime(uint64 _time) external {
        time = _time;
    }

    function _blockTimestamp() internal view override returns (uint64) {
        return time;
    }
}
