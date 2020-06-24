// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import '@uniswap/lib/contracts/libraries/FixedPoint.sol';
import 'abdk-libraries-solidity/ABDKMathQuad.sol';
import './FixedPointExtra.sol';

library PriceMath {
    uint public constant LP_FEE_BASE = 1000000; // 20 bits
    // given the reserve in and reserve out and LP fee and the desired ratio of in/out after the swap,
    // excluding the accumulated fee, returns the amount in to swap
    // the equation is:
    // (reserveIn + amountIn * (1-lpFee)) / ((reserveIn * reserveOut) / (reserveIn + amountIn * (1-lpFee))) = reserveInOutAfter
    // solve for amountIn where reserveIn, reserveOut, lpFee, inOutRatio, amountIn are all > 0
    function getTradeToRatio(uint112 reserveIn, uint112 reserveOut, uint112 lpFee, FixedPoint.uq112x112 memory inOutRatio) internal pure returns (uint112 amountIn) {
        bytes16 fee = ABDKMathQuad.div(ABDKMathQuad.fromUInt(LP_FEE_BASE - lpFee), ABDKMathQuad.fromUInt(LP_FEE_BASE));

        // 224 bits, never overflows
        uint k = uint(reserveIn) * reserveOut;

        // left = sqrt(reserveIn * reserveOut * ratioInOut / (lpFee ^ 2))
        bytes16 left = ABDKMathQuad.sqrt(
            ABDKMathQuad.div(
                ABDKMathQuad.mul(FixedPointExtra.toQuad(inOutRatio), ABDKMathQuad.fromUInt(k)),
                ABDKMathQuad.mul(fee, fee)
            )
        );

        // right = reserveIn / lpFee
        bytes16 right = ABDKMathQuad.div(ABDKMathQuad.fromUInt(reserveIn), fee);

        uint result = ABDKMathQuad.toUInt(ABDKMathQuad.sub(left, right));
        require(result <= type(uint112).max, 'PriceMath: AMOUNT_OVERFLOW_UINT112');
        return uint112(result);
    }
}
