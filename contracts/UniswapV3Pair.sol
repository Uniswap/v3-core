// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;
pragma abicoder v2;

import './libraries/FullMath.sol';
import './libraries/TransferHelper.sol';

import './libraries/SafeMath.sol';
import './libraries/SignedSafeMath.sol';

import './libraries/SafeCast.sol';
import './libraries/LiquidityMath.sol';
import './libraries/SqrtPriceMath.sol';
import './libraries/SwapMath.sol';
import './libraries/SqrtTickMath.sol';
import './libraries/TickBitmap.sol';
import './libraries/FixedPoint128.sol';
import './libraries/Tick.sol';
import './libraries/SecondsOutside.sol';
import './libraries/Position.sol';
import './libraries/Oracle.sol';

import './interfaces/IERC20Minimal.sol';
import './interfaces/IUniswapV3Pair.sol';
import './interfaces/IUniswapV3PairDeployer.sol';
import './interfaces/IUniswapV3Factory.sol';
import './interfaces/callback/IUniswapV3MintCallback.sol';
import './interfaces/callback/IUniswapV3SwapCallback.sol';
import './interfaces/callback/IUniswapV3FlashCallback.sol';
import './NoDelegateCall.sol';

contract UniswapV3Pair is IUniswapV3Pair, NoDelegateCall {
    using SafeMath for uint256;
    using SignedSafeMath for int256;
    using SafeCast for uint256;
    using SafeCast for int256;
    using LiquidityMath for uint128;
    using Tick for mapping(int24 => Tick.Info);
    using TickBitmap for mapping(int16 => uint256);
    using SecondsOutside for mapping(int24 => uint256);
    using Position for mapping(bytes32 => Position.Info);
    using Position for Position.Info;
    using Oracle for Oracle.Observation[65535];

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
        // the current maximum number of observations that are being stored
        uint16 observationCardinality;
        // the next maximum number of observations to store, triggered in observations.write
        uint16 observationCardinalityNext;
        // the current protocol fee as a percentage of total fees, represented as an integer denominator (1/x)%
        uint8 feeProtocol;
        // whether the pair is locked
        bool unlocked;
    }
    Slot0 public override slot0;

    // fee growth per unit of liquidity
    uint256 public override feeGrowthGlobal0X128;
    uint256 public override feeGrowthGlobal1X128;

    // accumulated protocol fees in token0/token1 units
    struct ProtocolFees {
        uint128 token0;
        uint128 token1;
    }
    ProtocolFees public override protocolFees;

    // the current liquidity
    uint128 public override liquidity;

    mapping(int24 => Tick.Info) public override ticks;
    mapping(int16 => uint256) public override tickBitmap;
    mapping(int24 => uint256) public override secondsOutside;
    mapping(bytes32 => Position.Info) public override positions;
    Oracle.Observation[65535] public override observations;

    modifier lock() {
        require(slot0.unlocked, 'LOK');
        slot0.unlocked = false;
        _;
        slot0.unlocked = true;
    }

    modifier onlyFactoryOwner() {
        require(msg.sender == IUniswapV3Factory(factory).owner());
        _;
    }

    constructor() {
        int24 _tickSpacing;
        (factory, token0, token1, fee, _tickSpacing) = IUniswapV3PairDeployer(msg.sender).parameters();
        tickSpacing = _tickSpacing;

        (minTick, maxTick, maxLiquidityPerTick) = Tick.tickSpacingToParameters(_tickSpacing);
    }

    function checkTicks(int24 tickLower, int24 tickUpper) private view {
        require(tickLower < tickUpper, 'TLU');
        require(tickLower >= minTick, 'TLM');
        require(tickUpper <= maxTick, 'TUM');
    }

    // returns the block timestamp % 2**32
    // overridden for tests
    function _blockTimestamp() internal view virtual returns (uint32) {
        return uint32(block.timestamp); // truncation is desired
    }

    function balance0() private view returns (uint256) {
        return balanceOfToken(token0);
    }

    function balance1() private view returns (uint256) {
        return balanceOfToken(token1);
    }

    function balanceOfToken(address token) private view returns (uint256) {
        return IERC20Minimal(token).balanceOf(address(this));
    }

    function secondsInside(int24 tickLower, int24 tickUpper) external view override noDelegateCall returns (uint32) {
        checkTicks(tickLower, tickUpper);
        require(ticks[tickLower].liquidityGross > 0 && ticks[tickUpper].liquidityGross > 0, 'X');
        return secondsOutside.secondsInside(tickLower, tickUpper, slot0.tick, tickSpacing, _blockTimestamp());
    }

    function scry(uint32 secondsAgo)
        external
        view
        override
        noDelegateCall
        returns (int56 tickCumulative, uint160 liquidityCumulative)
    {
        return
            observations.scry(
                _blockTimestamp(),
                secondsAgo,
                slot0.tick,
                slot0.observationIndex,
                liquidity,
                slot0.observationCardinality
            );
    }

    // increases the next observation cardinality, callable by anyone after initialize.
    function increaseObservationCardinalityNext(uint16 observationCardinalityNext) external override noDelegateCall {
        uint16 observationCardinalityNextOld = slot0.observationCardinalityNext; // for the event
        uint16 observationCardinalityNextNew =
            observations.grow(observationCardinalityNextOld, observationCardinalityNext);
        slot0.observationCardinalityNext = observationCardinalityNextNew;
        emit ObservationCardinalityNextIncreased(observationCardinalityNextOld, observationCardinalityNextNew);
    }

    // not locked because it initializes unlocked
    function initialize(uint160 sqrtPriceX96) external override {
        require(slot0.sqrtPriceX96 == 0, 'AI');

        int24 tick = SqrtTickMath.getTickAtSqrtRatio(sqrtPriceX96);
        require(tick >= minTick, 'MIN');
        require(tick < maxTick, 'MAX');

        (uint16 cardinality, uint16 cardinalityNext) = observations.initialize(_blockTimestamp());

        slot0 = Slot0({
            sqrtPriceX96: sqrtPriceX96,
            tick: tick,
            observationIndex: 0,
            observationCardinality: cardinality,
            observationCardinalityNext: cardinalityNext,
            feeProtocol: 0,
            unlocked: true
        });

        emit Initialized(sqrtPriceX96, tick);
    }

    struct ModifyPositionParams {
        // the address that owns the position
        address owner;
        // the lower and upper tick of the position
        int24 tickLower;
        int24 tickUpper;
        // any change in liquidity
        int128 liquidityDelta;
    }

    // effect some changes to a position
    function _modifyPosition(ModifyPositionParams memory params)
        private
        noDelegateCall
        returns (int256 amount0, int256 amount1)
    {
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
                (slot0.observationIndex, slot0.observationCardinality) = observations.write(
                    _slot0.observationIndex,
                    _blockTimestamp(),
                    _slot0.tick,
                    liquidityBefore,
                    _slot0.observationCardinality,
                    _slot0.observationCardinalityNext
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
                liquidity = liquidityBefore.addDelta(params.liquidityDelta);
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

    // gets and updates and gets a position with the given liquidity delta
    function _updatePosition(
        address owner,
        int24 tickLower,
        int24 tickUpper,
        int128 liquidityDelta,
        int24 tick
    ) private {
        Position.Info storage position = positions.get(owner, tickLower, tickUpper);

        uint256 _feeGrowthGlobal0X128 = feeGrowthGlobal0X128; // SLOAD for gas optimization
        uint256 _feeGrowthGlobal1X128 = feeGrowthGlobal1X128; // SLOAD for gas optimization

        // if we need to update the ticks, do it
        bool flippedLower;
        bool flippedUpper;
        if (liquidityDelta != 0) {
            uint32 blockTimestamp = _blockTimestamp();

            flippedLower = ticks.update(
                tickLower,
                tick,
                liquidityDelta,
                _feeGrowthGlobal0X128,
                _feeGrowthGlobal1X128,
                false,
                maxLiquidityPerTick
            );
            flippedUpper = ticks.update(
                tickUpper,
                tick,
                liquidityDelta,
                _feeGrowthGlobal0X128,
                _feeGrowthGlobal1X128,
                true,
                maxLiquidityPerTick
            );

            if (flippedLower) {
                tickBitmap.flipTick(tickLower, tickSpacing);
                secondsOutside.initialize(tickLower, tick, tickSpacing, blockTimestamp);
            }
            if (flippedUpper) {
                tickBitmap.flipTick(tickUpper, tickSpacing);
                secondsOutside.initialize(tickUpper, tick, tickSpacing, blockTimestamp);
            }
        }

        (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) =
            ticks.getFeeGrowthInside(tickLower, tickUpper, tick, _feeGrowthGlobal0X128, _feeGrowthGlobal1X128);

        (uint256 protocolFees0New, uint256 protocolFees1New) =
            position.update(liquidityDelta, feeGrowthInside0X128, feeGrowthInside1X128, slot0.feeProtocol);
        if (protocolFees0New > 0 || protocolFees1New > 0) {
            ProtocolFees memory _protocolFees = protocolFees;
            protocolFees.token0 = SafeMath.addCapped(_protocolFees.token0, protocolFees0New);
            protocolFees.token1 = SafeMath.addCapped(_protocolFees.token1, protocolFees1New);
        }

        // clear any tick data that is no longer needed
        if (liquidityDelta < 0) {
            if (flippedLower) {
                ticks.clear(tickLower);
                secondsOutside.clear(tickLower, tickSpacing);
            }
            if (flippedUpper) {
                ticks.clear(tickUpper);
                secondsOutside.clear(tickUpper, tickSpacing);
            }
        }
    }

    // noDelegateCall is applied indirectly via _modifyPosition
    function poke(
        address owner,
        int24 tickLower,
        int24 tickUpper
    ) external override lock {
        _modifyPosition(
            ModifyPositionParams({owner: owner, tickLower: tickLower, tickUpper: tickUpper, liquidityDelta: 0})
        );
    }

    // noDelegateCall is applied indirectly via _modifyPosition
    function mint(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount,
        bytes calldata data
    ) external override lock {
        require(amount > 0);
        (int256 amount0Int, int256 amount1Int) =
            _modifyPosition(
                ModifyPositionParams({
                    owner: recipient,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    liquidityDelta: int256(amount).toInt128()
                })
            );

        uint256 amount0 = uint256(amount0Int);
        uint256 amount1 = uint256(amount1Int);

        // todo: we need some test coverage to prove amount0Int/amount1Int are always positive and amount0 > 0 || amount1 > 0 is always true

        uint256 balance0Before;
        uint256 balance1Before;
        if (amount0 > 0) balance0Before = balance0();
        if (amount1 > 0) balance1Before = balance1();
        IUniswapV3MintCallback(msg.sender).uniswapV3MintCallback(amount0, amount1, data);
        if (amount0 > 0) require(balance0Before.add(amount0) <= balance0(), 'M0');
        if (amount1 > 0) require(balance1Before.add(amount1) <= balance1(), 'M1');

        emit Mint(recipient, tickLower, tickUpper, msg.sender, amount, amount0, amount1);
    }

    function collect(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external override lock returns (uint128 amount0, uint128 amount1) {
        // we don't need to checkTicks here, because invalid positions will never have non-zero feesOwed{0,1}
        Position.Info storage position = positions.get(msg.sender, tickLower, tickUpper);

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

        // note that spurious `Collect` events can be emitted with zero amounts - just ignore them
        emit Collect(msg.sender, tickLower, tickUpper, recipient, amount0, amount1);
    }

    // noDelegateCall is applied indirectly via _modifyPosition
    function burn(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount
    ) external override lock returns (uint256 amount0, uint256 amount1) {
        require(amount > 0);
        (int256 amount0Int, int256 amount1Int) =
            _modifyPosition(
                ModifyPositionParams({
                    owner: msg.sender,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    liquidityDelta: -int256(amount).toInt128()
                })
            );

        amount0 = uint256(-amount0Int);
        amount1 = uint256(-amount1Int);

        if (amount0 > 0) TransferHelper.safeTransfer(token0, recipient, amount0);
        if (amount1 > 0) TransferHelper.safeTransfer(token1, recipient, amount1);

        emit Burn(msg.sender, tickLower, tickUpper, recipient, amount, amount0, amount1);
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
    // manually locked for the sake of gas efficiency
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external override noDelegateCall {
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

            // shift tick if we reached the next price
            if (state.sqrtPriceX96 == step.sqrtPriceNextX96) {
                require(zeroForOne ? step.tickNext > minTick : step.tickNext < maxTick, 'TN');

                // if the tick is initialized, run the tick transition
                if (step.initialized) {
                    int128 liquidityDelta =
                        ticks.cross(
                            step.tickNext,
                            (zeroForOne ? state.feeGrowthGlobalX128 : feeGrowthGlobal0X128),
                            (zeroForOne ? feeGrowthGlobal1X128 : state.feeGrowthGlobalX128)
                        );

                    secondsOutside.cross(step.tickNext, tickSpacing, cache.blockTimestamp);

                    // update liquidity, subtract from right to left, add from left to right
                    state.liquidity = zeroForOne
                        ? state.liquidity.subDelta(liquidityDelta)
                        : state.liquidity.addDelta(liquidityDelta);
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
            (slot0.observationIndex, slot0.observationCardinality) = observations.write(
                cache.slot0Start.observationIndex,
                cache.blockTimestamp,
                cache.slot0Start.tick,
                cache.liquidityStart,
                cache.slot0Start.observationCardinality,
                cache.slot0Start.observationCardinalityNext
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
        if (amountOut != 0) TransferHelper.safeTransfer(tokenOut, recipient, uint256(-amountOut));

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

    function flash(
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external override lock noDelegateCall {
        uint128 _liquidity = liquidity;
        require(_liquidity > 0, 'L');

        uint256 fee0 = FullMath.mulDivRoundingUp(amount0, fee, 1e6);
        uint256 fee1 = FullMath.mulDivRoundingUp(amount1, fee, 1e6);
        uint256 balance0Before = balance0();
        uint256 balance1Before = balance1();

        if (amount0 > 0) TransferHelper.safeTransfer(token0, recipient, amount0);
        if (amount1 > 0) TransferHelper.safeTransfer(token1, recipient, amount1);

        IUniswapV3FlashCallback(msg.sender).uniswapV3FlashCallback(fee0, fee1, data);

        uint256 paid0 = balance0().sub(balance0Before);
        uint256 paid1 = balance1().sub(balance1Before);

        require(paid0 >= fee0, 'F0');
        require(paid1 >= fee1, 'F1');

        if (paid0 > 0) feeGrowthGlobal0X128 += FullMath.mulDiv(paid0, FixedPoint128.Q128, _liquidity);
        if (paid1 > 0) feeGrowthGlobal1X128 += FullMath.mulDiv(paid1, FixedPoint128.Q128, _liquidity);

        emit Flash(msg.sender, recipient, amount0, amount1, paid0, paid1);
    }

    function setFeeProtocol(uint8 feeProtocol) external override onlyFactoryOwner {
        require(feeProtocol == 0 || (feeProtocol <= 10 && feeProtocol >= 4));
        emit FeeProtocolChanged(slot0.feeProtocol, feeProtocol);
        slot0.feeProtocol = feeProtocol;
    }

    function collectProtocol(
        address recipient,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external override lock onlyFactoryOwner returns (uint128 amount0, uint128 amount1) {
        ProtocolFees memory _protocolFees = protocolFees;

        amount0 = amount0Requested > _protocolFees.token0 ? _protocolFees.token0 : amount0Requested;
        amount1 = amount1Requested > _protocolFees.token1 ? _protocolFees.token1 : amount1Requested;

        if (amount0 > 0) {
            protocolFees.token0 -= amount0;
            TransferHelper.safeTransfer(token0, recipient, amount0);
        }
        if (amount1 > 0) {
            protocolFees.token1 -= amount1;
            TransferHelper.safeTransfer(token1, recipient, amount1);
        }

        emit CollectProtocol(recipient, amount0, amount1);
    }
}
