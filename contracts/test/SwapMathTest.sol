// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import '../libraries/SwapMath.sol';

contract SwapMathTest {

    // Remove everything between these two lines once bug is fixed
    using SafeCast for uint256;
    using LowGasSafeMath for uint256;
    using UnsafeMath for uint256;

    function avoidBugs() external pure {
        uint256 x;
        uint256 y;

        x.toUint160();
        x.add(y);
        x.divRoundingUp(y);
    }
    // 

    function computeSwapStep(
        uint160 sqrtP,
        uint160 sqrtPTarget,
        uint128 liquidity,
        int256 amountRemaining,
        uint24 feePips
    )
        external
        pure
        returns (
            uint160 sqrtQ,
            uint256 amountIn,
            uint256 amountOut,
            uint256 feeAmount
        )
    {
        return SwapMath.computeSwapStep(sqrtP, sqrtPTarget, liquidity, amountRemaining, feePips);
    }

    // function getGasCostOfComputeSwapStep(
    //     uint160 sqrtP,
    //     uint160 sqrtPTarget,
    //     uint128 liquidity,
    //     int256 amountRemaining,
    //     uint24 feePips
    // ) external view returns (uint256) {
    //     uint256 gasBefore = gasleft();
    //     SwapMath.computeSwapStep(sqrtP, sqrtPTarget, liquidity, amountRemaining, feePips);
    //     return gasBefore - gasleft();
    // }
}
