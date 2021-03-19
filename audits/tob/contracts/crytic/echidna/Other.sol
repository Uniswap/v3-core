pragma solidity =0.7.6;

import '../../../../../contracts/libraries/SqrtPriceMath.sol';
import '../../../../../contracts/libraries/TickMath.sol';

contract Other {
    // prop #30
    function test_getNextSqrtPriceFromInAndOutput(
        uint160 sqrtPX96,
        uint128 liquidity,
        uint256 amount,
        bool add
    ) public {
        require(sqrtPX96 >= TickMath.MIN_SQRT_RATIO && sqrtPX96 < TickMath.MAX_SQRT_RATIO);
        require(liquidity < 3121856577256316178563069792952001939); // max liquidity per tick
        uint256 next_sqrt = SqrtPriceMath.getNextSqrtPriceFromInput(sqrtPX96, liquidity, amount, add);
        assert(next_sqrt >= TickMath.MIN_SQRT_RATIO && next_sqrt < TickMath.MAX_SQRT_RATIO);
        next_sqrt = SqrtPriceMath.getNextSqrtPriceFromOutput(sqrtPX96, liquidity, amount, add);
        assert(next_sqrt >= TickMath.MIN_SQRT_RATIO && next_sqrt < TickMath.MAX_SQRT_RATIO);
    }
}
