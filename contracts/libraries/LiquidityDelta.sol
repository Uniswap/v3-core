// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.0;

// applies liquidity deltas to liquidity
library LiquidityDelta {
    function add(uint128 liquidity, int128 delta) internal pure returns (uint128) {
        return delta < 0 ? liquidity - uint128(uint256(-int256(delta))) : liquidity + uint128(delta);
    }

    function sub(uint128 liquidity, int128 delta) internal pure returns (uint128) {
        return delta < 0 ? liquidity + uint128(uint256(-int256(delta))) : liquidity - uint128(delta);
    }
}
