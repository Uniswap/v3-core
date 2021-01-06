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

import './interfaces/IERC20.sol';
import './interfaces/IUniswapV3Pair.sol';
import './interfaces/IUniswapV3PairDeployer.sol';
import './interfaces/IUniswapV3Factory.sol';
import './interfaces/IUniswapV3MintCallback.sol';
import './interfaces/IUniswapV3SwapCallback.sol';

contract UniswapV3Pair is IUniswapV3Pair {
    using SafeMath for uint128;
    using SafeMath for uint256;
    using SignedSafeMath for int128;
    using SignedSafeMath for int256;
    using SafeCast for int256;
    using SafeCast for uint256;
    using MixedSafeMath for uint128;
    using MixedSafeMath for uint256;
    using SpacedTickBitmap for mapping(int16 => uint256);
    using Tick for mapping(int24 => Tick.Info);
    using Position for mapping(bytes32 => Position.Info);

    uint8 private constant PRICE_BIT = 0x10;
    uint8 private constant UNLOCKED_BIT = 0x01;

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
        uint160 sqrtPriceCurrentX96;
        // the last block timestamp where the tick accumulator was updated
        uint32 blockTimestampLast;
        // the tick accumulator, i.e. tick * time elapsed since the pair was first initialized
        int56 tickCumulativeLast;
        // whether the pair is locked for swapping
        // packed with a boolean representing whether the price is at the lower bounds of the
        // tick boundary but the tick transition has already happened
        uint8 unlockedAndPriceBit;
    }

    Slot0 public override slot0;

    // current in-range liquidity
    uint128 public override liquidityCurrent;

    address public override feeTo;

    // see TickBitmap.sol
    mapping(int16 => uint256) public override tickBitmap;

    // fee growth per unit of liquidity
    uint256 public override feeGrowthGlobal0X128;
    uint256 public override feeGrowthGlobal1X128;

    // accumulated protocol fees
    uint256 public override feeToFees0;
    uint256 public override feeToFees1;

    mapping(int24 => Tick.Info) public ticks;
    mapping(bytes32 => Position.Info) public positions;

    // lock the pair for operations that do not modify the price, i.e. everything but swap
    modifier lockNoPriceMovement() {
        uint8 uapb = slot0.unlockedAndPriceBit;
        require(uapb & UNLOCKED_BIT == UNLOCKED_BIT, 'LOK');
        slot0.unlockedAndPriceBit = uapb ^ UNLOCKED_BIT;
        _;
        slot0.unlockedAndPriceBit = uapb;
    }

    // throws if the pair is not initialized, which is implicitly used throughout to gatekeep various functions
    function tickCurrent() public view override returns (int24) {
        return _tickCurrent(slot0);
    }

    function _tickCurrent(Slot0 memory _slot0) internal pure returns (int24) {
        int24 tick = SqrtTickMath.getTickAtSqrtRatio(_slot0.sqrtPriceCurrentX96);
        if (_slot0.unlockedAndPriceBit & PRICE_BIT == PRICE_BIT) tick--;
        return tick;
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

    // returns the block timestamp % 2**32
    // overridden for tests
    function _blockTimestamp() internal view virtual returns (uint32) {
        return uint32(block.timestamp); // truncation is desired
    }

    function checkTicks(int24 tickLower, int24 tickUpper) private view {
        require(tickLower < tickUpper, 'TLU');
        require(tickLower >= minTick, 'TLM');
        require(tickUpper <= maxTick, 'TUM');
    }

    function setFeeTo(address feeTo_) external override {
        require(msg.sender == IUniswapV3Factory(factory).owner(), 'OO');
        emit FeeToChanged(feeTo, feeTo_);
        feeTo = feeTo_;
    }

    function initialize(uint160 sqrtPriceX96, bytes calldata data) external override {
        Slot0 memory _slot0 = slot0;
        require(_slot0.sqrtPriceCurrentX96 == 0, 'AI');

        _slot0 = Slot0({
            blockTimestampLast: _blockTimestamp(),
            tickCumulativeLast: 0,
            sqrtPriceCurrentX96: sqrtPriceX96,
            unlockedAndPriceBit: 1
        });

        int24 tick = SqrtTickMath.getTickAtSqrtRatio(_slot0.sqrtPriceCurrentX96);
        require(tick >= minTick, 'MIN');
        require(tick < maxTick, 'MAX');

        slot0 = _slot0;

        emit Initialized(sqrtPriceX96, tick);

        // set permanent 1 wei position
        mint(address(0), minTick, maxTick, 1, data);
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

        uint256 _feeGrowthGlobal0X128 = feeGrowthGlobal0X128;
        uint256 _feeGrowthGlobal1X128 = feeGrowthGlobal1X128;
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

        // collect protocol fee, if on
        if (feeTo != address(0)) {
            uint256 fee0 = feesOwed0 / 6;
            feesOwed0 -= fee0;
            feeToFees0 += fee0;

            uint256 fee1 = feesOwed1 / 6;
            feesOwed1 -= fee1;
            feeToFees1 += fee1;
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
    ) external override lockNoPriceMovement returns (uint256 amount0, uint256 amount1) {
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
    ) public override lockNoPriceMovement {
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

        // if necessary, collect payment via callback
        // TODO we could decrease bytecode size here at the cost of gas increase
        if (amount0 > 0 && amount1 > 0) {
            uint256 balance0 = IERC20(token0).balanceOf(address(this));
            uint256 balance1 = IERC20(token1).balanceOf(address(this));
            IUniswapV3MintCallback(msg.sender).uniswapV3MintCallback(amount0, amount1, data);
            require(balance0.add(amount0) <= IERC20(token0).balanceOf(address(this)), 'M0');
            require(balance1.add(amount1) <= IERC20(token1).balanceOf(address(this)), 'M1');
        } else if (amount0 > 0 && amount1 == 0) {
            uint256 balance0 = IERC20(token0).balanceOf(address(this));
            IUniswapV3MintCallback(msg.sender).uniswapV3MintCallback(amount0, 0, data);
            require(balance0.add(amount0) <= IERC20(token0).balanceOf(address(this)), 'M0');
        } else if (amount0 == 0 && amount1 > 0) {
            uint256 balance1 = IERC20(token1).balanceOf(address(this));
            IUniswapV3MintCallback(msg.sender).uniswapV3MintCallback(0, amount1, data);
            require(balance1.add(amount1) <= IERC20(token1).balanceOf(address(this)), 'M1');
        }

        emit Mint(recipient, tickLower, tickUpper, msg.sender, amount, amount0, amount1);
    }

    function burn(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount
    ) external override lockNoPriceMovement returns (uint256 amount0, uint256 amount1) {
        require(amount > 0, 'BA');
        require(amount < 2**127, 'BA');

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

        int24 tick = tickCurrent();

        _updatePosition(params.owner, params.tickLower, params.tickUpper, params.liquidityDelta, tick);

        if (params.liquidityDelta != 0) {
            if (tick < params.tickLower) {
                // current tick is below the passed range; liquidity can only become in range by crossing from left to
                // right, when we'll need _more_ token0 (it's becoming more valuable) so user must provide it
                amount0 = SqrtPriceMath.getAmount0Delta(
                    SqrtTickMath.getSqrtRatioAtTick(params.tickUpper),
                    SqrtTickMath.getSqrtRatioAtTick(params.tickLower),
                    params.liquidityDelta
                );
            } else if (tick < params.tickUpper) {
                // current tick is inside the passed range
                amount0 = SqrtPriceMath.getAmount0Delta(
                    SqrtTickMath.getSqrtRatioAtTick(params.tickUpper),
                    slot0.sqrtPriceCurrentX96,
                    params.liquidityDelta
                );
                amount1 = SqrtPriceMath.getAmount1Delta(
                    SqrtTickMath.getSqrtRatioAtTick(params.tickLower),
                    slot0.sqrtPriceCurrentX96,
                    params.liquidityDelta
                );

                // downcasting is safe because of gross liquidity checks
                liquidityCurrent = uint128(liquidityCurrent.addi(params.liquidityDelta));
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

    struct SwapParams {
        // how much is being swapped in (positive), or requested out (negative)
        int256 amountSpecified;
        // the max/min price that the pair will end up at after the swap
        uint160 sqrtPriceLimitX96;
        // the address that receives amount out
        address recipient;
        // the data to send in the callback
        bytes data;
        // the value of slot0 at the beginning of the swap
        Slot0 slot0Start;
        // the value of liquidityCurrent at the beginning of the swap
        uint128 liquidityStart;
        // the tick at the beginning of the swap
        int24 tickStart;
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
        // whether the price is at the lower tickCurrent boundary and a tick transition has already occurred
        bool priceBit;
        // the tick associated with the current price
        int24 tick;
        // the global fee growth of the input token
        uint256 feeGrowthGlobalX128;
        // the current liquidity in range
        uint128 liquidity;
    }

    struct StepComputations {
        // the price at the beginning of the step
        uint160 sqrtPriceStart;
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

    function _swap(SwapParams memory params) private {
        bool zeroForOne = params.sqrtPriceLimitX96 < params.slot0Start.sqrtPriceCurrentX96;
        bool exactInput = params.amountSpecified > 0;

        slot0.unlockedAndPriceBit = params.slot0Start.unlockedAndPriceBit ^ UNLOCKED_BIT;

        SwapState memory state =
            SwapState({
                amountSpecifiedRemaining: params.amountSpecified,
                amountCalculated: 0,
                sqrtPriceX96: params.slot0Start.sqrtPriceCurrentX96,
                priceBit: params.slot0Start.unlockedAndPriceBit & PRICE_BIT == PRICE_BIT,
                tick: params.tickStart,
                feeGrowthGlobalX128: zeroForOne ? feeGrowthGlobal0X128 : feeGrowthGlobal1X128,
                liquidity: params.liquidityStart
            });

        // continue swapping as long as we haven't used the entire input/output and haven't reached the price limit
        while (state.amountSpecifiedRemaining != 0 && state.sqrtPriceX96 != params.sqrtPriceLimitX96) {
            StepComputations memory step;

            step.sqrtPriceStart = state.sqrtPriceX96;

            (step.tickNext, step.initialized) = tickBitmap.nextInitializedTickWithinOneWord(
                state.tick,
                tickSpacing,
                zeroForOne
            );

            // get the price for the next tick
            step.sqrtPriceNextX96 = SqrtTickMath.getSqrtRatioAtTick(step.tickNext);

            (state.sqrtPriceX96, step.amountIn, step.amountOut, step.feeAmount) = SwapMath.computeSwapStep(
                state.sqrtPriceX96,
                (
                    zeroForOne
                        ? step.sqrtPriceNextX96 < params.sqrtPriceLimitX96
                        : step.sqrtPriceNextX96 > params.sqrtPriceLimitX96
                )
                    ? params.sqrtPriceLimitX96
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
            state.feeGrowthGlobalX128 += FixedPoint128.fraction(step.feeAmount, state.liquidity);

            // shift tick if we reached the next price target
            if (state.sqrtPriceX96 == step.sqrtPriceNextX96) {
                // if the tick is initialized, run the tick transition
                if (step.initialized) {
                    // it's ok to put this condition here, because the min/max ticks are always initialized
                    if (zeroForOne) require(step.tickNext > minTick, 'MIN');
                    else require(step.tickNext < maxTick, 'MAX');

                    int128 liquidityDelta =
                        ticks.cross(
                            step.tickNext,
                            (zeroForOne ? state.feeGrowthGlobalX128 : feeGrowthGlobal0X128),
                            (zeroForOne ? feeGrowthGlobal1X128 : state.feeGrowthGlobalX128),
                            params.blockTimestamp
                        );

                    // update liquidityCurrent, subi from right to left, addi from left to right
                    if (zeroForOne) state.liquidity = uint128(state.liquidity.subi(liquidityDelta));
                    else state.liquidity = uint128(state.liquidity.addi(liquidityDelta));
                }

                state.priceBit = zeroForOne;
                state.tick = zeroForOne ? step.tickNext - 1 : step.tickNext;
            } else {
                state.priceBit = state.priceBit && zeroForOne && state.sqrtPriceX96 == step.sqrtPriceStart;
                state.tick =
                    SqrtTickMath.getTickAtSqrtRatio(state.sqrtPriceX96) +
                    (state.priceBit ? int24(-1) : int24(0));
            }
        }

        // update liquidity if it changed
        if (params.liquidityStart != state.liquidity) liquidityCurrent = state.liquidity;

        // the price moved at least one tick, update the accumulator
        if (state.tick != params.tickStart) {
            uint32 _blockTimestampLast = params.slot0Start.blockTimestampLast;
            if (_blockTimestampLast != params.blockTimestamp) {
                slot0.blockTimestampLast = params.blockTimestamp;
                // overflow desired
                slot0.tickCumulativeLast =
                    params.slot0Start.tickCumulativeLast +
                    int56(params.blockTimestamp - _blockTimestampLast) *
                    params.tickStart;
            }
        }

        slot0.sqrtPriceCurrentX96 = state.sqrtPriceX96;
        // still locked until after the callback, but need to record the price bit
        slot0.unlockedAndPriceBit = state.priceBit ? PRICE_BIT : 0;

        if (zeroForOne) feeGrowthGlobal0X128 = state.feeGrowthGlobalX128;
        else feeGrowthGlobal1X128 = state.feeGrowthGlobalX128;

        // amountIn is always >0, amountOut is always <=0
        (int256 amountIn, int256 amountOut) =
            exactInput
                ? (params.amountSpecified - state.amountSpecifiedRemaining, state.amountCalculated)
                : (state.amountCalculated, params.amountSpecified - state.amountSpecifiedRemaining);

        (address tokenIn, address tokenOut) = zeroForOne ? (token0, token1) : (token1, token0);

        // transfer the output
        TransferHelper.safeTransfer(tokenOut, params.recipient, uint256(-amountOut));

        // callback for the input
        uint256 balanceBefore = IERC20(tokenIn).balanceOf(address(this));
        zeroForOne
            ? IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(amountIn, amountOut, params.data)
            : IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(amountOut, amountIn, params.data);
        require(balanceBefore.add(uint256(amountIn)) >= IERC20(tokenIn).balanceOf(address(this)), 'IIA');

        slot0.unlockedAndPriceBit = state.priceBit ? PRICE_BIT | UNLOCKED_BIT : UNLOCKED_BIT;

        if (zeroForOne) emit Swap(msg.sender, params.recipient, amountIn, amountOut, state.sqrtPriceX96, state.tick);
        else Swap(msg.sender, params.recipient, amountOut, amountIn, state.sqrtPriceX96, state.tick);
    }

    // positive (negative) numbers specify exact input (output) amounts, return values are output (input) amounts
    function swap(
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        address recipient,
        bytes calldata data
    ) external override {
        require(amountSpecified != 0, 'AS');

        Slot0 memory _slot0 = slot0;
        require(_slot0.unlockedAndPriceBit & UNLOCKED_BIT == UNLOCKED_BIT, 'LOK');
        require(
            zeroForOne
                ? sqrtPriceLimitX96 < _slot0.sqrtPriceCurrentX96
                : sqrtPriceLimitX96 > _slot0.sqrtPriceCurrentX96,
            'SPL'
        );

        _swap(
            SwapParams({
                amountSpecified: amountSpecified,
                sqrtPriceLimitX96: sqrtPriceLimitX96,
                recipient: recipient,
                data: data,
                slot0Start: _slot0,
                liquidityStart: liquidityCurrent,
                tickStart: _tickCurrent(_slot0),
                blockTimestamp: _blockTimestamp()
            })
        );
    }

    function recover(
        address token,
        address recipient,
        uint256 amount
    ) external override lockNoPriceMovement {
        require(msg.sender == IUniswapV3Factory(factory).owner(), 'OO');

        uint256 token0Balance = IERC20(token0).balanceOf(address(this));
        uint256 token1Balance = IERC20(token1).balanceOf(address(this));

        TransferHelper.safeTransfer(token, recipient, amount);

        // check the balance hasn't changed
        require(
            IERC20(token0).balanceOf(address(this)) == token0Balance &&
                IERC20(token1).balanceOf(address(this)) == token1Balance,
            'TOK'
        );
    }

    function collectProtocol(uint256 amount0Requested, uint256 amount1Requested)
        external
        override
        lockNoPriceMovement
        returns (uint256 amount0, uint256 amount1)
    {
        amount0 = amount0Requested > feeToFees0 ? feeToFees0 : amount0Requested;
        amount1 = amount1Requested > feeToFees1 ? feeToFees1 : amount1Requested;

        if (amount0 > 0) {
            feeToFees0 -= amount0;
            TransferHelper.safeTransfer(token0, feeTo, amount0);
        }
        if (amount1 > 0) {
            feeToFees1 -= amount1;
            TransferHelper.safeTransfer(token1, feeTo, amount1);
        }

        emit CollectProtocol(amount0, amount1);
    }
}
