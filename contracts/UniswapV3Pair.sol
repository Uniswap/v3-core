// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;
pragma abicoder v2;

import '@uniswap/lib/contracts/libraries/FullMath.sol';
import '@uniswap/lib/contracts/libraries/TransferHelper.sol';

import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/math/SignedSafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import './libraries/SafeCast.sol';
import './libraries/MixedSafeMath.sol';
import './libraries/SqrtPriceMath.sol';
import './libraries/SwapMath.sol';
import './libraries/SqrtTickMath.sol';

import './interfaces/IUniswapV3Pair.sol';
import './interfaces/IUniswapV3Factory.sol';
import './interfaces/IUniswapV3MintCallback.sol';
import './interfaces/IUniswapV3SwapCallback.sol';
import './libraries/SpacedTickBitmap.sol';
import './libraries/FixedPoint128.sol';
import './libraries/Tick.sol';

contract UniswapV3Pair is IUniswapV3Pair {
    using SafeMath for uint128;
    using SafeMath for uint256;
    using SignedSafeMath for int128;
    using SignedSafeMath for int256;
    using SafeCast for int256;
    using SafeCast for uint256;
    using MixedSafeMath for uint128;
    using FixedPoint128 for FixedPoint128.uq128x128;
    using SpacedTickBitmap for mapping(int16 => uint256);
    using Tick for mapping(int24 => Tick.Info);

    // if we constrain the gross liquidity associated to a single tick, then we can guarantee that the total
    // liquidityCurrent never exceeds uint128
    // the max liquidity for a single tick fee vote is then:
    //   floor(type(uint128).max / (number of ticks))
    //     = (2n ** 128n - 1n) / (2n ** 24n)
    // this is about 104 bits
    uint128 private constant MAX_LIQUIDITY_GROSS_PER_TICK = 20282409603651670423947251286015;

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
    int24 public immutable override MIN_TICK;
    int24 public immutable override MAX_TICK;

    address public override feeTo;

    // see TickBitmap.sol
    mapping(int16 => uint256) public override tickBitmap;

    // single storage slot
    FixedPoint96.uq64x96 public override sqrtPriceCurrent; // sqrt(token1 / token0) price
    uint32 public override blockTimestampLast;
    int56 public override tickCumulativeLast;
    bool private unlocked = true;
    // single storage slot

    // single storage slot
    uint128 public override liquidityCurrent; // all in-range liquidity
    // single storage slot

    // fee growth per unit of liquidity
    FixedPoint128.uq128x128 public override feeGrowthGlobal0;
    FixedPoint128.uq128x128 public override feeGrowthGlobal1;

    // accumulated protocol fees
    uint256 public override feeToFees0;
    uint256 public override feeToFees1;

    mapping(int24 => Tick.Info) public tickInfos;

    struct Position {
        uint128 liquidity;
        // fee growth per unit of liquidity as of the last modification
        FixedPoint128.uq128x128 feeGrowthInside0Last;
        FixedPoint128.uq128x128 feeGrowthInside1Last;
        // the fees owed to the position owner in token0/token1
        uint256 feesOwed0;
        uint256 feesOwed1;
    }
    mapping(bytes32 => Position) public positions;

    modifier lock() {
        require(unlocked, 'UniswapV3Pair::lock: reentrancy prohibited');
        unlocked = false;
        _;
        unlocked = true;
    }

    function _getPosition(
        address owner,
        int24 tickLower,
        int24 tickUpper
    ) private view returns (Position storage position) {
        position = positions[keccak256(abi.encodePacked(owner, tickLower, tickUpper))];
    }

    // check for one-time initialization
    function isInitialized() public view override returns (bool) {
        return sqrtPriceCurrent._x != 0; // sufficient check
    }

    function tickCurrent() public view override returns (int24) {
        return SqrtTickMath.getTickAtSqrtRatio(sqrtPriceCurrent);
    }

    constructor(
        address _factory,
        address _token0,
        address _token1,
        uint24 _fee,
        int24 _tickSpacing
    ) {
        factory = _factory;
        token0 = _token0;
        token1 = _token1;
        fee = _fee;
        tickSpacing = _tickSpacing;

        MIN_TICK = (SqrtTickMath.MIN_TICK / _tickSpacing) * _tickSpacing;
        MAX_TICK = (SqrtTickMath.MAX_TICK / _tickSpacing) * _tickSpacing;
    }

    // returns the block timestamp % 2**32
    // overridden for tests
    function _blockTimestamp() internal view virtual returns (uint32) {
        return uint32(block.timestamp); // truncation is desired
    }

    function getCumulatives() public view override returns (uint32 blockTimestamp, int56 tickCumulative) {
        require(isInitialized(), 'UniswapV3Pair::getCumulatives: pair not initialized');
        blockTimestamp = _blockTimestamp();

        if (blockTimestampLast != blockTimestamp) {
            uint32 timeElapsed = blockTimestamp - blockTimestampLast;
            tickCumulative = tickCumulativeLast + int56(timeElapsed) * tickCurrent();
        } else {
            return (blockTimestamp, tickCumulativeLast);
        }
    }

    function setFeeTo(address feeTo_) external override {
        require(msg.sender == IUniswapV3Factory(factory).owner(), 'UniswapV3Pair::setFeeTo: caller not owner');
        feeTo = feeTo_;
    }

    function _updateTick(
        int24 tick,
        int24 current,
        int128 liquidityDelta
    ) private returns (Tick.Info storage tickInfo) {
        tickInfo = tickInfos[tick];

        if (liquidityDelta != 0) {
            if (tickInfo.liquidityGross == 0) {
                assert(liquidityDelta > 0);
                // by convention, we assume that all growth before a tick was initialized happened _below_ the tick
                if (tick <= current) {
                    tickInfo.feeGrowthOutside0 = feeGrowthGlobal0;
                    tickInfo.feeGrowthOutside1 = feeGrowthGlobal1;
                    tickInfo.secondsOutside = _blockTimestamp();
                }
                // safe because we know liquidityDelta is > 0
                tickInfo.liquidityGross = uint128(liquidityDelta);
                tickBitmap.flipTick(tick, tickSpacing);
            } else {
                tickInfo.liquidityGross = uint128(tickInfo.liquidityGross.addi(liquidityDelta));
            }
        }
    }

    function _clearTick(int24 tick) private {
        delete tickInfos[tick];
        tickBitmap.flipTick(tick, tickSpacing);
    }

    function initialize(uint160 sqrtPrice, bytes calldata data) external override {
        require(!isInitialized(), 'UniswapV3Pair::initialize: pair already initialized');

        // initialize oracle timestamp
        blockTimestampLast = _blockTimestamp();

        // initialize current price
        sqrtPriceCurrent = FixedPoint96.uq64x96(sqrtPrice);

        emit Initialized(sqrtPrice);

        // set permanent 1 wei position
        mint(address(0), MIN_TICK, MAX_TICK, 1, data);
    }

    // gets and updates and gets a position with the given liquidity delta
    function _updatePosition(
        address owner,
        int24 tickLower,
        int24 tickUpper,
        int128 liquidityDelta,
        int24 tick
    ) private returns (Position storage position) {
        require(tickLower < tickUpper, 'UniswapV3Pair::_updatePosition: tickLower must be less than tickUpper');
        require(tickLower >= MIN_TICK, 'UniswapV3Pair::_updatePosition: tickLower cannot be less than min tick');
        require(tickUpper <= MAX_TICK, 'UniswapV3Pair::_updatePosition: tickUpper cannot be greater than max tick');
        require(
            tickLower % tickSpacing == 0,
            'UniswapV3Pair::_updatePosition: tickSpacing must evenly divide tickLower'
        );
        require(
            tickUpper % tickSpacing == 0,
            'UniswapV3Pair::_updatePosition: tickSpacing must evenly divide tickUpper'
        );

        position = _getPosition(owner, tickLower, tickUpper);

        if (liquidityDelta == 0) {
            require(
                position.liquidity > 0 || position.feesOwed0 > 0 || position.feesOwed1 > 0,
                'UniswapV3Pair::_updatePosition: cannot collect non-existent fees'
            );
        } else if (liquidityDelta < 0) {
            require(
                position.liquidity >= uint128(-liquidityDelta),
                'UniswapV3Pair::_updatePosition: cannot remove more than current position liquidity'
            );
        }

        Tick.Info storage tickInfoLower = _updateTick(tickLower, tick, liquidityDelta);
        Tick.Info storage tickInfoUpper = _updateTick(tickUpper, tick, liquidityDelta);

        require(
            tickInfoLower.liquidityGross <= MAX_LIQUIDITY_GROSS_PER_TICK,
            'UniswapV3Pair::_updatePosition: liquidity overflow in lower tick'
        );
        require(
            tickInfoUpper.liquidityGross <= MAX_LIQUIDITY_GROSS_PER_TICK,
            'UniswapV3Pair::_updatePosition: liquidity overflow in upper tick'
        );

        (FixedPoint128.uq128x128 memory feeGrowthInside0, FixedPoint128.uq128x128 memory feeGrowthInside1) = tickInfos
            .getFeeGrowthInside(tickLower, tickUpper, tick, feeGrowthGlobal0, feeGrowthGlobal1);

        // calculate accumulated fees
        uint256 feesOwed0 = FullMath.mulDiv(
            feeGrowthInside0._x - position.feeGrowthInside0Last._x,
            position.liquidity,
            FixedPoint128.Q128
        );
        uint256 feesOwed1 = FullMath.mulDiv(
            feeGrowthInside1._x - position.feeGrowthInside1Last._x,
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
        position.feeGrowthInside0Last = feeGrowthInside0;
        position.feeGrowthInside1Last = feeGrowthInside1;
        position.feesOwed0 += feesOwed0;
        position.feesOwed1 += feesOwed1;

        // when the lower (upper) tick is crossed left to right (right to left), liquidity must be added (removed)
        tickInfoLower.liquidityDelta = tickInfoLower.liquidityDelta.add(liquidityDelta).toInt128();
        tickInfoUpper.liquidityDelta = tickInfoUpper.liquidityDelta.sub(liquidityDelta).toInt128();

        // clear any tick or position data that is no longer needed
        if (liquidityDelta < 0) {
            if (tickInfoLower.liquidityGross == 0) _clearTick(tickLower);
            if (tickInfoUpper.liquidityGross == 0) _clearTick(tickUpper);
            if (position.liquidity == 0) {
                delete position.feeGrowthInside0Last;
                delete position.feeGrowthInside1Last;
            }
        }
    }

    function collectFees(
        int24 tickLower,
        int24 tickUpper,
        address recipient,
        uint256 amount0Requested,
        uint256 amount1Requested
    ) external override lock returns (uint256 amount0, uint256 amount1) {
        Position storage position = _updatePosition(msg.sender, tickLower, tickUpper, 0, tickCurrent());

        if (amount0Requested == uint256(-1)) {
            amount0 = position.feesOwed0;
        } else {
            require(amount0Requested <= position.feesOwed0, 'UniswapV3Pair::collectFees: too much token0 requested');
            amount0 = amount0Requested;
        }
        if (amount1Requested == uint256(-1)) {
            amount1 = position.feesOwed1;
        } else {
            require(amount1Requested <= position.feesOwed1, 'UniswapV3Pair::collectFees: too much token1 requested');
            amount1 = amount1Requested;
        }

        position.feesOwed0 -= amount0;
        position.feesOwed1 -= amount1;
        if (amount0 > 0) TransferHelper.safeTransfer(token0, recipient, amount0);
        if (amount1 > 0) TransferHelper.safeTransfer(token1, recipient, amount1);
    }

    function mint(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount,
        bytes calldata data
    ) public override lock returns (uint256 amount0, uint256 amount1) {
        require(isInitialized(), 'UniswapV3Pair::mint: pair not initialized');
        require(amount > 0, 'UniswapV3Pair::mint: amount must be greater than 0');

        (int256 amount0Int, int256 amount1Int) = _setPosition(
            SetPositionParams({
                owner: recipient,
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidityDelta: int256(amount).toInt128()
            })
        );

        assert(amount0Int >= 0);
        assert(amount1Int >= 0);

        amount0 = uint256(amount0Int);
        amount1 = uint256(amount1Int);

        // collect payment via callback
        {
            (uint256 balance0, uint256 balance1) = (
                IERC20(token0).balanceOf(address(this)),
                IERC20(token1).balanceOf(address(this))
            );
            IUniswapV3MintCallback(msg.sender).uniswapV3MintCallback(amount0, amount1, data);
            require(
                balance0.add(amount0) <= IERC20(token0).balanceOf(address(this)),
                'UniswapV3Pair::mint: insufficient token0 amount'
            );
            require(
                balance1.add(amount1) <= IERC20(token1).balanceOf(address(this)),
                'UniswapV3Pair::mint: insufficient token1 amount'
            );
        }
    }

    function burn(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount
    ) external override lock returns (uint256 amount0, uint256 amount1) {
        require(isInitialized(), 'UniswapV3Pair::burn: pair not initialized');
        require(amount > 0, 'UniswapV3Pair::burn: amount must be greater than 0');

        (int256 amount0Int, int256 amount1Int) = _setPosition(
            SetPositionParams({
                owner: msg.sender,
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidityDelta: -int256(amount).toInt128()
            })
        );

        assert(amount0Int <= 0);
        assert(amount1Int <= 0);

        amount0 = uint256(-amount0Int);
        amount1 = uint256(-amount1Int);

        if (amount0 > 0) TransferHelper.safeTransfer(token0, recipient, amount0);
        if (amount1 > 0) TransferHelper.safeTransfer(token1, recipient, amount1);
    }

    struct SetPositionParams {
        // the address that will pay for the mint
        address owner;
        // the lower and upper tick of the position
        int24 tickLower;
        int24 tickUpper;
        // the change in liquidity to effect
        int128 liquidityDelta;
    }

    // effect some changes to a position
    function _setPosition(SetPositionParams memory params) private returns (int256 amount0, int256 amount1) {
        int24 tick = tickCurrent();

        _updatePosition(params.owner, params.tickLower, params.tickUpper, params.liquidityDelta, tick);

        // the current price is below the passed range, so the liquidity can only become in range by crossing from left
        // to right, at which point we'll need _more_ token0 (it's becoming more valuable) so the user must provide it
        if (tick < params.tickLower) {
            amount0 = SqrtPriceMath.getAmount0Delta(
                SqrtTickMath.getSqrtRatioAtTick(params.tickUpper),
                SqrtTickMath.getSqrtRatioAtTick(params.tickLower),
                params.liquidityDelta
            );
        } else if (tick < params.tickUpper) {
            // the current price is inside the passed range
            amount0 = SqrtPriceMath.getAmount0Delta(
                SqrtTickMath.getSqrtRatioAtTick(params.tickUpper),
                sqrtPriceCurrent,
                params.liquidityDelta
            );
            amount1 = SqrtPriceMath.getAmount1Delta(
                SqrtTickMath.getSqrtRatioAtTick(params.tickLower),
                sqrtPriceCurrent,
                params.liquidityDelta
            );

            liquidityCurrent = liquidityCurrent.addi(params.liquidityDelta).toUint128();
        } else {
            // the current price is above the passed range, so liquidity can only become in range by crossing from right
            // to left, at which point we need _more_ token1 (it's becoming more valuable) so the user must provide it
            amount1 = SqrtPriceMath.getAmount1Delta(
                SqrtTickMath.getSqrtRatioAtTick(params.tickLower),
                SqrtTickMath.getSqrtRatioAtTick(params.tickUpper),
                params.liquidityDelta
            );
        }
    }

    struct SwapParams {
        // the tick where the price starts
        int24 tickStart;
        // whether the swap is from token 0 to 1, or 1 for 0
        bool zeroForOne;
        // how much is being swapped in (positive), or requested out (negative)
        int256 amountSpecified;
        // the address that receives amount out
        address recipient;
        // the timestamp of the current block
        uint32 blockTimestamp;
        // the data to send in the callback
        bytes data;
    }

    // the top level state of the swap, the results of which are recorded in storage at the end
    struct SwapState {
        // the amount remaining to be swapped in/out of the input/output asset
        int256 amountSpecifiedRemaining;
        // the tick associated with the current price
        int24 tick;
        // current sqrt(price)
        FixedPoint96.uq64x96 sqrtPrice;
        // the global fee growth of the input token
        FixedPoint128.uq128x128 feeGrowthGlobal;
        // the liquidity in range
        uint128 liquidityCurrent;
    }

    struct StepComputations {
        // the next initialized tick from the current tick in the swap direction
        int24 tickNext;
        // sqrt(price) for the target tick (1/0)
        FixedPoint96.uq64x96 sqrtPriceNext;
        // how much is being swapped in in this step
        uint256 amountIn;
        // how much is being swapped out in the current step
        uint256 amountOut;
        // how much fee is paid from the amount in
        uint256 feeAmount;
    }

    // returns the closest parent tick that could be initialized
    // the parent tick is the tick s.t. the input tick is gte parent tick and lt parent tick + tickSpacing
    function closestTick(int24 tick) private view returns (int24) {
        int24 compressed = tick / tickSpacing;
        // round towards negative infinity
        if (tick < 0 && tick % tickSpacing != 0) compressed--;
        return compressed * tickSpacing;
    }

    function _swap(SwapParams memory params) private returns (uint256 amountCalculated) {
        SwapState memory state = SwapState({
            amountSpecifiedRemaining: params.amountSpecified,
            tick: params.tickStart,
            sqrtPrice: sqrtPriceCurrent,
            feeGrowthGlobal: params.zeroForOne ? feeGrowthGlobal0 : feeGrowthGlobal1,
            liquidityCurrent: liquidityCurrent
        });

        while (state.amountSpecifiedRemaining != 0) {
            StepComputations memory step;

            (step.tickNext, ) = tickBitmap.nextInitializedTickWithinOneWord(
                closestTick(state.tick),
                params.zeroForOne,
                tickSpacing
            );

            if (params.zeroForOne) require(step.tickNext >= MIN_TICK, 'UniswapV3Pair::_swap: crossed min tick');
            else require(step.tickNext <= MAX_TICK, 'UniswapV3Pair::_swap: crossed max tick');

            // get the price for the next tick we're moving toward
            step.sqrtPriceNext = SqrtTickMath.getSqrtRatioAtTick(step.tickNext);

            // if there might be room to move in the current tick, continue calculations
            if (params.zeroForOne == false || (state.sqrtPrice._x > step.sqrtPriceNext._x)) {
                (state.sqrtPrice, step.amountIn, step.amountOut, step.feeAmount) = SwapMath.computeSwapStep(
                    state.sqrtPrice,
                    step.sqrtPriceNext,
                    state.liquidityCurrent,
                    state.amountSpecifiedRemaining,
                    fee
                );

                // decrement (increment) remaining input (negative output) amount
                // TODO we might not need safemath below
                if (state.amountSpecifiedRemaining > 0) {
                    state.amountSpecifiedRemaining -= step.amountIn.add(step.feeAmount).toInt256();
                    amountCalculated = amountCalculated.add(step.amountOut);
                } else {
                    state.amountSpecifiedRemaining += step.amountOut.toInt256();
                    amountCalculated = amountCalculated.add(step.amountIn.add(step.feeAmount));
                }

                // update global fee tracker
                state.feeGrowthGlobal._x += FixedPoint128.fraction(step.feeAmount, state.liquidityCurrent)._x;
            }

            // we have to shift to the next tick if either of two conditions are true:
            // 1) a positive input amount remains
            // 2) if we're moving right and the price is exactly on the target tick
            // TODO ensure that there's no off-by-one error here while transitioning ticks in either direction
            if (
                state.amountSpecifiedRemaining != 0 ||
                (params.zeroForOne == false && state.sqrtPrice._x == step.sqrtPriceNext._x)
            ) {
                Tick.Info storage tickInfo = tickInfos[step.tickNext];

                // if the tick is initialized, update it
                if (tickInfo.liquidityGross > 0) {
                    // update tick info
                    tickInfo.feeGrowthOutside0 = FixedPoint128.uq128x128(
                        (params.zeroForOne ? state.feeGrowthGlobal._x : feeGrowthGlobal0._x) -
                            tickInfo.feeGrowthOutside0._x
                    );
                    tickInfo.feeGrowthOutside1 = FixedPoint128.uq128x128(
                        (params.zeroForOne ? feeGrowthGlobal1._x : state.feeGrowthGlobal._x) -
                            tickInfo.feeGrowthOutside1._x
                    );
                    tickInfo.secondsOutside = params.blockTimestamp - tickInfo.secondsOutside; // overflow is desired

                    // update liquidityCurrent, subi from right to left, addi from left to right
                    if (params.zeroForOne) {
                        state.liquidityCurrent = uint128(state.liquidityCurrent.subi(tickInfo.liquidityDelta));
                    } else {
                        state.liquidityCurrent = uint128(state.liquidityCurrent.addi(tickInfo.liquidityDelta));
                    }
                }

                // todo: this might not be ok. the price may not move due to the remaining input amount!
                // original rationale: this is ok because we still have amountInRemaining so price is guaranteed to be
                // less than the tick after swapping the remaining amount in
                state.tick = params.zeroForOne ? step.tickNext - 1 : step.tickNext;
            } else {
                state.tick = SqrtTickMath.getTickAtSqrtRatio(state.sqrtPrice);
            }
        }

        // the price moved at least one tick
        if (state.tick != params.tickStart) {
            liquidityCurrent = state.liquidityCurrent;

            uint32 _blockTimestampLast = blockTimestampLast;
            if (_blockTimestampLast != params.blockTimestamp) {
                blockTimestampLast = params.blockTimestamp;
                // overflow desired
                tickCumulativeLast += int56(params.blockTimestamp - _blockTimestampLast) * params.tickStart;
            }
        }

        sqrtPriceCurrent = state.sqrtPrice;

        if (params.zeroForOne) {
            feeGrowthGlobal0 = state.feeGrowthGlobal;
        } else {
            feeGrowthGlobal1 = state.feeGrowthGlobal;
        }

        (uint256 amountIn, uint256 amountOut) = params.amountSpecified > 0
            ? (uint256(params.amountSpecified), amountCalculated)
            : (amountCalculated, uint256(-params.amountSpecified));

        // perform the token transfers
        {
            (address tokenIn, address tokenOut) = params.zeroForOne ? (token0, token1) : (token1, token0);
            TransferHelper.safeTransfer(tokenOut, params.recipient, amountOut);
            uint256 balanceBefore = IERC20(tokenIn).balanceOf(address(this));
            params.zeroForOne
                ? IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(
                    -amountIn.toInt256(),
                    amountOut.toInt256(),
                    params.data
                )
                : IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(
                    amountOut.toInt256(),
                    -amountIn.toInt256(),
                    params.data
                );
            require(
                balanceBefore.add(amountIn) >= IERC20(tokenIn).balanceOf(address(this)),
                'UniswapV3Pair::_swap: insufficient input amount'
            );
        }
    }

    function swapExact0For1(
        uint256 amount0In,
        address recipient,
        bytes calldata data
    ) external override lock returns (uint256 amount1Out) {
        require(amount0In > 1, 'UniswapV3Pair::swapExact0For1: amountIn must be greater than 1');

        return
            _swap(
                SwapParams({
                    tickStart: tickCurrent(),
                    zeroForOne: true,
                    amountSpecified: amount0In.toInt256(),
                    recipient: recipient,
                    blockTimestamp: _blockTimestamp(),
                    data: data
                })
            );
    }

    function swap0ForExact1(
        uint256 amount1Out,
        address recipient,
        bytes calldata data
    ) external override lock returns (uint256 amount0In) {
        require(amount1Out > 0, 'UniswapV3Pair::swap0ForExact1: amountOut must be greater than 0');

        return
            _swap(
                SwapParams({
                    tickStart: tickCurrent(),
                    zeroForOne: true,
                    amountSpecified: -amount1Out.toInt256(),
                    recipient: recipient,
                    blockTimestamp: _blockTimestamp(),
                    data: data
                })
            );
    }

    function swapExact1For0(
        uint256 amount1In,
        address recipient,
        bytes calldata data
    ) external override lock returns (uint256 amount0Out) {
        require(amount1In > 1, 'UniswapV3Pair::swapExact1For0: amountIn must be greater than 1');

        return
            _swap(
                SwapParams({
                    tickStart: tickCurrent(),
                    zeroForOne: false,
                    amountSpecified: amount1In.toInt256(),
                    recipient: recipient,
                    blockTimestamp: _blockTimestamp(),
                    data: data
                })
            );
    }

    function swap1ForExact0(
        uint256 amount0Out,
        address recipient,
        bytes calldata data
    ) external override lock returns (uint256 amount1In) {
        require(amount0Out > 0, 'UniswapV3Pair::swap1ForExact0: amountOut must be greater than 0');

        return
            _swap(
                SwapParams({
                    tickStart: tickCurrent(),
                    zeroForOne: false,
                    amountSpecified: -amount0Out.toInt256(),
                    recipient: recipient,
                    blockTimestamp: _blockTimestamp(),
                    data: data
                })
            );
    }

    function recover(
        address token,
        address recipient,
        uint256 amount
    ) external override {
        require(msg.sender == IUniswapV3Factory(factory).owner(), 'UniswapV3Pair::recover: caller not owner');

        uint256 token0Balance = IERC20(token0).balanceOf(address(this));
        uint256 token1Balance = IERC20(token1).balanceOf(address(this));

        TransferHelper.safeTransfer(token, recipient, amount);

        // check the balance hasn't changed
        require(
            IERC20(token0).balanceOf(address(this)) == token0Balance &&
                IERC20(token1).balanceOf(address(this)) == token1Balance,
            'UniswapV3Pair::recover: cannot recover token0 or token1'
        );
    }

    function collect(uint256 amount0Requested, uint256 amount1Requested)
        external
        override
        returns (uint256 amount0, uint256 amount1)
    {
        if (amount0Requested == uint256(-1)) {
            amount0 = feeToFees0;
        } else {
            require(amount0Requested <= feeToFees0, 'UniswapV3Pair::collect: too much token0 requested');
            amount0 = amount0Requested;
        }
        if (amount1Requested == uint256(-1)) {
            amount1 = feeToFees1;
        } else {
            require(amount1Requested <= feeToFees1, 'UniswapV3Pair::collect: too much token1 requested');
            amount1 = amount1Requested;
        }

        feeToFees0 -= amount0;
        feeToFees1 -= amount1;
        if (amount0 > 0) TransferHelper.safeTransfer(token0, feeTo, amount0);
        if (amount1 > 0) TransferHelper.safeTransfer(token1, feeTo, amount1);
    }
}
