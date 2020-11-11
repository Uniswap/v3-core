// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.12;
pragma experimental ABIEncoderV2;

import '@uniswap/lib/contracts/libraries/FixedPoint.sol';
import '@uniswap/lib/contracts/libraries/FullMath.sol';
import '@uniswap/lib/contracts/libraries/Babylonian.sol';
import '@uniswap/lib/contracts/libraries/TransferHelper.sol';

import '@openzeppelin/contracts/math/Math.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/math/SignedSafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import './libraries/SafeCast.sol';
import './libraries/FixedPointExtra.sol';
import './libraries/MixedSafeMath.sol';
import './libraries/TickMath.sol';
import './libraries/PriceMath.sol';
import './libraries/BitMath.sol';

import './interfaces/IUniswapV3Pair.sol';
import './interfaces/IUniswapV3Factory.sol';
import './interfaces/IUniswapV3Callee.sol';

contract UniswapV3Pair is IUniswapV3Pair {
    using SafeMath for uint256;
    using SafeMath for uint112;
    using SignedSafeMath for int256;
    using SignedSafeMath for int112;
    using SafeCast for uint256;
    using SafeCast for int256;
    using MixedSafeMath for uint112;
    using FixedPoint for FixedPoint.uq112x112;
    using FixedPointExtra for FixedPoint.uq112x112;

    // Number of fee options
    uint8 public constant override NUM_FEE_OPTIONS = 6;

    // list of fee options expressed as bips
    // uint16 because the maximum value is 10_000
    // options are 0.05%, 0.10%, 0.30%, 0.60%, 1.00%, 2.00%
    // ideally this would be a constant array, but constant arrays are not supported in solidity
    function FEE_OPTIONS(uint8 i) public pure override returns (uint16) {
        if (i < 3) {
            if (i == 0) return 5;
            if (i == 1) return 10;
            return 30;
        }
        if (i == 3) return 60;
        if (i == 4) return 100;
        assert(i == 5);
        return 200;
    }

    uint112 public constant override LIQUIDITY_MIN = 1000;

    // TODO could this be 100, or does it need to be 102, or higher? (150? 151? 152? 200?)
    // TODO this could potentially affect how many ticks we need to support
    uint8 public constant override TOKEN_MIN = 101;

    address public immutable override factory;
    address public immutable override token0;
    address public immutable override token1;

    address public override feeTo;

    // ⬇ single storage slot ⬇
    uint112 public override reserve0Virtual;
    uint112 public override reserve1Virtual;
    uint32 public override blockTimestampLast;
    // ⬆ single storage slot ⬆

    // the first price tick _at_ or _below_ the current (reserve1Virtual / reserve0Virtual) price
    // stored to avoid computing log_1.01(reserve1Virtual / reserve0Virtual) on-chain
    int16 public override tickCurrent;

    // the current fee (gets set by the first swap or setPosition/initialize in a block)
    // this is stored to protect liquidity providers from add/swap/remove sandwiching attacks
    uint16 public override feeLast;

    // the amount of in-range liquidity voting for each particular fee vote, used to determine the current fee
    uint112[NUM_FEE_OPTIONS] public override liquidityVirtualVotes;

    uint256 public override price0CumulativeLast; // cumulative (reserve1Virtual / reserve0Virtual) oracle price
    uint256 public override price1CumulativeLast; // cumulative (reserve0Virtual / reserve1Virtual) oracle price

    struct TickInfo {
        bool initialized;
        // fee growth on the _other_ side of this tick (relative to the current tick)
        // only has relative meaning, not absolute — the value depends on when the tick is initialized
        FixedPoint.uq112x112 feeGrowthOutside0;
        FixedPoint.uq112x112 feeGrowthOutside1;
        // seconds spent on the _other_ side of this tick (relative to the current tick)
        // only has relative meaning, not absolute — the value depends on when the tick is initialized
        uint32 secondsOutside;
        // amount of token1 added when ticks are crossed from left to right
        // (i.e. as the (reserve1Virtual / reserve0Virtual) price goes up), for each fee vote
        int112[NUM_FEE_OPTIONS] token1VirtualDeltas;
    }
    mapping(int16 => TickInfo) public tickInfos;

    struct Position {
        // amount of liquidity (sqrt(amount0 * amount1))
        uint112 liquidity;
        // cumulative fee growth per unit of liquidity as of the last modification
        FixedPoint.uq112x112 feeGrowthInside0Last;
        FixedPoint.uq112x112 feeGrowthInside1Last;
    }
    mapping(bytes32 => Position) public positions;

    // accumulated fees per unit of liquidity
    FixedPoint.uq112x112 public feeGrowthGlobal0;
    FixedPoint.uq112x112 public feeGrowthGlobal1;

    // accumulated protocol fees
    uint112 public feeToFees0;
    uint112 public feeToFees1;

    uint256 public unlocked = 1;
    modifier lock() {
        require(unlocked == 1, 'UniswapV3: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    function _getPosition(
        address owner,
        int16 tickLower,
        int16 tickUpper,
        uint8 feeVote
    ) private view returns (Position storage position) {
        position = positions[keccak256(abi.encodePacked(owner, tickLower, tickUpper, feeVote))];
    }

    // check for one-time initialization
    function isInitialized() public view override returns (bool) {
        return reserve0Virtual > 0; // sufficient check
    }

    // find the median fee vote, and return the fee in bips
    function getFee() public view override returns (uint16 fee) {
        uint256 liquidityVirtualVotesCumulative;
        // load all virtual supplies into memory
        uint256[NUM_FEE_OPTIONS] memory liquidityVirtualVotes_ = [
            uint256(liquidityVirtualVotes[0]),
            liquidityVirtualVotes[1],
            liquidityVirtualVotes[2],
            liquidityVirtualVotes[3],
            liquidityVirtualVotes[4],
            liquidityVirtualVotes[5]
        ];
        uint256 threshold = (uint256(liquidityVirtualVotes_[0]) +
            liquidityVirtualVotes_[1] +
            liquidityVirtualVotes_[2] +
            liquidityVirtualVotes_[3] +
            liquidityVirtualVotes_[4] +
            liquidityVirtualVotes_[5]) / 2;
        for (uint8 feeVoteIndex = 0; feeVoteIndex < NUM_FEE_OPTIONS - 1; feeVoteIndex++) {
            liquidityVirtualVotesCumulative += liquidityVirtualVotes_[feeVoteIndex];
            if (liquidityVirtualVotesCumulative >= threshold) {
                return FEE_OPTIONS(feeVoteIndex);
            }
        }
        return FEE_OPTIONS(NUM_FEE_OPTIONS - 1);
    }

    // gets fee growth between two ticks
    // this only has relative meaning, not absolute
    function _getFeeGrowthBelow(int16 tick, TickInfo storage tickInfo)
        private
        view
        returns (FixedPoint.uq112x112 memory feeGrowthBelow0, FixedPoint.uq112x112 memory feeGrowthBelow1)
    {
        // tick is above the current tick, meaning growth outside represents growth above, not below
        if (tick > tickCurrent) {
            feeGrowthBelow0 = feeGrowthGlobal0.sub(tickInfo.feeGrowthOutside0);
            feeGrowthBelow1 = feeGrowthGlobal1.sub(tickInfo.feeGrowthOutside1);
        } else {
            feeGrowthBelow0 = tickInfo.feeGrowthOutside0;
            feeGrowthBelow1 = tickInfo.feeGrowthOutside1;
        }
    }

    function _getFeeGrowthAbove(int16 tick, TickInfo storage tickInfo)
        private
        view
        returns (FixedPoint.uq112x112 memory feeGrowthAbove0, FixedPoint.uq112x112 memory feeGrowthAbove1)
    {
        // tick is at or below the current tick, meaning growth outside represents growth below, not above
        if (tick <= tickCurrent) {
            feeGrowthAbove0 = feeGrowthGlobal0.sub(tickInfo.feeGrowthOutside0);
            feeGrowthAbove1 = feeGrowthGlobal1.sub(tickInfo.feeGrowthOutside1);
        } else {
            feeGrowthAbove0 = tickInfo.feeGrowthOutside0;
            feeGrowthAbove1 = tickInfo.feeGrowthOutside1;
        }
    }

    function _getFeeGrowthInside(
        int16 tickLower,
        int16 tickUpper,
        TickInfo storage tickInfoLower,
        TickInfo storage tickInfoUpper
    )
        private
        view
        returns (FixedPoint.uq112x112 memory feeGrowthInside0, FixedPoint.uq112x112 memory feeGrowthInside1)
    {
        (FixedPoint.uq112x112 memory feeGrowthBelow0, FixedPoint.uq112x112 memory feeGrowthBelow1) = _getFeeGrowthBelow(
            tickLower,
            tickInfoLower
        );
        (FixedPoint.uq112x112 memory feeGrowthAbove0, FixedPoint.uq112x112 memory feeGrowthAbove1) = _getFeeGrowthAbove(
            tickUpper,
            tickInfoUpper
        );
        feeGrowthInside0 = feeGrowthGlobal0.sub(feeGrowthBelow0).sub(feeGrowthAbove0);
        feeGrowthInside1 = feeGrowthGlobal1.sub(feeGrowthBelow1).sub(feeGrowthAbove1);
    }

    // given a price and a liquidity amount, return the value of that liquidity at the price
    // note: this can be imprecise for 3 reasons:
    // 1: because it uses sqrt, which can be lossy up to 40 bits
    // 2: regardless of the lossiness of sqrt, amount1 may still be rounded from its actual value
    // 3: regardless of the lossiness of amount1, amount0 may still be rounded from its actual value
    // this means that the amounts may both be slightly inaccurate _and_ not return the exact ratio of the passed price
    function getValueAtPrice(FixedPoint.uq112x112 memory price, int112 liquidity)
        public
        pure
        returns (int112 amount0, int112 amount1)
    {
        if (liquidity == 0) return (0, 0);

        uint8 safeShiftBits = ((255 - BitMath.mostSignificantBit(price._x)) / 2) * 2;
        uint256 priceScaled = uint256(price._x) << safeShiftBits; // price * 2**safeShiftBits

        uint256 priceScaledRoot = Babylonian.sqrt(uint256(price._x) << safeShiftBits); // sqrt(priceScaled)
        uint256 scaleFactor = uint256(1) << (56 + safeShiftBits / 2); // compensate for q112 and shifted bits under root

        // calculate amount0 := liquidity / sqrt(price) and amount1 := liquidity * sqrt(price),
        // rounding down when liquidity is <0, i.e. being removed, and up when liquidity is >0, i.e. being added
        if (liquidity < 0) {
            // liquidity must be cast as a uint112 for proper overflow handling if liquidity := type(int112).min
            amount0 = FullMath.mulDiv(uint112(-liquidity), scaleFactor, priceScaledRoot).toInt112();
            amount1 = FullMath.mulDiv(uint112(-liquidity), priceScaledRoot, scaleFactor).toInt112();
            amount0 *= -1;
            amount1 *= -1;
        } else {
            if (priceScaledRoot**2 < priceScaled) priceScaledRoot++; // round priceScaledRoot up
            amount0 = PriceMath.mulDivRoundingUp(uint256(liquidity), scaleFactor, priceScaledRoot).toInt112();
            amount1 = PriceMath.mulDivRoundingUp(uint256(liquidity), priceScaledRoot, scaleFactor).toInt112();
        }
    }

    constructor(
        address _factory,
        address _token0,
        address _token1
    ) public {
        factory = _factory;
        token0 = _token0;
        token1 = _token1;
        // initialize min and max ticks
        TickInfo storage tickInfo = tickInfos[TickMath.MIN_TICK];
        tickInfo.initialized = true;
        tickInfo = tickInfos[TickMath.MAX_TICK];
        tickInfo.initialized = true;
    }

    // returns the block timestamp % 2**32.
    // the timestamp is truncated to 32 bits because the pair only ever uses it for relative timestamp computations.
    // overridden for tests.
    function _blockTimestamp() internal view virtual returns (uint32) {
        return uint32(block.timestamp); // truncation is desired
    }

    // update reserves and, on the first interaction per block, price accumulators
    function _update() private {
        uint32 blockTimestamp = _blockTimestamp();
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired
        if (timeElapsed > 0) {
            (price0CumulativeLast, price1CumulativeLast) = getCumulativePrices();
            feeLast = getFee();
            blockTimestampLast = blockTimestamp;
        }
    }

    function setFeeTo(address feeTo_) external override {
        require(
            msg.sender == IUniswapV3Factory(factory).feeToSetter(),
            'UniswapV3Pair::setFeeTo: caller not feeToSetter'
        );
        feeTo = feeTo_;
    }

    // the reason this can't _just_ burn but needs to mint is because otherwise it would incentivize bad starting prices
    function initialize(
        uint112 amount0,
        uint112 amount1,
        int16 tick,
        uint8 feeVote
    ) external override lock returns (uint112 liquidity) {
        require(isInitialized() == false, 'UniswapV3: ALREADY_INITIALIZED');
        require(amount0 >= TOKEN_MIN, 'UniswapV3: AMOUNT_0_TOO_SMALL');
        require(amount1 >= TOKEN_MIN, 'UniswapV3: AMOUNT_1_TOO_SMALL');
        require(tick >= TickMath.MIN_TICK, 'UniswapV3: TICK_TOO_SMALL');
        require(tick < TickMath.MAX_TICK, 'UniswapV3: TICK_TOO_LARGE');

        // ensure the tick witness is correct
        FixedPoint.uq112x112 memory price = FixedPoint.fraction(amount1, amount0);
        require(TickMath.getRatioAtTick(tick)._x <= price._x, 'UniswapV3: STARTING_TICK_TOO_LARGE');
        require(TickMath.getRatioAtTick(tick + 1)._x > price._x, 'UniswapV3: STARTING_TICK_TOO_SMALL');

        // ensure that a minimum amount of liquidity will be generated
        liquidity = uint112(Babylonian.sqrt(uint256(amount0) * amount1));
        require(liquidity >= LIQUIDITY_MIN, 'UniswapV3: LIQUIDITY_TOO_SMALL');

        // take the tokens
        TransferHelper.safeTransferFrom(token0, msg.sender, address(this), amount0);
        TransferHelper.safeTransferFrom(token1, msg.sender, address(this), amount1);

        // initialize reserves and oracle timestamp
        reserve0Virtual = amount0;
        reserve1Virtual = amount1;
        blockTimestampLast = _blockTimestamp();

        // initialize liquidityVirtualVotes (note that this votes indelibly with the burned liquidity)
        liquidityVirtualVotes[feeVote] = liquidity;

        // initialize tick and fee
        tickCurrent = tick;
        feeLast = FEE_OPTIONS(feeVote);

        // set the permanent LIQUIDITY_MIN position
        Position storage position = _getPosition(address(0), TickMath.MIN_TICK, TickMath.MAX_TICK, feeVote);
        position.liquidity = LIQUIDITY_MIN;
        emit PositionSet(address(0), TickMath.MIN_TICK, TickMath.MAX_TICK, feeVote, int112(LIQUIDITY_MIN));

        // set the user's position if necessary
        if (liquidity > LIQUIDITY_MIN) {
            position = _getPosition(msg.sender, TickMath.MIN_TICK, TickMath.MAX_TICK, feeVote);
            position.liquidity = liquidity - LIQUIDITY_MIN;
            emit PositionSet(
                msg.sender,
                TickMath.MIN_TICK,
                TickMath.MAX_TICK,
                feeVote,
                int112(liquidity - LIQUIDITY_MIN)
            );
        }

        emit Initialized(amount0, amount1, tick, feeVote);
    }

    function _initializeTick(int16 tick) private returns (TickInfo storage tickInfo) {
        tickInfo = tickInfos[tick];
        if (tickInfo.initialized == false) {
            // by convention, we assume that all growth before a tick was initialized happened _below_ the tick
            if (tick <= tickCurrent) {
                tickInfo.feeGrowthOutside0 = feeGrowthGlobal0;
                tickInfo.feeGrowthOutside1 = feeGrowthGlobal1;
                tickInfo.secondsOutside = _blockTimestamp();
            }
            tickInfo.initialized = true;
        }
    }

    // note: this function can cause the price to change
    function updateReservesAndLiquidity(int112 liquidityDelta, uint16 feeVote)
        internal
        returns (int112 amount0, int112 amount1)
    {
        FixedPoint.uq112x112 memory price = FixedPoint.fraction(reserve1Virtual, reserve0Virtual);
        (amount0, amount1) = getValueAtPrice(price, liquidityDelta);

        // update reserves
        // TODO in theory the price doesn't change, so there's no need to update the oracle or current tick,
        // but in practice it can because of rounding, leading to two considerations:
        // 1) we still need to round the "right" way according to the sign of liquidityDelta (as in getValueAtPrice)
        // 2) we could _probably_ still push the price in whatever direction we want, (e.g. away from the closer tick?)
        // 3) should we update the oracle here?
        reserve0Virtual = reserve0Virtual.addi(amount0).toUint112();
        reserve1Virtual = reserve1Virtual.addi(amount1).toUint112();
        if (liquidityDelta < 0) {
            require(reserve0Virtual >= TOKEN_MIN, 'UniswapV3: RESERVE_0_TOO_SMALL');
            require(reserve1Virtual >= TOKEN_MIN, 'UniswapV3: RESERVE_1_TOO_SMALL');
        }
        // TODO work on this
        price = FixedPoint.fraction(reserve1Virtual, reserve0Virtual);
        require(TickMath.getRatioAtTick(tickCurrent)._x <= price._x, 'UniswapV3: PRICE_EXCEEDS_LOWER_BOUND');
        require(TickMath.getRatioAtTick(tickCurrent + 1)._x > price._x, 'UniswapV3: PRICE_EXCEEDS_UPPER_BOUND');

        liquidityVirtualVotes[feeVote] = liquidityVirtualVotes[feeVote].addi(liquidityDelta).toUint112();
    }

    // add or remove a specified amount of liquidity from a specified range, and/or change feeVote for that range
    // also sync a position and return accumulated fees from it to user as tokens
    // liquidityDelta is sqrt(reserve0Virtual * reserve1Virtual), so does not incorporate fees
    function setPosition(
        int16 tickLower,
        int16 tickUpper,
        uint8 feeVote,
        int112 liquidityDelta
    ) external lock returns (int112 amount0, int112 amount1) {
        require(isInitialized(), 'UniswapV3: NOT_INITIALIZED');
        require(tickLower < tickUpper, 'UniswapV3: TICK_ORDER');
        require(tickLower >= TickMath.MIN_TICK, 'UniswapV3: LOWER_TICK');
        require(tickUpper <= TickMath.MAX_TICK, 'UniswapV3: UPPER_TICK');
        _update();

        TickInfo storage tickInfoLower = _initializeTick(tickLower); // initialize tick idempotently
        TickInfo storage tickInfoUpper = _initializeTick(tickUpper); // initialize tick idempotently

        Position storage position = _getPosition(msg.sender, tickLower, tickUpper, feeVote);

        {
            (
                FixedPoint.uq112x112 memory feeGrowthInside0,
                FixedPoint.uq112x112 memory feeGrowthInside1
            ) = _getFeeGrowthInside(tickLower, tickUpper, tickInfoLower, tickInfoUpper);

            // TODO there was a major issue here with the first liquidity provision, need to make sure this is correct
            // TODO credit protocol fees here? (1/6 of each of token0/token1 fees)
            // check if this condition has accrued any untracked fees and credit them to the caller
            if (position.liquidity > 0) {
                if (feeGrowthInside0._x > position.feeGrowthInside0Last._x) {
                    amount0 = -FullMath
                        .mulDiv(
                        feeGrowthInside0._x - position.feeGrowthInside0Last._x,
                        position
                            .liquidity,
                        uint256(1) << 112
                    )
                        .toInt112();
                }
                if (feeGrowthInside1._x > position.feeGrowthInside1Last._x) {
                    amount1 = -FullMath
                        .mulDiv(
                        feeGrowthInside1._x - position.feeGrowthInside1Last._x,
                        position
                            .liquidity,
                        uint256(1) << 112
                    )
                        .toInt112();
                }
            }
            position.feeGrowthInside0Last = feeGrowthInside0;
            position.feeGrowthInside1Last = feeGrowthInside1;
            position.liquidity = position.liquidity.addi(liquidityDelta).toUint112();
        }

        // calculate how much the specified liquidity delta is worth at the lower and upper ticks
        // amount0Lower :> amount0Upper
        // amount1Upper :> amount1Lower
        (int112 amount0Lower, int112 amount1Lower) = getValueAtPrice(
            TickMath.getRatioAtTick(tickLower),
            liquidityDelta
        );
        (int112 amount0Upper, int112 amount1Upper) = getValueAtPrice(
            TickMath.getRatioAtTick(tickUpper),
            liquidityDelta
        );

        // regardless of current price, when lower tick is crossed from left to right, amount1Lower should be added
        if (tickLower > TickMath.MIN_TICK) {
            tickInfoLower.token1VirtualDeltas[feeVote] = tickInfoLower.token1VirtualDeltas[feeVote]
                .add(amount1Lower)
                .toInt112();
        }
        // regardless of current price, when upper tick is crossed from left to right amount1Upper should be removed
        if (tickUpper < TickMath.MAX_TICK) {
            tickInfoUpper.token1VirtualDeltas[feeVote] = tickInfoUpper.token1VirtualDeltas[feeVote]
                .sub(amount1Upper)
                .toInt112();
        }

        // the current price is below the passed range, so the liquidity can only become in range by crossing from left
        // to right, at which point we'll need _more_ token0 (it's becoming more valuable) so the user must provide it
        if (tickCurrent < tickLower) {
            amount0 = amount0.add(amount0Lower.sub(amount0Upper)).toInt112();
        } else if (tickCurrent < tickUpper) {
            // the current price is inside the passed range
            (int112 amount0Current, int112 amount1Current) = updateReservesAndLiquidity(liquidityDelta, feeVote);

            // charge the user whatever is required to cover their position
            amount0 = amount0.add(amount0Current.sub(amount0Upper)).toInt112();
            amount1 = amount1.add(amount1Current.sub(amount1Lower)).toInt112();
        } else {
            // the current price is above the passed range, so liquidity can only become in range by crossing from right
            // to left, at which point we need _more_ token1 (it's becoming more valuable) so the user must provide it
            amount1 = amount1.add(amount1Upper.sub(amount1Lower)).toInt112();
        }

        if (amount0 > 0) {
            TransferHelper.safeTransferFrom(token0, msg.sender, address(this), uint256(amount0));
        } else if (amount0 < 0) {
            TransferHelper.safeTransfer(token0, msg.sender, uint256(-amount0));
        }
        if (amount1 > 0) {
            TransferHelper.safeTransferFrom(token1, msg.sender, address(this), uint256(amount1));
        } else if (amount1 < 0) {
            TransferHelper.safeTransfer(token1, msg.sender, uint256(-amount1));
        }
    }

    struct SwapParams {
        // whether the swap is from token 0 to 1, or 1 for 0
        bool zeroForOne;
        // how much is being swapped in
        uint112 amountIn;
        // the recipient address
        address to;
        // any data that should be sent to the address with the call
        bytes data;
    }

    // the top level state of the swap, the results of which are recorded in storage at the end
    struct SwapState {
        // the virtual reserves of token0
        uint112 reserve0Virtual;
        // the virtual reserves of token1
        uint112 reserve1Virtual;
        // the amount in remaining to be swapped of the input asset
        uint112 amountInRemaining;
        // the current tick
        int16 tick;
        // the floor for the fee, used to prevent sandwiching attacks
        uint16 feeFloor;
        // the global fee growth of token0
        FixedPoint.uq112x112 feeGrowthGlobal0;
        // the global fee growth of token1
        FixedPoint.uq112x112 feeGrowthGlobal1;
    }

    struct StepComputations {
        // price for the tick (1/0)
        FixedPoint.uq112x112 nextPrice;
        // how much is being swapped in in this step
        uint112 amountIn;
        // how much is being swapped out in the current step
        uint112 amountOut;
        // the fee that will be paid in this step
        uint16 fee;
    }

    function _swap(SwapParams memory params) internal returns (uint112 amountOut) {
        require(params.amountIn > 0, 'UniswapV3: INSUFFICIENT_INPUT_AMOUNT');
        _update(); // update the oracle and feeLast

        SwapState memory state = SwapState({
            reserve0Virtual: reserve0Virtual,
            reserve1Virtual: reserve1Virtual,
            amountInRemaining: params.amountIn,
            tick: tickCurrent,
            feeFloor: feeLast,
            feeGrowthGlobal0: feeGrowthGlobal0,
            feeGrowthGlobal1: feeGrowthGlobal1
        });

        // TODO here and the other place we check state.amountInRemaining > 0, we should _actually_ be checking
        // that state.amountInRemaining > *whatever input amount, discounted by the appropriate fee,
        // leads to 1 wei of effective input*, while still taking the whole amount and accounting correctly
        // this will probably be complicated because fees can change every tick, gotta think about this...
        while (state.amountInRemaining > 0) {
            StepComputations memory step;
            // get the price for the next tick we're moving toward
            step.nextPrice = params.zeroForOne
                ? TickMath.getRatioAtTick(state.tick)
                : TickMath.getRatioAtTick(state.tick + 1);

            // protect liquidity providers by adjusting the fee only if the current fee is greater than the stored fee
            step.fee = uint16(Math.max(state.feeFloor, getFee()));

            // compute the ~minimum amount of input token required s.t. the price equals or exceeds the target price
            // _after_ computing the corresponding output amount according to x * y = k, given the current fee
            (uint112 amountInRequiredForShift, uint112 amountOutMax) = PriceMath.getInputToRatio(
                state.reserve0Virtual,
                state.reserve1Virtual,
                step.fee,
                step.nextPrice,
                params.zeroForOne
            );

            // TODO ensure that there's no off-by-one error here while transitioning ticks
            if (amountInRequiredForShift > 0) {
                // either trade fully to the next tick, or only as much as we need to
                step.amountIn = Math.min(amountInRequiredForShift, state.amountInRemaining).toUint112();

                uint112 amountInLessFee = uint112(
                    (uint256(step.amountIn) * (PriceMath.LP_FEE_BASE - step.fee)) / PriceMath.LP_FEE_BASE
                );
                {
                    uint112 feePaid = step.amountIn - amountInLessFee;

                    // take the protocol fee if it's on
                    // TODO is this the right approach?
                    if (feeTo != address(0)) {
                        uint112 feeToFee = feePaid / 6;
                        // increment feeToFees monotonically, while being cognizant of overflow
                        if (params.zeroForOne) feeToFees0 = uint112(Math.max(feeToFees0 + feeToFee, feeToFees0));
                        else feeToFees1 = uint112(Math.max(feeToFees1 + feeToFee, feeToFees1));
                        feePaid -= feeToFee;
                    }

                    // update the global fee tracker
                    // TODO is this correct/is there a less lossy way to do this?
                    FixedPoint.uq112x112 memory feeGrowthGlobalDelta = FixedPoint.fraction(
                        feePaid,
                        uint112(Babylonian.sqrt(uint256(state.reserve0Virtual) * state.reserve1Virtual))
                    );
                    if (params.zeroForOne) state.feeGrowthGlobal0 = state.feeGrowthGlobal0.add(feeGrowthGlobalDelta);
                    else state.feeGrowthGlobal1 = state.feeGrowthGlobal1.add(feeGrowthGlobalDelta);
                }

                // calculate the owed output amount on the input amount discounted by the fee paid
                step.amountOut = params.zeroForOne
                    ? PriceMath.getAmountOut(state.reserve0Virtual, state.reserve1Virtual, amountInLessFee)
                    : PriceMath.getAmountOut(state.reserve1Virtual, state.reserve0Virtual, amountInLessFee);

                // in some cases this output amount can be marginally too high, fix this
                step.amountOut = uint112(Math.min(step.amountOut, amountOutMax));

                if (params.zeroForOne) {
                    state.reserve0Virtual = state.reserve0Virtual.add(amountInLessFee).toUint112();
                    state.reserve1Virtual = state.reserve1Virtual.sub(step.amountOut).toUint112();
                    require(state.reserve1Virtual >= TOKEN_MIN, 'UniswapV3: RESERVE_1_TOO_SMALL');
                } else {
                    state.reserve0Virtual = state.reserve0Virtual.sub(step.amountOut).toUint112();
                    require(state.reserve0Virtual >= TOKEN_MIN, 'UniswapV3: RESERVE_0_TOO_SMALL');
                    state.reserve1Virtual = state.reserve1Virtual.add(amountInLessFee).toUint112();
                }

                state.amountInRemaining -= step.amountIn;
                amountOut = (uint256(amountOut) + step.amountOut).toUint112();
            }

            // we have to shift to the next tick if either of two conditions are true:
            // 1) a positive input amount remains (TODO, a positive _effective_ input amount (at the next tick?))
            // 2) if we're moving right and the price is exactly on the target tick
            if (
                state.amountInRemaining > 0 ||
                (params.zeroForOne == false &&
                    FixedPoint.fraction(state.reserve1Virtual, state.reserve0Virtual)._x == step.nextPrice._x)
            ) {
                TickInfo storage tickInfo = tickInfos[state.tick];

                // if the tick is initialized, we must update it
                if (tickInfo.initialized) {
                    // update tick info
                    tickInfo.feeGrowthOutside0 = feeGrowthGlobal0.sub(tickInfo.feeGrowthOutside0);
                    tickInfo.feeGrowthOutside1 = feeGrowthGlobal1.sub(tickInfo.feeGrowthOutside1);
                    tickInfo.secondsOutside = _blockTimestamp() - tickInfo.secondsOutside; // overflow is desired

                    int256 token1VirtualDelta; // will not exceed int120
                    // loop through each entry in token1VirtualDeltas
                    for (uint8 i = 0; i < NUM_FEE_OPTIONS; i++) {
                        int256 delta1I = tickInfo.token1VirtualDeltas[i];

                        // increment the _net_ token1VirtualDelta counter;
                        token1VirtualDelta += delta1I;

                        // calculate the liquidityDelta in order to update liquidityVirtualVotes
                        // TODO it is possible to squeeze out a bit more precision here by:
                        // a) summing total negative and positive token1VirtualDeltas
                        // b) calculating the total negative and positive liquidityDelta
                        // c) allocating these deltas proportionally across virtualSupplies according to sign
                        // TODO make sure there's not an attack here by repeatedly crossing ticks + forcing rounding
                        // compute update to liquidityVirtualVotes, for fee voting purposes
                        int256 delta0I = delta1I << (112 / step.nextPrice._x);
                        int256 liquidityDelta = int256(Babylonian.sqrt(uint256(delta1I * delta0I)));
                        if (delta1I < 0 || delta0I < 0) liquidityDelta *= -1;

                        if (params.zeroForOne) {
                            // subi because we're moving from right to left
                            liquidityVirtualVotes[i] = liquidityVirtualVotes[i].subi(liquidityDelta).toUint112();
                        } else {
                            liquidityVirtualVotes[i] = liquidityVirtualVotes[i].addi(liquidityDelta).toUint112();
                        }
                    }

                    // calculate the net token1VirtualDelta
                    // TODO we probably have to round conditionally here, up or down depending on direction and sign
                    int256 token0VirtualDelta = token1VirtualDelta << (112 / step.nextPrice._x);

                    // TODO the price can change here because of rounding error in calculating token0VirtualDelta
                    // it's very important that after adding/removing these reserves, we maintain the property that
                    // adding 1 wei of effective input and subtracting the corresponding output amount still
                    // is guaranteed to push us past the target price.
                    // it's important because this is what lets us be confident that we can actually bump the tick
                    // to the next value, as we're guaranteed that (since enough input amount remains to at least
                    // add 1 more wei of effective input), the price will end up past the target.
                    // it's pretty trivial to round s.t. the price consistently moves in the same direction we're going
                    // (if it has to move at all), but it's not immediately clear that this will lead
                    // to our desired property always holding
                    if (params.zeroForOne) {
                        // subi because we're moving from right to left
                        state.reserve0Virtual = state.reserve0Virtual.subi(token0VirtualDelta).toUint112();
                        state.reserve1Virtual = state.reserve1Virtual.subi(token1VirtualDelta).toUint112();
                        if (token0VirtualDelta > 0 || token1VirtualDelta > 0) {
                            require(state.reserve0Virtual >= TOKEN_MIN, 'UniswapV3: RESERVE_0_TOO_SMALL');
                            require(state.reserve1Virtual >= TOKEN_MIN, 'UniswapV3: RESERVE_1_TOO_SMALL');
                        }
                    } else {
                        state.reserve0Virtual = state.reserve0Virtual.addi(token0VirtualDelta).toUint112();
                        state.reserve1Virtual = state.reserve1Virtual.addi(token1VirtualDelta).toUint112();
                        if (token0VirtualDelta < 0 || token1VirtualDelta < 0) {
                            require(state.reserve0Virtual >= TOKEN_MIN, 'UniswapV3: RESERVE_0_TOO_SMALL');
                            require(state.reserve1Virtual >= TOKEN_MIN, 'UniswapV3: RESERVE_1_TOO_SMALL');
                        }
                    }
                }

                if (params.zeroForOne) {
                    state.tick--;
                    require(state.tick >= TickMath.MIN_TICK, 'UniswapV3: TICK_TOO_SMALL');
                } else {
                    state.tick++;
                    require(state.tick < TickMath.MAX_TICK, 'UniswapV3: TICK_TOO_LARGE');
                }
            }
        }

        tickCurrent = state.tick;
        reserve0Virtual = state.reserve0Virtual;
        reserve1Virtual = state.reserve1Virtual;
        feeGrowthGlobal0 = state.feeGrowthGlobal0;
        feeGrowthGlobal1 = state.feeGrowthGlobal1;

        // this is different than v2
        TransferHelper.safeTransfer(params.zeroForOne ? token1 : token0, params.to, amountOut);
        if (params.data.length > 0) {
            params.zeroForOne
                ? IUniswapV3Callee(params.to).swap0For1Callback(msg.sender, amountOut, params.data)
                : IUniswapV3Callee(params.to).swap1For0Callback(msg.sender, amountOut, params.data);
        }
        TransferHelper.safeTransferFrom(
            params.zeroForOne ? token0 : token1,
            msg.sender,
            address(this),
            params.amountIn
        );
    }

    // move from right to left (token 1 is becoming more valuable)
    function swap0For1(
        uint112 amount0In,
        address to,
        bytes calldata data
    ) external override lock returns (uint112 amount1Out) {
        SwapParams memory params = SwapParams({zeroForOne: true, amountIn: amount0In, to: to, data: data});
        return _swap(params);
    }

    // move from left to right (token 0 is becoming more valuable)
    function swap1For0(
        uint112 amount1In,
        address to,
        bytes calldata data
    ) external override lock returns (uint112 amount0Out) {
        SwapParams memory params = SwapParams({zeroForOne: false, amountIn: amount1In, to: to, data: data});
        return _swap(params);
    }

    // helper for reading the cumulative price as of the current block
    function getCumulativePrices() public view override returns (uint256 price0Cumulative, uint256 price1Cumulative) {
        uint32 blockTimestamp = _blockTimestamp();

        if (blockTimestampLast != blockTimestamp) {
            uint32 timeElapsed = blockTimestamp - blockTimestampLast;
            price0Cumulative =
                price0CumulativeLast + // overflow is desired
                FixedPoint.fraction(reserve1Virtual, reserve0Virtual).mul(timeElapsed)._x;
            price1Cumulative =
                price1CumulativeLast + // overflow is desired
                FixedPoint.fraction(reserve0Virtual, reserve1Virtual).mul(timeElapsed)._x;
        } else {
            price0Cumulative = price0CumulativeLast;
            price1Cumulative = price1CumulativeLast;
        }
    }

    function recover(
        address token,
        address to,
        uint256 amount
    ) external override {
        require(
            msg.sender == IUniswapV3Factory(factory).feeToSetter(),
            'UniswapV3Pair::recover: caller not feeToSetter'
        );

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
