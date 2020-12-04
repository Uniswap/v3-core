// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.12;
pragma experimental ABIEncoderV2;

import '@uniswap/lib/contracts/libraries/FullMath.sol';
import '@uniswap/lib/contracts/libraries/TransferHelper.sol';

import '@openzeppelin/contracts/math/Math.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/math/SignedSafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import './libraries/SafeCast.sol';
import './libraries/MixedSafeMath.sol';
import './libraries/PriceMath.sol';
import './libraries/TickMath.sol';

import './interfaces/IUniswapV3Pair.sol';
import './interfaces/IUniswapV3Factory.sol';
import './interfaces/IUniswapV3Callee.sol';
import './libraries/SpacedTickBitmap.sol';
import './libraries/FixedPoint128.sol';

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

    // if we constrain the liquidity associated to a single tick, then we can guarantee that the total
    // liquidityCurrent never exceeds uint128
    // the max liquidity for a single tick fee vote is then:
    //   floor(type(uint128).max / (number of ticks))
    //     = (2n ** 128n - 1n) / (2n ** 16n)
    // this is about 112 bits
    uint128 private constant MAX_LIQUIDITY_GROSS_PER_TICK = 5192296858534827628530496329220095;

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
    uint32 public override blockTimestampLast;
    uint160 public override liquidityCumulativeLast;
    int56 public override tickCumulativeLast;
    bool private unlocked = true;
    // single storage slot

    // single storage slot (104 bits empty)
    uint128 public override liquidityCurrent; // all in-range liquidity
    // single storage slot

    FixedPoint128.uq128x128 public override priceCurrent; // (token1 / token0) price

    // fee growth per unit of liquidity
    FixedPoint128.uq128x128 public override feeGrowthGlobal0;
    FixedPoint128.uq128x128 public override feeGrowthGlobal1;

    // accumulated protocol fees
    // there is no value in packing these values, since we only ever set one at a time
    uint256 public override feeToFees0;
    uint256 public override feeToFees1;

    struct TickInfo {
        // the total position liquidity that references this tick
        uint128 liquidityGross;
        // seconds spent on the _other_ side of this tick (relative to the current tick)
        // only has relative meaning, not absolute — the value depends on when the tick is initialized
        uint32 secondsOutside;
        // fee growth per unit of liquidity on the _other_ side of this tick (relative to the current tick)
        // only has relative meaning, not absolute — the value depends on when the tick is initialized
        FixedPoint128.uq128x128 feeGrowthOutside0;
        FixedPoint128.uq128x128 feeGrowthOutside1;
        // amount of liquidity added (subtracted) when tick is crossed from left to right (right to left),
        // i.e. as the price goes up (down), for each fee vote
        int128 liquidityDelta;
    }
    mapping(int24 => TickInfo) public tickInfos;

    struct Position {
        uint128 liquidity;
        // fee growth per unit of liquidity as of the last modification
        FixedPoint128.uq128x128 feeGrowthInside0Last;
        FixedPoint128.uq128x128 feeGrowthInside1Last;
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

    function _getFeeGrowthBelow(
        int24 tick,
        int24 current,
        TickInfo storage tickInfo
    )
        private
        view
        returns (FixedPoint128.uq128x128 memory feeGrowthBelow0, FixedPoint128.uq128x128 memory feeGrowthBelow1)
    {
        // tick is above the current tick, meaning growth outside represents growth above, not below
        if (tick > current) {
            feeGrowthBelow0 = FixedPoint128.uq128x128(feeGrowthGlobal0._x - tickInfo.feeGrowthOutside0._x);
            feeGrowthBelow1 = FixedPoint128.uq128x128(feeGrowthGlobal1._x - tickInfo.feeGrowthOutside1._x);
        } else {
            feeGrowthBelow0 = tickInfo.feeGrowthOutside0;
            feeGrowthBelow1 = tickInfo.feeGrowthOutside1;
        }
    }

    function _getFeeGrowthAbove(
        int24 tick,
        int24 current,
        TickInfo storage tickInfo
    )
        private
        view
        returns (FixedPoint128.uq128x128 memory feeGrowthAbove0, FixedPoint128.uq128x128 memory feeGrowthAbove1)
    {
        // tick is above current tick, meaning growth outside represents growth above
        if (tick > current) {
            feeGrowthAbove0 = tickInfo.feeGrowthOutside0;
            feeGrowthAbove1 = tickInfo.feeGrowthOutside1;
        } else {
            feeGrowthAbove0 = FixedPoint128.uq128x128(feeGrowthGlobal0._x - tickInfo.feeGrowthOutside0._x);
            feeGrowthAbove1 = FixedPoint128.uq128x128(feeGrowthGlobal1._x - tickInfo.feeGrowthOutside1._x);
        }
    }

    function _getFeeGrowthInside(
        int24 tickLower,
        int24 tickUpper,
        int24 current,
        TickInfo storage tickInfoLower,
        TickInfo storage tickInfoUpper
    )
        private
        view
        returns (FixedPoint128.uq128x128 memory feeGrowthInside0, FixedPoint128.uq128x128 memory feeGrowthInside1)
    {
        (
            FixedPoint128.uq128x128 memory feeGrowthBelow0,
            FixedPoint128.uq128x128 memory feeGrowthBelow1
        ) = _getFeeGrowthBelow(tickLower, current, tickInfoLower);
        (
            FixedPoint128.uq128x128 memory feeGrowthAbove0,
            FixedPoint128.uq128x128 memory feeGrowthAbove1
        ) = _getFeeGrowthAbove(tickUpper, current, tickInfoUpper);
        feeGrowthInside0 = FixedPoint128.uq128x128(feeGrowthGlobal0._x - feeGrowthBelow0._x - feeGrowthAbove0._x);
        feeGrowthInside1 = FixedPoint128.uq128x128(feeGrowthGlobal1._x - feeGrowthBelow1._x - feeGrowthAbove1._x);
    }

    // check for one-time initialization
    function isInitialized() public view override returns (bool) {
        return priceCurrent._x != 0; // sufficient check
    }

    function tickCurrent() public view override returns (int24) {
        return TickMath.getTickAtRatio(priceCurrent._x);
    }

    constructor(
        address _factory,
        address _token0,
        address _token1,
        uint24 _fee,
        int24 _tickSpacing
    ) public {
        require(_tickSpacing > 0, 'UniswapV3Pair::constructor: _tickSpacing must be greater than 0');

        factory = _factory;
        token0 = _token0;
        token1 = _token1;
        fee = _fee;
        tickSpacing = _tickSpacing;
        MIN_TICK = (TickMath.MIN_TICK / _tickSpacing) * _tickSpacing;
        MAX_TICK = (TickMath.MAX_TICK / _tickSpacing) * _tickSpacing;
    }

    // returns the block timestamp % 2**64
    // overridden for tests
    function _blockTimestamp() internal view virtual returns (uint32) {
        return uint32(block.timestamp); // truncation is desired
    }

    // on the first interaction per block, update the oracle price accumulator and fee
    function _updateAccumulators() private {
        uint32 blockTimestamp = _blockTimestamp();

        if (blockTimestampLast != blockTimestamp) {
            (blockTimestampLast, liquidityCumulativeLast, tickCumulativeLast) = getCumulatives();
        }
    }

    function getCumulatives()
        public
        view
        override
        returns (
            uint32 blockTimestamp,
            uint160 liquidityCumulative,
            int56 tickCumulative
        )
    {
        require(isInitialized(), 'UniswapV3Pair::getCumulatives: pair not initialized');
        blockTimestamp = _blockTimestamp();

        if (blockTimestampLast != blockTimestamp) {
            uint32 timeElapsed = blockTimestamp - blockTimestampLast;
            liquidityCumulative = liquidityCumulativeLast + uint160(timeElapsed) * liquidityCurrent;
            tickCumulative = tickCumulativeLast + int56(timeElapsed) * TickMath.getTickAtRatio(priceCurrent._x);
        } else {
            return (blockTimestamp, liquidityCumulativeLast, tickCumulativeLast);
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
    ) private returns (TickInfo storage tickInfo) {
        tickInfo = tickInfos[tick];

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

    function _clearTick(int24 tick) private {
        delete tickInfos[tick];
        tickBitmap.flipTick(tick, tickSpacing);
    }

    function initialize(uint256 price) external override lock {
        require(!isInitialized(), 'UniswapV3Pair::initialize: pair already initialized');

        // initialize oracle timestamp and fee
        blockTimestampLast = _blockTimestamp();

        // initialize current price
        priceCurrent = FixedPoint128.uq128x128(price);

        emit Initialized(price);

        // set permanent 1 wei position
        _setPosition(
            SetPositionParams({owner: address(0), tickLower: MIN_TICK, tickUpper: MAX_TICK, liquidityDelta: 1})
        );
    }

    struct SetPositionParams {
        address owner;
        int24 tickLower;
        int24 tickUpper;
        int128 liquidityDelta;
    }

    function setPosition(
        int24 tickLower,
        int24 tickUpper,
        int128 liquidityDelta
    ) external override lock returns (int256 amount0, int256 amount1) {
        require(isInitialized(), 'UniswapV3Pair::setPosition: pair not initialized');
        require(tickLower < tickUpper, 'UniswapV3Pair::setPosition: tickLower must be less than tickUpper');
        require(tickLower >= MIN_TICK, 'UniswapV3Pair::setPosition: tickLower cannot be less than min tick');
        require(tickUpper <= MAX_TICK, 'UniswapV3Pair::setPosition: tickUpper cannot be greater than max tick');
        require(
            tickLower % tickSpacing == 0 && tickUpper % tickSpacing == 0,
            'UniswapV3Pair::setPosition: tickLower and tickUpper must be multiples of tickSpacing'
        );

        return
            _setPosition(
                SetPositionParams({
                    owner: msg.sender,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    liquidityDelta: liquidityDelta
                })
            );
    }

    function _updatePosition(SetPositionParams memory params, int24 tick)
        private
        returns (uint256 feesOwed0, uint256 feesOwed1)
    {
        Position storage position = _getPosition(params.owner, params.tickLower, params.tickUpper);

        if (params.liquidityDelta == 0) {
            require(
                position.liquidity > 0,
                'UniswapV3Pair::_updatePosition: cannot collect fees on 0 liquidity position'
            );
        } else if (params.liquidityDelta < 0) {
            require(
                position.liquidity >= uint128(-params.liquidityDelta),
                'UniswapV3Pair::_updatePosition: cannot remove more than current position liquidity'
            );
        }

        TickInfo storage tickInfoLower = _updateTick(params.tickLower, tick, params.liquidityDelta);
        TickInfo storage tickInfoUpper = _updateTick(params.tickUpper, tick, params.liquidityDelta);

        require(
            tickInfoLower.liquidityGross <= MAX_LIQUIDITY_GROSS_PER_TICK,
            'UniswapV3Pair::_updatePosition: liquidity overflow in lower tick'
        );
        require(
            tickInfoUpper.liquidityGross <= MAX_LIQUIDITY_GROSS_PER_TICK,
            'UniswapV3Pair::_updatePosition: liquidity overflow in upper tick'
        );

        {
            (
                FixedPoint128.uq128x128 memory feeGrowthInside0,
                FixedPoint128.uq128x128 memory feeGrowthInside1
            ) = _getFeeGrowthInside(params.tickLower, params.tickUpper, tick, tickInfoLower, tickInfoUpper);

            // check if this condition has accrued any untracked fees and credit them to the caller
            if (position.liquidity > 0) {
                if (feeGrowthInside0._x > position.feeGrowthInside0Last._x) {
                    feesOwed0 = FullMath.mulDiv(
                        feeGrowthInside0._x - position.feeGrowthInside0Last._x,
                        position.liquidity,
                        FixedPoint128.Q128
                    );
                }
                if (feeGrowthInside1._x > position.feeGrowthInside1Last._x) {
                    feesOwed1 = FullMath.mulDiv(
                        feeGrowthInside1._x - position.feeGrowthInside1Last._x,
                        position.liquidity,
                        FixedPoint128.Q128
                    );
                }

                // collect protocol fee
                if (feeTo != address(0)) {
                    uint256 fee0 = feesOwed0 / 6;
                    feesOwed0 -= fee0;
                    feeToFees0 += fee0;

                    uint256 fee1 = feesOwed1 / 6;
                    feesOwed1 -= fee1;
                    feeToFees1 += fee1;
                }
            }

            // update the position
            position.liquidity = position.liquidity.addi(params.liquidityDelta).toUint128();
            position.feeGrowthInside0Last = feeGrowthInside0;
            position.feeGrowthInside1Last = feeGrowthInside1;
        }

        // when the lower (upper) tick is crossed left to right (right to left), liquidity must be added (removed)
        tickInfoLower.liquidityDelta = tickInfoLower.liquidityDelta.add(params.liquidityDelta).toInt128();
        tickInfoUpper.liquidityDelta = tickInfoUpper.liquidityDelta.sub(params.liquidityDelta).toInt128();

        // clear any tick or position data that is no longer needed
        if (params.liquidityDelta < 0) {
            if (tickInfoLower.liquidityGross == 0) _clearTick(params.tickLower);
            if (tickInfoUpper.liquidityGross == 0) _clearTick(params.tickUpper);
            if (position.liquidity == 0) {
                delete position.feeGrowthInside0Last;
                delete position.feeGrowthInside1Last;
            }
        }
    }

    function _transferDelta(address token, int256 delta) private {
        if (delta > 0) {
            TransferHelper.safeTransferFrom(token, msg.sender, address(this), uint256(delta));
        } else if (delta < 0) {
            TransferHelper.safeTransfer(token, msg.sender, uint256(-delta));
        }
    }

    // add or remove a specified amount of liquidity from a specified range, and/or change feeVote for that range
    // also sync a position and return accumulated fees from it to user as tokens
    // liquidityDelta is sqrt(reserve0Virtual * reserve1Virtual), so does not incorporate fees
    function _setPosition(SetPositionParams memory params) private returns (int256 amount0, int256 amount1) {
        _updateAccumulators();

        int24 tick = tickCurrent();

        // how many fees are owed to the position owner
        (uint256 feesOwed0, uint256 feesOwed1) = _updatePosition(params, tick);

        // the current price is below the passed range, so the liquidity can only become in range by crossing from left
        // to right, at which point we'll need _more_ token0 (it's becoming more valuable) so the user must provide it
        if (tick < params.tickLower) {
            amount0 = PriceMath
                .getAmount0Delta(
                FixedPoint128.uq128x128(TickMath.getRatioAtTick(params.tickLower)),
                FixedPoint128.uq128x128(TickMath.getRatioAtTick(params.tickUpper)),
                params
                    .liquidityDelta
            )
                .sub(feesOwed0.toInt256());
            amount1 = -feesOwed1.toInt256();
        } else if (tick < params.tickUpper) {
            // the current price is inside the passed range
            amount0 = PriceMath
                .getAmount0Delta(
                priceCurrent,
                FixedPoint128.uq128x128(TickMath.getRatioAtTick(params.tickUpper)),
                params
                    .liquidityDelta
            )
                .sub(feesOwed0.toInt256());
            amount1 = PriceMath
                .getAmount1Delta(
                FixedPoint128.uq128x128(TickMath.getRatioAtTick(params.tickLower)),
                priceCurrent,
                params
                    .liquidityDelta
            )
                .sub(feesOwed1.toInt256());

            liquidityCurrent = liquidityCurrent.addi(params.liquidityDelta).toUint128();
        } else {
            amount0 = -feesOwed0.toInt256();
            // the current price is above the passed range, so liquidity can only become in range by crossing from right
            // to left, at which point we need _more_ token1 (it's becoming more valuable) so the user must provide it
            amount1 = PriceMath
                .getAmount1Delta(
                FixedPoint128.uq128x128(TickMath.getRatioAtTick(params.tickLower)),
                FixedPoint128.uq128x128(TickMath.getRatioAtTick(params.tickUpper)),
                params
                    .liquidityDelta
            )
                .sub(feesOwed1.toInt256());
        }

        _transferDelta(token0, amount0);
        _transferDelta(token1, amount1);
    }

    struct SwapParams {
        // the tick where the price starts
        int24 tickStart;
        // whether the swap is from token 0 to 1, or 1 for 0
        bool zeroForOne;
        // how much is being swapped in
        uint256 amountIn;
        // the recipient address
        address to;
        // any data that should be sent to the address with the call
        bytes data;
    }

    // the top level state of the swap, the results of which are recorded in storage at the end
    struct SwapState {
        // the amount in remaining to be swapped of the input asset
        uint256 amountInRemaining;
        // the tick associated with the current price
        int24 tick;
        // the price
        FixedPoint128.uq128x128 price;
        // the global fee growth of the input token
        FixedPoint128.uq128x128 feeGrowthGlobal;
        // the liquidity in range
        uint128 liquidityCurrent;
    }

    struct StepComputations {
        // the next initialized tick from the current tick in the swap direction
        int24 tickNext;
        // price for the target tick (1/0)
        FixedPoint128.uq128x128 priceNext;
        // (computed) virtual reserves of token0
        uint256 reserve0Virtual;
        // (computed) virtual reserves of token1
        uint256 reserve1Virtual;
        // how much is being swapped in in this step
        uint256 amountIn;
        // how much is being swapped out in the current step
        uint256 amountOut;
    }

    // returns the closest parent tick that could be initialized
    // the parent tick is the tick s.t. the input tick is gte parent tick and lt parent tick + tickSpacing
    function closestTick(int24 tick) private view returns (int24) {
        int24 compressed = tick / tickSpacing;
        // round towards negative infinity
        if (tick < 0 && tick % tickSpacing != 0) compressed--;
        return compressed * tickSpacing;
    }

    function _swap(SwapParams memory params) private returns (uint256 amountOut) {
        SwapState memory state = SwapState({
            amountInRemaining: params.amountIn,
            tick: params.tickStart,
            price: priceCurrent,
            feeGrowthGlobal: params.zeroForOne ? feeGrowthGlobal0 : feeGrowthGlobal1,
            liquidityCurrent: liquidityCurrent
        });

        while (state.amountInRemaining > 0) {
            StepComputations memory step;

            (step.tickNext, ) = tickBitmap.nextInitializedTickWithinOneWord(
                closestTick(state.tick),
                params.zeroForOne,
                tickSpacing
            );

            if (params.zeroForOne) require(step.tickNext >= MIN_TICK, 'UniswapV3Pair::_swap: crossed min tick');
            else require(step.tickNext <= MAX_TICK, 'UniswapV3Pair::_swap: crossed max tick');

            // get the price for the next tick we're moving toward
            step.priceNext = FixedPoint128.uq128x128(TickMath.getRatioAtTick(step.tickNext));

            // it should always be the case that if params.zeroForOne is true, we should be at or above the target price
            // similarly, if it's false we should be below the target price
            // TODO we can remove this if/when we're confident they never trigger
            if (params.zeroForOne) assert(state.price._x >= step.priceNext._x);
            else assert(state.price._x < step.priceNext._x);

            // if there might be room to move in the current tick, continue calculations
            if (params.zeroForOne == false || (state.price._x > step.priceNext._x)) {
                // recompute reserves given the current price/liquidity
                (step.reserve0Virtual, step.reserve1Virtual) = PriceMath.getVirtualReservesAtPrice(
                    state.price,
                    state.liquidityCurrent,
                    false
                );

                // compute the amount of input token required to push the price to the target (and max output token)
                (uint256 amountInMax, uint256 amountOutMax) = PriceMath.getInputToRatio(
                    step.reserve0Virtual,
                    step.reserve1Virtual,
                    state.liquidityCurrent,
                    step.priceNext,
                    fee,
                    params.zeroForOne
                );

                // swap to the next tick, or stop early if we've exhausted all the input
                step.amountIn = Math.min(amountInMax, state.amountInRemaining);

                // decrement remaining input amount
                state.amountInRemaining -= step.amountIn;

                // discount the input amount by the fee
                uint256 amountInLessFee = step.amountIn.mul(PriceMath.LP_FEE_BASE - fee) / PriceMath.LP_FEE_BASE;

                // handle the fee accounting
                uint256 feePaid = step.amountIn - amountInLessFee;

                if (feePaid > 0) {
                    // update global fee tracker
                    state.feeGrowthGlobal._x += FixedPoint128.fraction(feePaid, state.liquidityCurrent)._x;
                }

                // handle the swap
                if (amountInLessFee > 0) {
                    // calculate the owed output amount on the discounted input amount
                    step.amountOut = params.zeroForOne
                        ? PriceMath.getAmountOut(step.reserve0Virtual, step.reserve1Virtual, amountInLessFee)
                        : PriceMath.getAmountOut(step.reserve1Virtual, step.reserve0Virtual, amountInLessFee);

                    // cap the output amount
                    step.amountOut = Math.min(step.amountOut, amountOutMax);

                    // increment amountOut
                    amountOut = amountOut.add(step.amountOut);
                }

                // update the price
                // if we've consumed the input required to get to the target price, that's the price now!
                if (step.amountIn == amountInMax) {
                    state.price = step.priceNext;
                } else {
                    // if not, the price is the new ratio of (computed) reserves, capped at the target price
                    if (params.zeroForOne) {
                        FixedPoint128.uq128x128 memory priceEstimate = FixedPoint128.fraction(
                            step.reserve1Virtual.sub(step.amountOut),
                            step.reserve0Virtual.add(amountInLessFee)
                        );
                        state.price = FixedPoint128.uq128x128(Math.max(step.priceNext._x, priceEstimate._x));
                    } else {
                        FixedPoint128.uq128x128 memory priceEstimate = FixedPoint128.fraction(
                            step.reserve1Virtual.add(amountInLessFee),
                            step.reserve0Virtual.sub(step.amountOut)
                        );
                        state.price = FixedPoint128.uq128x128(Math.min(step.priceNext._x, priceEstimate._x));
                    }
                }
            }

            // we have to shift to the next tick if either of two conditions are true:
            // 1) a positive input amount remains
            // 2) if we're moving right and the price is exactly on the target tick
            // TODO ensure that there's no off-by-one error here while transitioning ticks in either direction
            if (state.amountInRemaining > 0 || (params.zeroForOne == false && state.price._x == step.priceNext._x)) {
                TickInfo storage tickInfo = tickInfos[step.tickNext];

                // if the tick is initialized, update it
                // todo: decide on a minimum here that may be non-zero
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
                    tickInfo.secondsOutside = _blockTimestamp() - tickInfo.secondsOutside; // overflow is desired

                    // update liquidityCurrent, subi from right to left, addi from left to right
                    if (params.zeroForOne) {
                        state.liquidityCurrent = uint128(state.liquidityCurrent.subi(tickInfo.liquidityDelta));
                    } else {
                        state.liquidityCurrent = uint128(state.liquidityCurrent.addi(tickInfo.liquidityDelta));
                    }
                }

                // this is ok because we still have amountInRemaining so price is guaranteed to be less than the tick
                // after swapping the remaining amount in
                state.tick = params.zeroForOne ? step.tickNext - 1 : step.tickNext;
            } else {
                // todo: this getTickAtRatio call may not be necessary, since we only use it to determine if we crossed a tick
                state.tick = TickMath.getTickAtRatio(state.price._x);
            }
        }

        if (state.tick != params.tickStart) {
            // must be called before updating the price or liquidity
            _updateAccumulators();
            liquidityCurrent = state.liquidityCurrent;
        }

        priceCurrent = state.price;

        if (params.zeroForOne) {
            feeGrowthGlobal0 = state.feeGrowthGlobal;
        } else {
            feeGrowthGlobal1 = state.feeGrowthGlobal;
        }

        // this is different than v2
        TransferHelper.safeTransfer(params.zeroForOne ? token1 : token0, params.to, amountOut);
        if (params.data.length > 0) {
            params.zeroForOne
                ? IUniswapV3Callee(params.to).swap0For1Callback(msg.sender, amountOut, params.data)
                : IUniswapV3Callee(params.to).swap1For0Callback(msg.sender, amountOut, params.data);
        }
        // to *only* support callback style payment, remove the following transferFrom call.
        TransferHelper.safeTransferFrom(
            params.zeroForOne ? token0 : token1,
            msg.sender,
            address(this),
            params.amountIn
        );
    }

    // move from right to left (token 1 is becoming more valuable)
    function swap0For1(
        uint256 amount0In,
        address to,
        bytes calldata data
    ) external override lock returns (uint256 amount1Out) {
        require(amount0In > 0, 'UniswapV3Pair::swap0For1: amountIn must be greater than 0');

        return _swap(SwapParams({tickStart: tickCurrent(), zeroForOne: true, amountIn: amount0In, to: to, data: data}));
    }

    // move from left to right (token 0 is becoming more valuable)
    function swap1For0(
        uint256 amount1In,
        address to,
        bytes calldata data
    ) external override lock returns (uint256 amount0Out) {
        require(amount1In > 0, 'UniswapV3Pair::swap1For0: amountIn must be greater than 0');

        return
            _swap(SwapParams({tickStart: tickCurrent(), zeroForOne: false, amountIn: amount1In, to: to, data: data}));
    }

    function recover(
        address token,
        address to,
        uint256 amount
    ) external override {
        require(msg.sender == IUniswapV3Factory(factory).owner(), 'UniswapV3Pair::recover: caller not owner');

        uint256 token0Balance = IERC20(token0).balanceOf(address(this));
        uint256 token1Balance = IERC20(token1).balanceOf(address(this));

        TransferHelper.safeTransfer(token, to, amount);

        // check the balance hasn't changed
        require(
            IERC20(token0).balanceOf(address(this)) == token0Balance &&
                IERC20(token1).balanceOf(address(this)) == token1Balance,
            'UniswapV3Pair::recover: cannot recover token0 or token1'
        );
    }
}
