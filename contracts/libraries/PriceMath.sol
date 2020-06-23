// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import '@uniswap/lib/contracts/libraries/FixedPoint.sol';

library PriceMath {
    uint public constant LP_FEE_BASE = 1000000; // 20 bits

    // given the reserve in and reserve out and LP fee and the desired ratio of in/out,
    // returns the amount in to swap to reach the inOutRatio.
    function getTradeToRatio(uint112 reserveIn, uint112 reserveOut, uint112 lpFee, FixedPoint.uq112x112 memory inOutRatio) internal pure returns (uint112 amountIn) {
        // 20 bits, no loss
        uint feeNumerator = (LP_FEE_BASE - lpFee);
        // 224 bits, no loss
        uint k = uint(reserveIn) * reserveOut;
        // sqrt(reserveIn * reserveOut * ratioInOut / (lpFee ^ 2))
        uint leftInner = k * (LP_FEE_BASE / feeNumerator) * (LP_FEE_BASE / feeNumerator);
        // reserveIn / lpFee
        uint right = uint(reserveIn) * LP_FEE_BASE / feeNumerator;
        require(right < uint112(- 1), 'RIGHT_TOO_LARGE');
        return uint112(Babylonian.sqrt(leftInner) + right);
    }
}
