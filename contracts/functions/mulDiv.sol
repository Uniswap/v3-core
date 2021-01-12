// SPDX-License-Identifier: CC-BY-4.0
pragma solidity =0.7.6;

import './fullMul.sol';

// taken from https://medium.com/coinmonks/math-in-solidity-part-3-percents-and-proportions-4db014e080b1
function mulDiv(
    uint256 x,
    uint256 y,
    uint256 d
) pure returns (uint256) {
    (uint256 l, uint256 h) = fullMul(x, y);
    require(h < d, 'FMD');

    uint256 mm = mulmod(x, y, d);
    if (mm > l) h -= 1;
    l -= mm;

    if (h == 0) return l / d;

    uint256 pow2 = d & -d;
    d /= pow2;
    l /= pow2;
    l += h * ((-pow2) / pow2 + 1);
    uint256 r = 1;
    r *= 2 - d * r;
    r *= 2 - d * r;
    r *= 2 - d * r;
    r *= 2 - d * r;
    r *= 2 - d * r;
    r *= 2 - d * r;
    r *= 2 - d * r;
    r *= 2 - d * r;
    return l * r;
}

function mulDivRoundUp(
    uint256 x,
    uint256 y,
    uint256 d
) pure returns (uint256) {
    return mulDiv(x, y, d) + (mulmod(x, y, d) > 0 ? 1 : 0);
}
