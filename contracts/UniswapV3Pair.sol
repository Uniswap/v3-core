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
import './interfaces/IUniswapV3PairDeployer.sol';
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

    uint8 private constant PRICE_BIT = 0x10;
    uint8 private constant UNLOCKED_BIT = 0x01;

    // if we constrain the gross liquidity associated to a single tick, then we can guarantee that the total
    // liquidity never exceeds uint128
    // the max liquidity for a single tick fee vote is then:
    //   floor(type(uint128).max / (number of ticks))
    //     = (2n ** 128n - 1n) / (2n ** 24n)
    // this is about 104 bits
    uint128 private constant MAX_LIQUIDITY_GROSS_PER_TICK = 20282409603651670423947251286015;
    uint16 private constant NUMBER_OF_ORACLE_OBSERVATIONS = 1024;

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

    struct Slot0 {
        // the current price
        FixedPoint96.uq64x96 sqrtPrice;
        // the current tick
        int24 tick;
        // the next index of oracleObservations to be updated
        uint16 index;
        // whether the pair is locked
        bool unlocked;
    }

    Slot0 public override slot0;

    struct Slot1 {
        // current in-range liquidity
        uint128 liquidity;
    }

    Slot1 public override slot1;

    struct OracleObservation {
        // the block timestamp of the observation
        uint32 blockTimestamp;
        // the tick accumulator, i.e. tick * time elapsed since the pair was first initialized
        int56 tickCumulative;
        // in-range liquidity at the time of the observation
        uint128 liquidity;
    }

    OracleObservation[NUMBER_OF_ORACLE_OBSERVATIONS] public override oracleObservations;

    address public override feeTo;

    // see TickBitmap.sol
    mapping(int16 => uint256) public override tickBitmap;

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

    // reentrancy lock
    modifier lock() {
        require(slot0.unlocked, 'LOK');
        slot0.unlocked = false;
        _;
        slot0.unlocked = true;
    }

    function _getPosition(
        address owner,
        int24 tickLower,
        int24 tickUpper
    ) private view returns (Position storage position) {
        position = positions[keccak256(abi.encodePacked(owner, tickLower, tickUpper))];
    }

    constructor() {
        (address _factory, address _token0, address _token1, uint24 _fee, int24 _tickSpacing) =
            IUniswapV3PairDeployer(msg.sender).parameters();
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

    function setFeeTo(address feeTo_) external override {
        require(msg.sender == IUniswapV3Factory(factory).owner(), 'OO');
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

    function writeOracleObservationIfNecessary(Slot0 memory _slot0, uint128 liquidity) private {
        uint32 blockTimestamp = _blockTimestamp();

        OracleObservation memory oracleObservationLast =
            oracleObservations[(_slot0.index == 0 ? NUMBER_OF_ORACLE_OBSERVATIONS : _slot0.index) - 1];
        if (oracleObservationLast.blockTimestamp != blockTimestamp) {
            // addition overflow below is desired
            oracleObservations[_slot0.index] = OracleObservation({
                blockTimestamp: blockTimestamp,
                tickCumulative: oracleObservationLast.tickCumulative +
                    int56(blockTimestamp - oracleObservationLast.blockTimestamp) *
                    _slot0.tick,
                liquidity: liquidity
            });
            slot0.index = (_slot0.index + 1) % NUMBER_OF_ORACLE_OBSERVATIONS;
        }
    }

    function _clearTick(int24 tick) private {
        delete tickInfos[tick];
        tickBitmap.flipTick(tick, tickSpacing);
    }

    function initialize(uint160 sqrtPrice, bytes calldata data) external override {
        require(slot0.sqrtPrice._x == 0, 'AI'); // ensure the pair isn't already initialized

        int24 tick = SqrtTickMath.getTickAtSqrtRatio(FixedPoint96.uq64x96(sqrtPrice));
        require(tick >= MIN_TICK, 'MIN');
        require(tick < MAX_TICK, 'MAX');

        Slot0 memory _slot0 = Slot0({sqrtPrice: FixedPoint96.uq64x96(sqrtPrice), tick: tick, index: 0, unlocked: true});

        oracleObservations[_slot0.index++] = OracleObservation({
            blockTimestamp: _blockTimestamp(),
            tickCumulative: 0,
            liquidity: 0
        });

        slot0 = _slot0;

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
        require(slot0.sqrtPrice._x != 0, 'UI'); // ensure the pair is initialized
        require(tickLower < tickUpper, 'TLU');
        require(tickLower >= MIN_TICK, 'TLM');
        require(tickUpper <= MAX_TICK, 'TUM');
        require(tickLower % tickSpacing == 0, 'TLS');
        require(tickUpper % tickSpacing == 0, 'TUS');

        position = _getPosition(owner, tickLower, tickUpper);

        if (liquidityDelta < 0) {
            require(position.liquidity >= uint128(-liquidityDelta), 'CP');
        }

        Tick.Info storage tickInfoLower = _updateTick(tickLower, tick, liquidityDelta);
        Tick.Info storage tickInfoUpper = _updateTick(tickUpper, tick, liquidityDelta);

        require(tickInfoLower.liquidityGross <= MAX_LIQUIDITY_GROSS_PER_TICK, 'LOL');
        require(tickInfoUpper.liquidityGross <= MAX_LIQUIDITY_GROSS_PER_TICK, 'LOU');

        (FixedPoint128.uq128x128 memory feeGrowthInside0, FixedPoint128.uq128x128 memory feeGrowthInside1) =
            tickInfos.getFeeGrowthInside(tickLower, tickUpper, tick, feeGrowthGlobal0, feeGrowthGlobal1);

        // calculate accumulated fees
        uint256 feesOwed0 =
            FullMath.mulDiv(
                feeGrowthInside0._x - position.feeGrowthInside0Last._x,
                position.liquidity,
                FixedPoint128.Q128
            );
        uint256 feesOwed1 =
            FullMath.mulDiv(
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
        Position storage position = _updatePosition(msg.sender, tickLower, tickUpper, 0, slot0.tick);

        if (amount0Requested == uint256(-1)) {
            amount0 = position.feesOwed0;
        } else {
            require(amount0Requested <= position.feesOwed0, 'CF0');
            amount0 = amount0Requested;
        }
        if (amount1Requested == uint256(-1)) {
            amount1 = position.feesOwed1;
        } else {
            require(amount1Requested <= position.feesOwed1, 'CF1');
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
        (int256 amount0Int, int256 amount1Int) =
            _setPosition(
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
        (uint256 balance0, uint256 balance1) =
            (IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)));
        IUniswapV3MintCallback(msg.sender).uniswapV3MintCallback(amount0, amount1, data);
        require(balance0.add(amount0) <= IERC20(token0).balanceOf(address(this)), 'M0');
        require(balance1.add(amount1) <= IERC20(token1).balanceOf(address(this)), 'M1');
    }

    function burn(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount
    ) external override lock returns (uint256 amount0, uint256 amount1) {
        require(amount > 0, 'BA');

        (int256 amount0Int, int256 amount1Int) =
            _setPosition(
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
        // write an oracle entry if liquidity is changing
        if (params.liquidityDelta != 0) writeOracleObservationIfNecessary(slot0, slot1.liquidity);

        Slot0 memory _slot0 = slot0; // for SLOAD savings

        _updatePosition(params.owner, params.tickLower, params.tickUpper, params.liquidityDelta, _slot0.tick);

        // the current price is below the passed range, so the liquidity can only become in range by crossing from left
        // to right, at which point we'll need _more_ token0 (it's becoming more valuable) so the user must provide it
        if (_slot0.tick < params.tickLower) {
            amount0 = SqrtPriceMath.getAmount0Delta(
                SqrtTickMath.getSqrtRatioAtTick(params.tickUpper),
                SqrtTickMath.getSqrtRatioAtTick(params.tickLower),
                params.liquidityDelta
            );
        } else if (_slot0.tick < params.tickUpper) {
            // the current price is inside the passed range
            amount0 = SqrtPriceMath.getAmount0Delta(
                SqrtTickMath.getSqrtRatioAtTick(params.tickUpper),
                _slot0.sqrtPrice,
                params.liquidityDelta
            );
            amount1 = SqrtPriceMath.getAmount1Delta(
                SqrtTickMath.getSqrtRatioAtTick(params.tickLower),
                _slot0.sqrtPrice,
                params.liquidityDelta
            );

            // downcasting is safe because of gross liquidity checks in the _updatePosition call
            slot1.liquidity = uint128(slot1.liquidity.addi(params.liquidityDelta));
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
        // how much is being swapped in (positive), or requested out (negative)
        int256 amountSpecified;
        // the max/min price that the pair will end up at after the swap
        FixedPoint96.uq64x96 sqrtPriceLimit;
        // the address that receives amount out
        address recipient;
        // the data to send in the callback
        bytes data;
        // the value of slot0 at the beginning of the swap
        Slot0 slot0Start;
        // the value of slot1 at the beginning of the swap
        Slot1 slot1Start;
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
        FixedPoint96.uq64x96 sqrtPrice;
        // the tick associated with the current price
        int24 tick;
        // the global fee growth of the input token
        FixedPoint128.uq128x128 feeGrowthGlobal;
        // the current liquidity in range
        uint128 liquidity;
    }

    struct StepComputations {
        // the price at the beginning of the step
        FixedPoint96.uq64x96 sqrtPriceStart;
        // the next tick to swap to from the current tick in the swap direction
        int24 tickNext;
        // whether tickNext is initialized or not
        bool initialized;
        // sqrt(price) for the next tick (1/0)
        FixedPoint96.uq64x96 sqrtPriceNext;
        // how much is being swapped in in this step
        uint256 amountIn;
        // how much is being swapped out
        uint256 amountOut;
        // how much fee is being paid in
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

    function _swap(SwapParams memory params) private {
        bool zeroForOne = params.sqrtPriceLimit._x < params.slot0Start.sqrtPrice._x;
        bool exactInput = params.amountSpecified > 0;

        SwapState memory state =
            SwapState({
                amountSpecifiedRemaining: params.amountSpecified,
                amountCalculated: 0,
                sqrtPrice: params.slot0Start.sqrtPrice,
                tick: params.slot0Start.tick,
                feeGrowthGlobal: zeroForOne ? feeGrowthGlobal0 : feeGrowthGlobal1,
                liquidity: params.slot1Start.liquidity
            });

        // continue swapping as long as we haven't used the entire input/output and haven't reached the price limit
        while (state.amountSpecifiedRemaining != 0 && state.sqrtPrice._x != params.sqrtPriceLimit._x) {
            StepComputations memory step;

            step.sqrtPriceStart = state.sqrtPrice;

            (step.tickNext, step.initialized) = tickBitmap.nextInitializedTickWithinOneWord(
                closestTick(state.tick),
                zeroForOne,
                tickSpacing
            );

            // get the price for the next tick
            step.sqrtPriceNext = SqrtTickMath.getSqrtRatioAtTick(step.tickNext);

            (state.sqrtPrice, step.amountIn, step.amountOut, step.feeAmount) = SwapMath.computeSwapStep(
                state.sqrtPrice,
                (
                    zeroForOne
                        ? step.sqrtPriceNext._x < params.sqrtPriceLimit._x
                        : step.sqrtPriceNext._x > params.sqrtPriceLimit._x
                )
                    ? params.sqrtPriceLimit
                    : step.sqrtPriceNext,
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
            state.feeGrowthGlobal._x += FixedPoint128.fraction(step.feeAmount, state.liquidity)._x;

            // shift tick if we reached the next price target
            if (state.sqrtPrice._x == step.sqrtPriceNext._x) {
                // if the tick is initialized, run the tick transition
                if (step.initialized) {
                    // it's ok to put this check here, as the min/max ticks are always initialized
                    require(zeroForOne ? step.tickNext > MIN_TICK : step.tickNext < MAX_TICK, 'TN');

                    Tick.Info storage tickInfo = tickInfos[step.tickNext];
                    // update tick info
                    tickInfo.feeGrowthOutside0 = FixedPoint128.uq128x128(
                        (zeroForOne ? state.feeGrowthGlobal._x : feeGrowthGlobal0._x) - tickInfo.feeGrowthOutside0._x
                    );
                    tickInfo.feeGrowthOutside1 = FixedPoint128.uq128x128(
                        (zeroForOne ? feeGrowthGlobal1._x : state.feeGrowthGlobal._x) - tickInfo.feeGrowthOutside1._x
                    );
                    tickInfo.secondsOutside = params.blockTimestamp - tickInfo.secondsOutside; // overflow is desired

                    // update liquidity, subi from right to left, addi from left to right
                    zeroForOne
                        ? state.liquidity = uint128(state.liquidity.subi(tickInfo.liquidityDelta))
                        : state.liquidity = uint128(state.liquidity.addi(tickInfo.liquidityDelta));
                }

                state.tick = zeroForOne ? step.tickNext - 1 : step.tickNext;
            } else {
                state.tick = SqrtTickMath.getTickAtSqrtRatio(state.sqrtPrice);
                // if the price didn't move from the left boundary, adjust the tick down
                if (zeroForOne && state.sqrtPrice._x == step.sqrtPriceStart._x) state.tick--;
            }
        }

        slot0.sqrtPrice = state.sqrtPrice;

        // update the tick and write an oracle entry if the price moved at least one tick
        if (state.tick != params.slot0Start.tick) {
            slot0.tick = state.tick;
            writeOracleObservationIfNecessary(params.slot0Start, params.slot1Start.liquidity);
        }

        // update liquidity if it changed
        if (params.slot1Start.liquidity != state.liquidity) slot1.liquidity = state.liquidity;

        zeroForOne ? feeGrowthGlobal0 = state.feeGrowthGlobal : feeGrowthGlobal1 = state.feeGrowthGlobal;

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
    }

    // positive (negative) numbers specify exact input (output) amounts, return values are output (input) amounts
    function swap(
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimit,
        address recipient,
        bytes calldata data
    ) external override lock {
        require(amountSpecified != 0, 'AS');

        Slot0 memory _slot0 = slot0;
        require(_slot0.sqrtPrice._x != 0, 'UI'); // ensure the pair is initialized
        require(zeroForOne ? sqrtPriceLimit < _slot0.sqrtPrice._x : sqrtPriceLimit > _slot0.sqrtPrice._x, 'SPL');

        _swap(
            SwapParams({
                amountSpecified: amountSpecified,
                sqrtPriceLimit: FixedPoint96.uq64x96(sqrtPriceLimit),
                recipient: recipient,
                data: data,
                slot0Start: _slot0,
                slot1Start: slot1,
                blockTimestamp: _blockTimestamp()
            })
        );
    }

    function recover(
        address token,
        address recipient,
        uint256 amount
    ) external override lock {
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

    function collect(uint256 amount0Requested, uint256 amount1Requested)
        external
        override
        lock
        returns (uint256 amount0, uint256 amount1)
    {
        if (amount0Requested == uint256(-1)) {
            amount0 = feeToFees0;
        } else {
            require(amount0Requested <= feeToFees0, 'T0');
            amount0 = amount0Requested;
        }
        if (amount1Requested == uint256(-1)) {
            amount1 = feeToFees1;
        } else {
            require(amount1Requested <= feeToFees1, 'T1');
            amount1 = amount1Requested;
        }

        feeToFees0 -= amount0;
        feeToFees1 -= amount1;

        if (amount0 > 0) TransferHelper.safeTransfer(token0, feeTo, amount0);
        if (amount1 > 0) TransferHelper.safeTransfer(token1, feeTo, amount1);
    }
}
