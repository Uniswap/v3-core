// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

function divRoundUp(uint256 x, uint256 d) pure returns (uint256) {
    // addition is safe because (uint256(-1) / 1) + (uint256(-1) % 1 > 0 ? 1 : 0) == uint256(-1)
    return (x / d) + (x % d > 0 ? 1 : 0);
}
