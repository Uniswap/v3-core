// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import '@uniswap/lib/contracts/libraries/FullMath.sol';

import '../libraries/FixedPoint96.sol';
import '../libraries/SqrtPriceMath.sol';

contract SqrtPriceMathEchidnaTest {
    function mulDivRoundingUpInvariants(
        uint256 x,
        uint256 y,
        uint256 z
    ) external pure {
        require(z > 0);
        uint256 notRoundedUp = FullMath.mulDiv(x, y, z);
        uint256 roundedUp = SqrtPriceMath.mulDivRoundingUp(x, y, z);
        assert(roundedUp >= notRoundedUp);
        assert(roundedUp - notRoundedUp < 2);
        if (roundedUp - notRoundedUp == 1) {
            assert(mulmod(x, y, z) > 0);
        } else {
            assert(mulmod(x, y, z) == 0);
        }
    }

    function getNextPriceFromInputInvariants(
        uint160 sqrtP,
        uint128 liquidity,
        uint256 amountIn,
        bool zeroForOne
    ) external pure {
        FixedPoint96.uq64x96 memory sqrtQ = SqrtPriceMath.getNextPriceFromInput(
            FixedPoint96.uq64x96(sqrtP),
            liquidity,
            amountIn,
            zeroForOne
        );

        if (zeroForOne) {
            assert(sqrtQ._x <= sqrtP);
            assert(amountIn >= SqrtPriceMath.getAmount0Delta(FixedPoint96.uq64x96(sqrtP), sqrtQ, liquidity, true));
        } else {
            assert(sqrtQ._x >= sqrtP);
            assert(amountIn >= SqrtPriceMath.getAmount1Delta(FixedPoint96.uq64x96(sqrtP), sqrtQ, liquidity, true));
        }
    }

    function getNextPriceFromOutputInvariants(
        uint160 sqrtP,
        uint128 liquidity,
        uint256 amountOut,
        bool zeroForOne
    ) external pure {
        FixedPoint96.uq64x96 memory sqrtQ = SqrtPriceMath.getNextPriceFromOutput(
            FixedPoint96.uq64x96(sqrtP),
            liquidity,
            amountOut,
            zeroForOne
        );

        if (zeroForOne) {
            assert(sqrtQ._x <= sqrtP);
            assert(amountOut <= SqrtPriceMath.getAmount1Delta(sqrtQ, FixedPoint96.uq64x96(sqrtP), liquidity, true));
        } else {
            assert(sqrtQ._x >= sqrtP);
            assert(amountOut <= SqrtPriceMath.getAmount0Delta(sqrtQ, FixedPoint96.uq64x96(sqrtP), liquidity, true));
        }
    }

    function getAmount0DeltaInvariants(
        uint160 sqrtP,
        uint160 sqrtQ,
        uint128 liquidity
    ) external pure {
        require(sqrtP >= sqrtQ);
        require(sqrtP > 0 && sqrtQ > 0);
        uint256 amount0Down = SqrtPriceMath.getAmount0Delta(
            FixedPoint96.uq64x96(sqrtP),
            FixedPoint96.uq64x96(sqrtQ),
            liquidity,
            false
        );
        uint256 amount0Up = SqrtPriceMath.getAmount0Delta(
            FixedPoint96.uq64x96(sqrtP),
            FixedPoint96.uq64x96(sqrtQ),
            liquidity,
            true
        );
        assert(amount0Down <= amount0Up);
        // diff is no greater than 2
        assert(amount0Up - amount0Down < 2);
    }

    function getAmount1DeltaInvariants(
        uint160 sqrtP,
        uint160 sqrtQ,
        uint128 liquidity
    ) external pure {
        require(sqrtP <= sqrtQ);
        require(sqrtP > 0 && sqrtQ > 0);
        uint256 amount1Down = SqrtPriceMath.getAmount1Delta(
            FixedPoint96.uq64x96(sqrtP),
            FixedPoint96.uq64x96(sqrtQ),
            liquidity,
            false
        );
        uint256 amount1Up = SqrtPriceMath.getAmount1Delta(
            FixedPoint96.uq64x96(sqrtP),
            FixedPoint96.uq64x96(sqrtQ),
            liquidity,
            true
        );
        assert(amount1Down <= amount1Up);
        // diff is no greater than 2
        assert(amount1Up - amount1Down < 2);
    }
}
