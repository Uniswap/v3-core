// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import '@uniswap/lib/contracts/libraries/FixedPoint.sol';
import 'abdk-libraries-solidity/ABDKMathQuad.sol';

library PriceMath {
    using FixedPoint for FixedPoint.uq112x112;
    using ABDKMathQuad for bytes16;

    //    //ABDKMathQuad.fromUInt(1);
    //    bytes16 public constant QUAD_ONE = bytes16(0);
    //    //ABDKMathQuad.fromUInt(2);
    //    bytes16 public constant QUAD_TWO = bytes16(0);
    //    //ABDKMathQuad.fromUInt(4);
    //    bytes16 public constant QUAD_FOUR = bytes16(0);

    uint24 public constant LP_FEE_BASE = 1000000; // 1000000 pips, or 10000 bips, or 100%

    function toQuad(FixedPoint.uq112x112 memory self) private pure returns (bytes16) {
        return ABDKMathQuad.from128x128(int256(self._x) << 16);
    }

    function getTradeToRatioInner(bytes16 reserveIn, bytes16 reserveOut, bytes16 fee, bytes16 inOutRatio)
        private
        pure
        returns (bytes16)
    {
        // left =
        //	sqrt(
        //		(
        //			reserveIn
        //				*
        //			(fee ^ 2 * reserveIn - 4 * fee * inOutRatio * reserveOut + 4 * reserveInOut * reserveOut)
        //		)
        //			/
        //		((fee - 1) ^ 2)
        //	)
        bytes16 left = reserveIn.mul(
                fee.mul(fee).mul(reserveIn)
                .sub(ABDKMathQuad.fromUInt(4).mul(fee).mul(inOutRatio).mul(reserveOut))
                .add(ABDKMathQuad.fromUInt(4).mul(inOutRatio).mul(reserveOut))
            )
            .div(fee.sub(ABDKMathQuad.fromUInt(1)).mul(fee.sub(ABDKMathQuad.fromUInt(1))))
            .sqrt();
        // right =
        // (
        //		((fee - 2) * reserveIn)
        //			/
        //		(fee - 1)
        //	)
        bytes16 right = fee.sub(ABDKMathQuad.fromUInt(2)).mul(reserveIn).div(fee.sub(ABDKMathQuad.fromUInt(1)));

        return left.sub(right).div(ABDKMathQuad.fromUInt(2));
    }

    // given the reserve in and reserve out and LP fee and the desired price after the swap (i.e. inOutRatio),
    // returns the amount that must be swapped in
    // the equation is:
    // reserveInOut = target price in terms of reserveIn/reserveOut
    // reserveIn = original reserves of the amount being swapped in
    // reserveOut = original reserves of the amount being swapped out
    // amountIn = amount traded in, solve for this
    // fee = liquidity provider fee
    // (reserveIn + amountIn) /
    // ((reserveOut * reserveIn) / (reserveIn + amountIn * (1-lpFee))) = inOutRatio
    // the solution is found here
    // https://www.wolframalpha.com/input/?i=solve+%28x0+%2B+x%29+%2F+%28%28y0+*+x0%29+%2F+%28x0+%2B+x+*+%281-f%29%29%29+%3D+p+for+x+where+x+%3E+0+and+x0+%3E+0+and+y0+%3E+0+and+f+%3E+0+and+f+%3C+1+and+p+%3E+0
    // rewritten:
    // amountIn = (
    //	sqrt(
    //		(
    //			reserveIn
    //				*
    //			(fee ^ 2 * reserveIn - 4 * fee * inOutRatio * reserveOut + 4 * reserveInOut * reserveOut)
    //		)
    //			/
    //		((fee - 1) ^ 2)
    //	)
    //		-
    //	(
    //		((fee - 2) * reserveIn)
    //			/
    //		(fee - 1)
    //	)
    //) / 2
    function getTradeToRatio(
        uint112 reserveIn,
        uint112 reserveOut,
        uint16 lpFee,
        FixedPoint.uq112x112 memory inOutRatio
    )
        internal
        pure
        returns (uint112 amountIn)
    {
        require(reserveIn > 0 && reserveOut > 0, 'PriceMath: NONZERO');
        require(FixedPoint.fraction(reserveIn, reserveOut)._x <= inOutRatio._x, 'PriceMath: DIRECTION');
        bytes16 fee = ABDKMathQuad.div(ABDKMathQuad.fromUInt(lpFee), ABDKMathQuad.fromUInt(LP_FEE_BASE));
        bytes16 quadReserveIn = ABDKMathQuad.fromUInt(reserveIn);
        bytes16 quadReserveOut = ABDKMathQuad.fromUInt(reserveOut);
        bytes16 quadInOutRatio = toQuad(inOutRatio);

        uint result = ABDKMathQuad.toUInt(getTradeToRatioInner(quadReserveIn, quadReserveOut, fee, quadInOutRatio));
        require(result <= type(uint112).max, 'PriceMath: AMOUNT_OVERFLOW_UINT112');
        return uint112(result);
    }
}
