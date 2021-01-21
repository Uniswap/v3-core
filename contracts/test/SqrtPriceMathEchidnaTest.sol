// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import '../libraries/FullMath.sol';
import '../libraries/SqrtPriceMath.sol';

contract SqrtPriceMathEchidnaTest {
    function mulDivRoundingUpInvariants(
        uint256 x,
        uint256 y,
        uint256 z
    ) external pure {
        require(z > 0);
        uint256 notRoundedUp = FullMath.mulDiv(x, y, z);
        uint256 roundedUp = FullMath.mulDivRoundingUp(x, y, z);
        assert(roundedUp >= notRoundedUp);
        assert(roundedUp - notRoundedUp < 2);
        if (roundedUp - notRoundedUp == 1) {
            assert(mulmod(x, y, z) > 0);
        } else {
            assert(mulmod(x, y, z) == 0);
        }
    }

    function getNextSqrtPriceFromInputInvariants(
        uint160 sqrtP,
        uint128 liquidity,
        uint256 amountIn,
        bool zeroForOne
    ) external pure {
        uint160 sqrtQ = SqrtPriceMath.getNextSqrtPriceFromInput(sqrtP, liquidity, amountIn, zeroForOne);

        if (zeroForOne) {
            assert(sqrtQ <= sqrtP);
            assert(amountIn >= SqrtPriceMath.getAmount0Delta(sqrtP, sqrtQ, liquidity, true));
        } else {
            assert(sqrtQ >= sqrtP);
            assert(amountIn >= SqrtPriceMath.getAmount1Delta(sqrtP, sqrtQ, liquidity, true));
        }
    }

    function getNextSqrtPriceFromOutputInvariants(
        uint160 sqrtP,
        uint128 liquidity,
        uint256 amountOut,
        bool zeroForOne
    ) external pure {
        uint160 sqrtQ = SqrtPriceMath.getNextSqrtPriceFromOutput(sqrtP, liquidity, amountOut, zeroForOne);

        if (zeroForOne) {
            assert(sqrtQ <= sqrtP);
            assert(amountOut <= SqrtPriceMath.getAmount1Delta(sqrtQ, sqrtP, liquidity, true));
        } else {
            assert(sqrtQ >= sqrtP);
            assert(amountOut <= SqrtPriceMath.getAmount0Delta(sqrtQ, sqrtP, liquidity, true));
        }
    }

    function getAmount0DeltaInvariants(
        uint160 sqrtP,
        uint160 sqrtQ,
        uint128 liquidity
    ) external pure {
        require(sqrtP >= sqrtQ);
        require(sqrtP > 0 && sqrtQ > 0);
        uint256 amount0Down = SqrtPriceMath.getAmount0Delta(sqrtP, sqrtQ, liquidity, false);
        uint256 amount0Up = SqrtPriceMath.getAmount0Delta(sqrtP, sqrtQ, liquidity, true);
        assert(amount0Down <= amount0Up);
        // diff is 0 or 1
        assert(amount0Up - amount0Down < 2);
    }

    function getAmount1DeltaInvariants(
        uint160 sqrtP,
        uint160 sqrtQ,
        uint128 liquidity
    ) external pure {
        require(sqrtP <= sqrtQ);
        require(sqrtP > 0 && sqrtQ > 0);
        uint256 amount1Down = SqrtPriceMath.getAmount1Delta(sqrtP, sqrtQ, liquidity, false);
        uint256 amount1Up = SqrtPriceMath.getAmount1Delta(sqrtP, sqrtQ, liquidity, true);
        assert(amount1Down <= amount1Up);
        // diff is 0 or 1
        assert(amount1Up - amount1Down < 2);
    }

    function getAmount0DeltaSignedInvariants(
        uint160 sqrtP,
        uint160 sqrtQ,
        int128 liquidity
    ) external pure {
        require(sqrtP >= sqrtQ);
        require(sqrtP > 0 && sqrtQ > 0);

        int256 amount0 = SqrtPriceMath.getAmount0Delta(sqrtP, sqrtQ, liquidity);
        if (liquidity < 0) assert(amount0 <= 0);
        if (liquidity > 0) {
            if (sqrtP == sqrtQ) assert(amount0 == 0);
            else assert(amount0 > 0);
        }
        if (liquidity == 0) assert(amount0 == 0);
    }

    function getAmount1DeltaSignedInvariants(
        uint160 sqrtP,
        uint160 sqrtQ,
        int128 liquidity
    ) external pure {
        require(sqrtP <= sqrtQ);
        require(sqrtP > 0 && sqrtQ > 0);

        int256 amount1 = SqrtPriceMath.getAmount1Delta(sqrtP, sqrtQ, liquidity);
        if (liquidity < 0) assert(amount1 <= 0);
        if (liquidity > 0) {
            if (sqrtP == sqrtQ) assert(amount1 == 0);
            else assert(amount1 > 0);
        }
        if (liquidity == 0) assert(amount1 == 0);
    }
}
