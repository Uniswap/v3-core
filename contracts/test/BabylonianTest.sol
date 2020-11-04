// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.12;

import '@uniswap/lib/contracts/libraries/Babylonian.sol';

contract BabylonianTest {
    function sqrt(uint112 a, uint112 b) public pure returns (uint112) {
        return uint112(Babylonian.sqrt(uint256(a) * b));
    }
}
