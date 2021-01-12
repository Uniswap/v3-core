// SPDX-License-Identifier: CC-BY-4.0
pragma solidity =0.7.6;

// taken from https://medium.com/coinmonks/math-in-solidity-part-3-percents-and-proportions-4db014e080b1
function fullMul(uint256 x, uint256 y) pure returns (uint256 l, uint256 h) {
    uint256 mm = mulmod(x, y, uint256(-1));
    l = x * y;
    h = mm - l;
    if (mm < l) h -= 1;
}
