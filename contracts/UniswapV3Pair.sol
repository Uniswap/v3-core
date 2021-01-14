// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;
pragma abicoder v2;

import './libraries/FullMath.sol';
import './libraries/TransferHelper.sol';

import './libraries/SafeMath.sol';
import './libraries/SignedSafeMath.sol';

import './libraries/SafeCast.sol';
import './libraries/MixedSafeMath.sol';
import './libraries/SqrtPriceMath.sol';
import './libraries/SwapMath.sol';
import './libraries/SqrtTickMath.sol';
import './libraries/SpacedTickBitmap.sol';
import './libraries/FixedPoint128.sol';
import './libraries/Tick.sol';
import './libraries/Position.sol';
import './libraries/Oracle.sol';

import './interfaces/IERC20.sol';
import './interfaces/IUniswapV3Pair.sol';
import './interfaces/IUniswapV3PairDeployer.sol';
import './interfaces/IUniswapV3Factory.sol';
import './interfaces/IUniswapV3MintCallback.sol';
import './interfaces/IUniswapV3SwapCallback.sol';

contract UniswapV3Pair is IUniswapV3Pair {
    using SafeMath for uint256;
    using SignedSafeMath for int256;
    using SafeCast for uint256;
    using MixedSafeMath for uint128;
    using SpacedTickBitmap for mapping(int16 => uint256);
    using Tick for mapping(int24 => Tick.Info);
    using Position for mapping(bytes32 => Position.Info);
    using Oracle for Oracle.Observation[1024]; // 1024 over Oracle.CARDINALITY is a hack to satisfy solidity

    address public immutable override factory;
    address public immutable override token0;
    address public immutable override token1;
    uint24 public immutable override fee;

    // how far apart initialized ticks must be
    // e.g. a tickSpacing of 3 means ticks can be initialized every 3rd tick, i.e. ..., -6, -3, 0, 3, 6, ...
    // int24 to avoid casting even though it's always positive
    int24 public immutable override tickSpacing;

    // the minimum and maximum tick for the pair
    // always a multiple of tickSpacing
    int24 public immutable override minTick;
    int24 public immutable override maxTick;

    // the maximum amount of liquidity that can use any individual tick
    uint128 public immutable override maxLiquidityPerTick;

    struct Slot0 {
        // the current price
        uint160 sqrtPriceX96;
        // the current tick
        int24 tick;
        // the most-recently updated index of the observations array
        uint16 observationIndex;
        // the current protocol fee as a percentage of total fees, represented as an integer denominator (1/x)%
        uint8 feeProtocol;
        // whether the pair is locked
        bool unlocked;
    }

    Slot0 public override slot0;

    // the current liquidity
    uint128 public override liquidity;

    // see Oracle.sol
    Oracle.Observation[1024] public override observations; // 1024 over Oracle.CARDINALITY is a hack to satisfy solidity

    // see TickBitmap.sol
    mapping(int16 => uint256) public override tickBitmap;

    // fee growth per unit of liquidity
    uint256 public override feeGrowthGlobal0X128;
    uint256 public override feeGrowthGlobal1X128;

    // accumulated protocol fees in token0/token1 units
    uint256 public override protocolFees0;
    uint256 public override protocolFees1;

    mapping(int24 => Tick.Info) public ticks;
    mapping(bytes32 => Position.Info) public positions;

    modifier lock() {
        require(slot0.unlocked, 'LOK');
        slot0.unlocked = false;
        _;
        slot0.unlocked = true;
    }

    modifier onlyFactoryOwner() {
        require(msg.sender == IUniswapV3Factory(factory).owner(), 'OO');
        _;
    }

    constructor() {
        (address _factory, address _token0, address _token1, uint24 _fee, int24 _tickSpacing) =
            IUniswapV3PairDeployer(msg.sender).parameters();
        factory = _factory;
        token0 = _token0;
        token1 = _token1;
        fee = _fee;
        tickSpacing = _tickSpacing;

        (minTick, maxTick, maxLiquidityPerTick) = Tick.tickSpacingToParameters(_tickSpacing);
    }

    function balance0() private view returns (uint256) {
        return balanceOfToken(token0);
    }

    function balance1() private view returns (uint256) {
        return balanceOfToken(token1);
    }

    function balanceOfToken(address token) private view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    // returns the block timestamp % 2**32
    // overridden for tests
    function _blockTimestamp() internal view virtual returns (uint32) {
        return uint32(block.timestamp); // truncation is desired
    }

    // constructs an exact observation as of a particular time in the past, as long as we have observations before then
    function scry(uint32 secondsAgo)
        external
        view
        override
        returns (int56 tickCumulative, uint160 liquidityCumulative)
    {
        uint32 current = _blockTimestamp();
        uint32 target = current - secondsAgo;

        (Oracle.Observation memory before, Oracle.Observation memory atOrAfter) =
            getSurroundingObservations(current, target);

        Oracle.Observation memory at;
        if (target == atOrAfter.blockTimestamp) {
            // if we're at the right boundary, make it so
            at = atOrAfter;
        } else {
            // else, adjust counterfactually
            uint32 delta = atOrAfter.blockTimestamp - before.blockTimestamp;
            int24 tickDerived = int24((atOrAfter.tickCumulative - before.tickCumulative) / delta);
            uint128 liquidityDerived = uint128((atOrAfter.liquidityCumulative - before.liquidityCumulative) / delta);
            at = Oracle.transform(before, target, tickDerived, liquidityDerived);
        }

        return (at.tickCumulative, at.liquidityCumulative);
    }

    // fetches the observations before and atOrAfter a target, i.e. where this range is satisfied: (before, atOrAfter]
    function getSurroundingObservations(uint32 current, uint32 target)
        private
        view
        returns (Oracle.Observation memory before, Oracle.Observation memory)
    {
        uint16 index = slot0.observationIndex;

        // first, set before to the oldest observation, and make sure it's initialized
        before = observations[(index + 1) % Oracle.CARDINALITY];
        if (!before.initialized) {
            before = observations[0];
            require(before.initialized, 'UI');
        }

        // ensure that the target is greater than the oldest observation (accounting for wrapping)
        require(before.blockTimestamp < target || (before.blockTimestamp > current && target <= current), 'OLD');

        // now, optimistically set before to the newest observation
        before = observations[index];

        // before proceeding, short-circuit if the target equals the newest observation, meaning we're in the same block
        // but an interaction updated the oracle before this tx, so before is actually atOrAfter
        if (target == before.blockTimestamp)
            return (index == 0 ? observations[Oracle.CARDINALITY - 1] : observations[index - 1], before);

        // adjust for overflow
        uint256 beforeAdjusted = before.blockTimestamp;
        uint256 targetAdjusted = target;
        if (beforeAdjusted > current && targetAdjusted <= current) targetAdjusted += 2**32;
        if (targetAdjusted > current) beforeAdjusted += 2**32;

        // once here, check if we're right and return a counterfactual observation for atOrAfter
        if (beforeAdjusted < targetAdjusted) return (before, Oracle.transform(before, current, slot0.tick, liquidity));

        // we're wrong, so perform binary search
        return observations.binarySearch(target, index);
    }

    function checkTicks(int24 tickLower, int24 tickUpper) private view {
        require(tickLower < tickUpper, 'TLU');
        require(tickLower >= minTick, 'TLM');
        require(tickUpper <= maxTick, 'TUM');
    }

    function setFeeProtocol(uint8 feeProtocol) external override onlyFactoryOwner {
        require(feeProtocol == 0 || (feeProtocol <= 10 && feeProtocol >= 4), 'FP');
        emit FeeProtocolChanged(slot0.feeProtocol, feeProtocol);
        slot0.feeProtocol = feeProtocol;
    }

    function initialize(uint160 sqrtPriceX96) external override {
        require(slot0.sqrtPriceX96 == 0, 'AI');

        int24 tick = SqrtTickMath.getTickAtSqrtRatio(sqrtPriceX96);
        require(tick >= minTick, 'MIN');
        require(tick < maxTick, 'MAX');

        Slot0 memory _slot0 =
            Slot0({sqrtPriceX96: sqrtPriceX96, tick: tick, observationIndex: 0, feeProtocol: 0, unlocked: true});

        observations[_slot0.observationIndex] = Oracle.Observation({
            blockTimestamp: _blockTimestamp(),
            tickCumulative: 0,
            liquidityCumulative: 0,
            initialized: true
        });

        slot0 = _slot0;

        emit Initialized(sqrtPriceX96, tick);
    }

    // gets and updates and gets a position with the given liquidity delta
    function _updatePosition(
        address owner,
        int24 tickLower,
        int24 tickUpper,
        int128 liquidityDelta,
        int24 tick
    ) private {
        Position.Info storage position = positions.getPosition(owner, tickLower, tickUpper);

        if (liquidityDelta < 0) {
            require(position.liquidity >= uint128(-liquidityDelta), 'CP');
        } else if (liquidityDelta == 0) {
            require(position.liquidity > 0, 'NP'); // disallow updates for 0 liquidity positions
        }

        uint256 _feeGrowthGlobal0X128 = feeGrowthGlobal0X128; // SLOAD for gas optimization
        uint256 _feeGrowthGlobal1X128 = feeGrowthGlobal1X128; // SLOAD for gas optimization
        uint32 blockTimestamp = _blockTimestamp();

        bool flippedLower =
            ticks.update(
                tickLower,
                tick,
                liquidityDelta,
                _feeGrowthGlobal0X128,
                _feeGrowthGlobal1X128,
                blockTimestamp,
                false,
                maxLiquidityPerTick
            );
        if (flippedLower) tickBitmap.flipTick(tickLower, tickSpacing);
        bool flippedUpper =
            ticks.update(
                tickUpper,
                tick,
                liquidityDelta,
                _feeGrowthGlobal0X128,
                _feeGrowthGlobal1X128,
                blockTimestamp,
                true,
                maxLiquidityPerTick
            );
        if (flippedUpper) tickBitmap.flipTick(tickUpper, tickSpacing);

        (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) =
            ticks.getFeeGrowthInside(tickLower, tickUpper, tick, _feeGrowthGlobal0X128, _feeGrowthGlobal1X128);

        // calculate accumulated fees
        uint256 feesOwed0 =
            FullMath.mulDiv(
                feeGrowthInside0X128 - position.feeGrowthInside0LastX128,
                position.liquidity,
                FixedPoint128.Q128
            );
        uint256 feesOwed1 =
            FullMath.mulDiv(
                feeGrowthInside1X128 - position.feeGrowthInside1LastX128,
                position.liquidity,
                FixedPoint128.Q128
            );

        // collect protocol fee
        uint8 feeProtocol = slot0.feeProtocol;
        if (feeProtocol > 0) {
            uint256 fee0 = feesOwed0 / feeProtocol;
            feesOwed0 -= fee0;
            protocolFees0 += fee0;

            uint256 fee1 = feesOwed1 / feeProtocol;
            feesOwed1 -= fee1;
            protocolFees1 += fee1;
        }

        // update the position
        position.liquidity = uint128(position.liquidity.addi(liquidityDelta));
        position.feeGrowthInside0LastX128 = feeGrowthInside0X128;
        position.feeGrowthInside1LastX128 = feeGrowthInside1X128;
        position.feesOwed0 += feesOwed0;
        position.feesOwed1 += feesOwed1;

        // clear any tick or position data that is no longer needed
        if (liquidityDelta < 0) {
            if (flippedLower) ticks.clear(tickLower);
            if (flippedUpper) ticks.clear(tickUpper);
            if (position.liquidity == 0) {
                delete position.feeGrowthInside0LastX128;
                delete position.feeGrowthInside1LastX128;
            }
        }
    }

    function collect(
        int24 tickLower,
        int24 tickUpper,
        address recipient,
        uint256 amount0Requested,
        uint256 amount1Requested
    ) external override lock returns (uint256 amount0, uint256 amount1) {
        checkTicks(tickLower, tickUpper);

        Position.Info storage position = positions.getPosition(msg.sender, tickLower, tickUpper);

        amount0 = amount0Requested > position.feesOwed0 ? position.feesOwed0 : amount0Requested;
        amount1 = amount1Requested > position.feesOwed1 ? position.feesOwed1 : amount1Requested;

        if (amount0 > 0) {
            position.feesOwed0 -= amount0;
            TransferHelper.safeTransfer(token0, recipient, amount0);
        }
        if (amount1 > 0) {
            position.feesOwed1 -= amount1;
            TransferHelper.safeTransfer(token1, recipient, amount1);
        }

        emit Collect(msg.sender, tickLower, tickUpper, recipient, amount0, amount1);
    }

    function mint(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount,
        bytes calldata data
    ) public override lock {
        require(amount < 2**127, 'MA');

        (int256 amount0Int, int256 amount1Int) =
            _setPosition(
                SetPositionParams({
                    owner: recipient,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    liquidityDelta: int128(amount)
                })
            );

        uint256 amount0 = uint256(amount0Int);
        uint256 amount1 = uint256(amount1Int);

        if (amount0 > 0 || amount1 > 0) {
            uint256 balance0Before;
            uint256 balance1Before;
            if (amount0 > 0) balance0Before = balance0();
            if (amount1 > 0) balance1Before = balance1();
            IUniswapV3MintCallback(msg.sender).uniswapV3MintCallback(amount0, amount1, data);
            if (amount0 > 0) require(balance0Before.add(amount0) <= balance0(), 'M0');
            if (amount1 > 0) require(balance1Before.add(amount1) <= balance1(), 'M1');
        }

        emit Mint(recipient, tickLower, tickUpper, msg.sender, amount, amount0, amount1);
    }

    function burn(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount
    ) external override lock returns (uint256 amount0, uint256 amount1) {
        require(amount > 0 && amount < 2**127, 'BA');

        (int256 amount0Int, int256 amount1Int) =
            _setPosition(
                SetPositionParams({
                    owner: msg.sender,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    liquidityDelta: -int128(amount)
                })
            );

        amount0 = uint256(-amount0Int);
        amount1 = uint256(-amount1Int);

        if (amount0 > 0) TransferHelper.safeTransfer(token0, recipient, amount0);
        if (amount1 > 0) TransferHelper.safeTransfer(token1, recipient, amount1);

        emit Burn(msg.sender, tickLower, tickUpper, recipient, amount, amount0, amount1);
    }

    struct SetPositionParams {
        // the address that owns the position
        address owner;
        // the lower and upper tick of the position
        int24 tickLower;
        int24 tickUpper;
        // any change in liquidity
        int128 liquidityDelta;
    }

    // effect some changes to a position
    function _setPosition(SetPositionParams memory params) private returns (int256 amount0, int256 amount1) {
        checkTicks(params.tickLower, params.tickUpper);

        Slot0 memory _slot0 = slot0; // SLOAD for gas optimization

        _updatePosition(params.owner, params.tickLower, params.tickUpper, params.liquidityDelta, _slot0.tick);

        if (params.liquidityDelta != 0) {
            if (_slot0.tick < params.tickLower) {
                // current tick is below the passed range; liquidity can only become in range by crossing from left to
                // right, when we'll need _more_ token0 (it's becoming more valuable) so user must provide it
                amount0 = SqrtPriceMath.getAmount0Delta(
                    SqrtTickMath.getSqrtRatioAtTick(params.tickUpper),
                    SqrtTickMath.getSqrtRatioAtTick(params.tickLower),
                    params.liquidityDelta
                );
            } else if (_slot0.tick < params.tickUpper) {
                // current tick is inside the passed range
                uint128 liquidityBefore = liquidity; // SLOAD for gas optimization

                // write an oracle entry
                slot0.observationIndex = observations.write(
                    _slot0.observationIndex,
                    _blockTimestamp(),
                    _slot0.tick,
                    liquidityBefore
                );

                amount0 = SqrtPriceMath.getAmount0Delta(
                    SqrtTickMath.getSqrtRatioAtTick(params.tickUpper),
                    _slot0.sqrtPriceX96,
                    params.liquidityDelta
                );
                amount1 = SqrtPriceMath.getAmount1Delta(
                    SqrtTickMath.getSqrtRatioAtTick(params.tickLower),
                    _slot0.sqrtPriceX96,
                    params.liquidityDelta
                );

                // downcasting is safe because of gross liquidity checks
                liquidity = uint128(liquidityBefore.addi(params.liquidityDelta));
            } else {
                // current tick is above the passed range; liquidity can only become in range by crossing from right to
                // left, when we'll need _more_ token1 (it's becoming more valuable) so user must provide it
                amount1 = SqrtPriceMath.getAmount1Delta(
                    SqrtTickMath.getSqrtRatioAtTick(params.tickLower),
                    SqrtTickMath.getSqrtRatioAtTick(params.tickUpper),
                    params.liquidityDelta
                );
            }
        }
    }

    struct SwapCache {
        // the value of slot0 at the beginning of the swap
        Slot0 slot0Start;
        // liquidity at the beginning of the swap
        uint128 liquidityStart;
        // the timestamp of the current block
        uint32 blockTimestamp;
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

    // positive (negative) numbers specify exact input (output) amounts
    function swap(
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        address recipient,
        bytes calldata data
    ) external override {
        require(amountSpecified != 0, 'AS');

        Slot0 memory _slot0 = slot0;

        require(_slot0.unlocked, 'LOK');
        require(zeroForOne ? sqrtPriceLimitX96 < _slot0.sqrtPriceX96 : sqrtPriceLimitX96 > _slot0.sqrtPriceX96, 'SPL');

        slot0.unlocked = false;

        SwapCache memory cache =
            SwapCache({slot0Start: _slot0, liquidityStart: liquidity, blockTimestamp: _blockTimestamp()});

        bool exactInput = amountSpecified > 0;

        SwapState memory state =
            SwapState({
                amountSpecifiedRemaining: amountSpecified,
                amountCalculated: 0,
                sqrtPriceX96: cache.slot0Start.sqrtPriceX96,
                tick: cache.slot0Start.tick,
                feeGrowthGlobalX128: zeroForOne ? feeGrowthGlobal0X128 : feeGrowthGlobal1X128,
                liquidity: cache.liquidityStart
            });

        // continue swapping as long as we haven't used the entire input/output and haven't reached the price limit
        while (state.amountSpecifiedRemaining != 0 && state.sqrtPriceX96 != sqrtPriceLimitX96) {
            StepComputations memory step;

            step.sqrtPriceStartX96 = state.sqrtPriceX96;

            (step.tickNext, step.initialized) = tickBitmap.nextInitializedTickWithinOneWord(
                state.tick,
                tickSpacing,
                zeroForOne
            );

            // get the price for the next tick
            step.sqrtPriceNextX96 = SqrtTickMath.getSqrtRatioAtTick(step.tickNext);

            (state.sqrtPriceX96, step.amountIn, step.amountOut, step.feeAmount) = SwapMath.computeSwapStep(
                state.sqrtPriceX96,
                (zeroForOne ? step.sqrtPriceNextX96 < sqrtPriceLimitX96 : step.sqrtPriceNextX96 > sqrtPriceLimitX96)
                    ? sqrtPriceLimitX96
                    : step.sqrtPriceNextX96,
                state.liquidity,
                state.amountSpecifiedRemaining,
                fee
            );

            if (exactInput) {
                state.amountSpecifiedRemaining -= (step.amountIn + step.feeAmount).toInt256();
                state.amountCalculated = state.amountCalculated.sub(step.amountOut.toInt256());
            } else {
                state.amountSpecifiedRemaining += step.amountOut.toInt256();
                state.amountCalculated = state.amountCalculated.add((step.amountIn + step.feeAmount).toInt256());
            }

            // update global fee tracker
            if (state.liquidity > 0)
                state.feeGrowthGlobalX128 += FullMath.mulDiv(step.feeAmount, FixedPoint128.Q128, state.liquidity);

            // shift tick if we reached the next price target
            if (state.sqrtPriceX96 == step.sqrtPriceNextX96) {
                require(zeroForOne ? step.tickNext > minTick : step.tickNext < maxTick, 'TN');

                // if the tick is initialized, run the tick transition
                if (step.initialized) {
                    int128 liquidityDelta =
                        ticks.cross(
                            step.tickNext,
                            (zeroForOne ? state.feeGrowthGlobalX128 : feeGrowthGlobal0X128),
                            (zeroForOne ? feeGrowthGlobal1X128 : state.feeGrowthGlobalX128),
                            cache.blockTimestamp
                        );

                    // update liquidity, subi from right to left, addi from left to right
                    zeroForOne
                        ? state.liquidity = uint128(state.liquidity.subi(liquidityDelta))
                        : state.liquidity = uint128(state.liquidity.addi(liquidityDelta));
                }

                state.tick = zeroForOne ? step.tickNext - 1 : step.tickNext;
            } else {
                // recompute unless we're on a lower tick boundary (i.e. already transitioned ticks), but haven't moved
                if (state.sqrtPriceX96 != step.sqrtPriceStartX96)
                    state.tick = SqrtTickMath.getTickAtSqrtRatio(state.sqrtPriceX96);
            }
        }

        // update liquidity if it changed
        if (cache.liquidityStart != state.liquidity) liquidity = state.liquidity;

        if (state.tick != cache.slot0Start.tick) {
            slot0.tick = state.tick;
            // write an oracle entry if the price moved at least one tick
            slot0.observationIndex = observations.write(
                cache.slot0Start.observationIndex,
                cache.blockTimestamp,
                cache.slot0Start.tick,
                cache.liquidityStart
            );
        }

        slot0.sqrtPriceX96 = state.sqrtPriceX96;

        zeroForOne ? feeGrowthGlobal0X128 = state.feeGrowthGlobalX128 : feeGrowthGlobal1X128 = state
            .feeGrowthGlobalX128;

        // amountIn is always >0, amountOut is always <=0
        (int256 amountIn, int256 amountOut) =
            exactInput
                ? (amountSpecified - state.amountSpecifiedRemaining, state.amountCalculated)
                : (state.amountCalculated, amountSpecified - state.amountSpecifiedRemaining);

        (address tokenIn, address tokenOut) = zeroForOne ? (token0, token1) : (token1, token0);

        // transfer the output
        TransferHelper.safeTransfer(tokenOut, recipient, uint256(-amountOut));

        // callback for the input
        uint256 balanceBefore = balanceOfToken(tokenIn);
        zeroForOne
            ? IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(amountIn, amountOut, data)
            : IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(amountOut, amountIn, data);
        require(balanceBefore.add(uint256(amountIn)) >= balanceOfToken(tokenIn), 'IIA');

        if (zeroForOne) emit Swap(msg.sender, recipient, amountIn, amountOut, state.sqrtPriceX96, state.tick);
        else emit Swap(msg.sender, recipient, amountOut, amountIn, state.sqrtPriceX96, state.tick);

        slot0.unlocked = true;
    }

    function collectProtocol(
        address recipient,
        uint256 amount0Requested,
        uint256 amount1Requested
    ) external override lock onlyFactoryOwner returns (uint256 amount0, uint256 amount1) {
        amount0 = amount0Requested > protocolFees0 ? protocolFees0 : amount0Requested;
        amount1 = amount1Requested > protocolFees1 ? protocolFees1 : amount1Requested;

        if (amount0 > 0) {
            protocolFees0 -= amount0;
            TransferHelper.safeTransfer(token0, recipient, amount0);
        }
        if (amount1 > 0) {
            protocolFees1 -= amount1;
            TransferHelper.safeTransfer(token1, recipient, amount1);
        }

        emit CollectProtocol(recipient, amount0, amount1);
    }
}
