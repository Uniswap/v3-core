// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.7.6;
pragma abicoder v2;

import './../UniswapV3Pool.sol';
import './../interfaces/IERC20Minimal.sol';
import './../interfaces/callback/IUniswapV3SwapCallback.sol';

import './TickMath.sol';
import './Tick.sol';
import './TickBitmap.sol';
import './SwapMath.sol';
import './FullMath.sol';
import './Oracle.sol';
import './FixedPoint128.sol';
import './SafeCast.sol';
import './LowGasSafeMath.sol';

library StateMath {
    using SafeCast for uint256;
    using SafeCast for int256;
    using LowGasSafeMath for int256;
    using Oracle for Oracle.Observation[65535];
    using Tick for mapping(int24 => Tick.Info);
    using TickBitmap for mapping(int16 => uint256);

    struct Slot0 {
        // the current price
        uint160 sqrtPriceX96;
        // the current tick
        int24 tick;
        // the most-recently updated index of the observations array
        uint16 observationIndex;
        // the current maximum number of observations that are being stored
        uint16 observationCardinality;
        // the next maximum number of observations to store, triggered in observations.write
        uint16 observationCardinalityNext;
        // the current protocol fee as a percentage of the swap fee taken on withdrawal
        // represented as an integer denominator (1/x)%
        uint8 feeProtocol;
        // whether the pool is locked
        bool unlocked;
    }

    struct SwapArgs {
        SwapCache cache;
        uint24 fee;
        int24 tickSpacing;
        uint256 feeGrowthGlobal0X128;
        uint256 feeGrowthGlobal1X128;
        bool zeroForOne;
        int256 amountSpecified;
        uint160 sqrtPriceLimitX96;
    }

    function swap(
        SwapArgs memory args,
        Slot0 storage slot0,
        mapping(int24 => Tick.Info) storage ticks,
        Oracle.Observation[65535] storage observations,
        mapping(int16 => uint256) storage tickBitmap
    )
        public
        returns (
            SwapState memory state,
            SwapCache memory,
            bool
        )
    {
        Slot0 memory slot0Start = slot0;
        state = SwapState({
            amountSpecifiedRemaining: args.amountSpecified,
            amountCalculated: 0,
            sqrtPriceX96: slot0Start.sqrtPriceX96,
            tick: slot0Start.tick,
            feeGrowthGlobalX128: args.zeroForOne ? args.feeGrowthGlobal0X128 : args.feeGrowthGlobal1X128,
            protocolFee: 0,
            liquidity: args.cache.liquidityStart
        });

        // continue swapping as long as we haven't used the entire input/output and haven't reached the price limit
        while (state.amountSpecifiedRemaining != 0 && state.sqrtPriceX96 != args.sqrtPriceLimitX96) {
            StepComputations memory step = createStep(tickBitmap, state, args.zeroForOne, args.tickSpacing);

            // compute values to swap to the target tick, price limit, or point where input/output amount is exhausted
            (state.sqrtPriceX96, step.amountIn, step.amountOut, step.feeAmount) = SwapMath.computeSwapStep(
                state.sqrtPriceX96,
                (
                    args.zeroForOne
                        ? step.sqrtPriceNextX96 < args.sqrtPriceLimitX96
                        : step.sqrtPriceNextX96 > args.sqrtPriceLimitX96
                )
                    ? args.sqrtPriceLimitX96
                    : step.sqrtPriceNextX96,
                state.liquidity,
                state.amountSpecifiedRemaining,
                args.fee
            );

            // exact input
            if (args.amountSpecified > 0) {
                state.amountSpecifiedRemaining -= (step.amountIn + step.feeAmount).toInt256();
                state.amountCalculated = state.amountCalculated.sub(step.amountOut.toInt256());
            } else {
                state.amountSpecifiedRemaining += step.amountOut.toInt256();
                state.amountCalculated = state.amountCalculated.add((step.amountIn + step.feeAmount).toInt256());
            }

            // if the protocol fee is on, calculate how much is owed, decrement feeAmount, and increment protocolFee
            if (args.cache.feeProtocol > 0) {
                uint256 delta = step.feeAmount / args.cache.feeProtocol;
                step.feeAmount -= delta;
                state.protocolFee += uint128(delta);
            }

            // update global fee tracker
            if (state.liquidity > 0)
                state.feeGrowthGlobalX128 += FullMath.mulDiv(step.feeAmount, FixedPoint128.Q128, state.liquidity);

            // shift tick if we reached the next price
            state = shiftTick(slot0Start, state, step, args, ticks, observations);
        }

        // update tick and write an oracle entry if the tick change
        if (state.tick != slot0Start.tick) {
            SwapCache memory cache = args.cache;
            (slot0.observationIndex, slot0.observationCardinality) = observations.write(
                slot0Start.observationIndex,
                cache.blockTimestamp,
                slot0Start.tick,
                cache.liquidityStart,
                slot0Start.observationCardinality,
                slot0Start.observationCardinalityNext
            );
            slot0.sqrtPriceX96 = state.sqrtPriceX96;
            slot0.tick = state.tick;
        } else {
            // otherwise just update the price
            slot0.sqrtPriceX96 = state.sqrtPriceX96;
        }

        return (state, args.cache, args.amountSpecified > 0);
    }

    function shiftTick(
        Slot0 memory slot0Start,
        SwapState memory state,
        StepComputations memory step,
        SwapArgs memory args,
        mapping(int24 => Tick.Info) storage ticks,
        Oracle.Observation[65535] storage observations
    ) private returns (SwapState memory) {
        if (state.sqrtPriceX96 == step.sqrtPriceNextX96) {
            SwapCache memory cache = args.cache;
            // if the tick is initialized, run the tick transition
            if (step.initialized) {
                // check for the placeholder value, which we replace with the actual value the first time the swap
                // crosses an initialized tick
                if (!cache.computedLatestObservation) {
                    (cache.tickCumulative, cache.secondsPerLiquidityCumulativeX128) = observations.observeSingle(
                        cache.blockTimestamp,
                        0,
                        slot0Start.tick,
                        slot0Start.observationIndex,
                        cache.liquidityStart,
                        slot0Start.observationCardinality
                    );
                    cache.computedLatestObservation = true;
                }
                int128 liquidityNet =
                    ticks.cross(
                        step.tickNext,
                        (args.zeroForOne ? state.feeGrowthGlobalX128 : args.feeGrowthGlobal0X128),
                        (args.zeroForOne ? args.feeGrowthGlobal1X128 : state.feeGrowthGlobalX128),
                        cache.secondsPerLiquidityCumulativeX128,
                        cache.tickCumulative,
                        cache.blockTimestamp
                    );
                // if we're moving leftward, we interpret liquidityNet as the opposite sign
                // safe because liquidityNet cannot be type(int128).min
                if (args.zeroForOne) liquidityNet = -liquidityNet;

                state.liquidity = LiquidityMath.addDelta(state.liquidity, liquidityNet);
            }

            state.tick = args.zeroForOne ? step.tickNext - 1 : step.tickNext;
        } else if (state.sqrtPriceX96 != step.sqrtPriceStartX96) {
            // recompute unless we're on a lower tick boundary (i.e. already transitioned ticks), and haven't moved
            state.tick = TickMath.getTickAtSqrtRatio(state.sqrtPriceX96);
        }

        return state;
    }

    struct SwapCache {
        // the protocol fee for the input token
        uint8 feeProtocol;
        // liquidity at the beginning of the swap
        uint128 liquidityStart;
        // the timestamp of the current block
        uint32 blockTimestamp;
        // the current value of the tick accumulator, computed only if we cross an initialized tick
        int56 tickCumulative;
        // the current value of seconds per liquidity accumulator, computed only if we cross an initialized tick
        uint160 secondsPerLiquidityCumulativeX128;
        // whether we've computed and cached the above two accumulators
        bool computedLatestObservation;
    }

    // the top level state of the swap, the results of which are recorded in storage at the end
    struct SwapState {
        // the amount remaining to be swapped in/out of the input/output asset
        int256 amountSpecifiedRemaining;
        // the amount already swapped out/in of the output/input asset
        int256 amountCalculated;
        // current sqrt(price)
        uint160 sqrtPriceX96;
        // the tick associated with the current price
        int24 tick;
        // the global fee growth of the input token
        uint256 feeGrowthGlobalX128;
        // amount of input token paid as protocol fee
        uint128 protocolFee;
        // the current liquidity in range
        uint128 liquidity;
    }

    struct StepComputations {
        // the price at the beginning of the step
        uint160 sqrtPriceStartX96;
        // the next tick to swap to from the current tick in the swap direction
        int24 tickNext;
        // whether tickNext is initialized or not
        bool initialized;
        // sqrt(price) for the next tick (1/0)
        uint160 sqrtPriceNextX96;
        // how much is being swapped in in this step
        uint256 amountIn;
        // how much is being swapped out
        uint256 amountOut;
        // how much fee is being paid in
        uint256 feeAmount;
    }

    function createStep(
        mapping(int16 => uint256) storage tickBitmap,
        SwapState memory state,
        bool zeroForOne,
        int24 tickSpacing
    ) public view returns (StepComputations memory step) {
        step.sqrtPriceStartX96 = state.sqrtPriceX96;

        (step.tickNext, step.initialized) = tickBitmap.nextInitializedTickWithinOneWord(
            state.tick,
            tickSpacing,
            zeroForOne
        );

        // ensure that we do not overshoot the min/max tick, as the tick bitmap is not aware of these bounds
        if (step.tickNext < TickMath.MIN_TICK) {
            step.tickNext = TickMath.MIN_TICK;
        } else if (step.tickNext > TickMath.MAX_TICK) {
            step.tickNext = TickMath.MAX_TICK;
        }

        // get the price for the next tick
        step.sqrtPriceNextX96 = TickMath.getSqrtRatioAtTick(step.tickNext);
    }

    struct SnapshotArgs {
        Slot0 slot0;
        uint128 liquidity;
        uint32 time;
        int24 tickLower;
        int24 tickUpper;
    }

    function snapshotCumulativesInside(
        mapping(int24 => Tick.Info) storage ticks,
        Oracle.Observation[65535] storage observations,
        SnapshotArgs memory args
    )
        public
        view
        returns (
            int56,
            uint160,
            uint32
        )
    {
        int56 tickCumulativeLower;
        int56 tickCumulativeUpper;
        uint160 secondsPerLiquidityOutsideLowerX128;
        uint160 secondsPerLiquidityOutsideUpperX128;
        uint32 secondsOutsideLower;
        uint32 secondsOutsideUpper;

        {
            Tick.Info storage lower = ticks[args.tickLower];
            Tick.Info storage upper = ticks[args.tickUpper];
            bool initializedLower;
            (tickCumulativeLower, secondsPerLiquidityOutsideLowerX128, secondsOutsideLower, initializedLower) = (
                lower.tickCumulativeOutside,
                lower.secondsPerLiquidityOutsideX128,
                lower.secondsOutside,
                lower.initialized
            );
            require(initializedLower);

            bool initializedUpper;
            (tickCumulativeUpper, secondsPerLiquidityOutsideUpperX128, secondsOutsideUpper, initializedUpper) = (
                upper.tickCumulativeOutside,
                upper.secondsPerLiquidityOutsideX128,
                upper.secondsOutside,
                upper.initialized
            );
            require(initializedUpper);
        }

        if (args.slot0.tick < args.tickLower) {
            return (
                tickCumulativeLower - tickCumulativeUpper,
                secondsPerLiquidityOutsideLowerX128 - secondsPerLiquidityOutsideUpperX128,
                secondsOutsideLower - secondsOutsideUpper
            );
        } else if (args.slot0.tick < args.tickUpper) {
            ObsArgs memory args2 =
                ObsArgs(
                    tickCumulativeLower,
                    tickCumulativeUpper,
                    secondsPerLiquidityOutsideLowerX128,
                    secondsPerLiquidityOutsideUpperX128,
                    secondsOutsideLower,
                    secondsOutsideUpper
                );
            return observeTick(observations, args, args2);
        } else {
            return (
                tickCumulativeUpper - tickCumulativeLower,
                secondsPerLiquidityOutsideUpperX128 - secondsPerLiquidityOutsideLowerX128,
                secondsOutsideUpper - secondsOutsideLower
            );
        }
    }

    struct ObsArgs {
        int56 tickCumulativeLower;
        int56 tickCumulativeUpper;
        uint160 secondsPerLiquidityOutsideLowerX128;
        uint160 secondsPerLiquidityOutsideUpperX128;
        uint32 secondsOutsideLower;
        uint32 secondsOutsideUpper;
    }

    function observeTick(
        Oracle.Observation[65535] storage observations,
        SnapshotArgs memory args,
        ObsArgs memory args2
    )
        private
        view
        returns (
            int56,
            uint160,
            uint32
        )
    {
        (int56 tickCumulative, uint160 secondsPerLiquidityCumulativeX128) =
            observations.observeSingle(
                args.time,
                0,
                args.slot0.tick,
                args.slot0.observationIndex,
                args.liquidity,
                args.slot0.observationCardinality
            );

        return (
            tickCumulative - args2.tickCumulativeLower - args2.tickCumulativeUpper,
            secondsPerLiquidityCumulativeX128 -
                args2.secondsPerLiquidityOutsideLowerX128 -
                args2.secondsPerLiquidityOutsideUpperX128,
            args.time - args2.secondsOutsideLower - args2.secondsOutsideUpper
        );
    }
}
