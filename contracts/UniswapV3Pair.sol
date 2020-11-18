// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.12;
pragma experimental ABIEncoderV2;

import '@uniswap/lib/contracts/libraries/FixedPoint.sol';
import '@uniswap/lib/contracts/libraries/FullMath.sol';
import '@uniswap/lib/contracts/libraries/Babylonian.sol';
import '@uniswap/lib/contracts/libraries/TransferHelper.sol';
import '@uniswap/lib/contracts/libraries/BitMath.sol';

import '@openzeppelin/contracts/math/Math.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/math/SignedSafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import './libraries/SafeCast.sol';
import './libraries/FixedPointExtra.sol';
import './libraries/MixedSafeMath.sol';
import './libraries/TickMath.sol';
import './libraries/PriceMath.sol';

import './interfaces/IUniswapV3Pair.sol';
import './interfaces/IUniswapV3Factory.sol';
import './interfaces/IUniswapV3Callee.sol';

contract UniswapV3Pair is IUniswapV3Pair {
    using SafeMath for uint112;
    using SafeMath for uint256;
    using SignedSafeMath for int112;
    using SignedSafeMath for int256;
    using SafeCast for int256;
    using SafeCast for uint256;
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

    address public immutable override factory;
    address public immutable override token0;
    address public immutable override token1;

    // TODO figure out the best way to pack these state variables
    address public override feeTo;

    // meant to be accessed via getPriceCumulative
    FixedPoint.uq144x112 private price0CumulativeLast; // cumulative (token1 / token0) oracle price
    FixedPoint.uq144x112 private price1CumulativeLast; // cumulative (token0 / token1) oracle price
    uint32 public override blockTimestampLast;

    // the current fee (gets set by the first swap or setPosition/initialize in a block)
    // this is stored to protect liquidity providers from add/swap/remove sandwiching attacks
    uint16 public override feeLast;

    uint112[NUM_FEE_OPTIONS] public override liquidityCurrent; // all in-range liquidity, segmented across fee options
    FixedPoint.uq112x112 public override priceCurrent; // (token1 / token0) price
    int16 public override tickCurrent; // first tick at or below priceCurrent

    // fee growth per unit of liquidity
    FixedPoint.uq144x112 public override feeGrowthGlobal0;
    FixedPoint.uq144x112 public override feeGrowthGlobal1;

    // accumulated protocol fees
    // there is no value in packing these values, since we only ever set one at a time
    uint256 public override feeToFees0;
    uint256 public override feeToFees1;

    struct TickInfo {
        // the number of positions that are active using this tick as a lower or upper tick
        // can technically grow to 2^160 addresses * 16k ticks * 6 fee options = ~177 bits
        uint256 numPositions;
        // fee growth per unit of liquidity on the _other_ side of this tick (relative to the current tick)
        // only has relative meaning, not absolute — the value depends on when the tick is initialized
        FixedPoint.uq144x112 feeGrowthOutside0;
        FixedPoint.uq144x112 feeGrowthOutside1;
        // seconds spent on the _other_ side of this tick (relative to the current tick)
        // only has relative meaning, not absolute — the value depends on when the tick is initialized
        uint32 secondsOutside;
        // amount of liquidity added (subtracted) when ticks are crossed from left to right (right to left),
        // i.e. as the price goes up (down), for each fee vote
        int112[NUM_FEE_OPTIONS] liquidityDelta;
    }
    mapping(int16 => TickInfo) public tickInfos;

    struct Position {
        uint112 liquidity;
        // fee growth per unit of liquidity as of the last modification
        FixedPoint.uq144x112 feeGrowthInside0Last;
        FixedPoint.uq144x112 feeGrowthInside1Last;
    }
    mapping(bytes32 => Position) public positions;

    uint256 private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, 'UniswapV3Pair::lock: reentrancy prohibited');
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

    function _getFeeGrowthBelow(int16 tick, TickInfo storage tickInfo)
        private
        view
        returns (FixedPoint.uq144x112 memory feeGrowthBelow0, FixedPoint.uq144x112 memory feeGrowthBelow1)
    {
        // should never be called on uninitialized ticks
        assert(tickInfo.numPositions > 0);
        // tick is above the current tick, meaning growth outside represents growth above, not below
        if (tick > tickCurrent) {
            feeGrowthBelow0 = FixedPoint.uq144x112(feeGrowthGlobal0._x - tickInfo.feeGrowthOutside0._x);
            feeGrowthBelow1 = FixedPoint.uq144x112(feeGrowthGlobal1._x - tickInfo.feeGrowthOutside1._x);
        } else {
            feeGrowthBelow0 = tickInfo.feeGrowthOutside0;
            feeGrowthBelow1 = tickInfo.feeGrowthOutside1;
        }
    }

    function _getFeeGrowthAbove(int16 tick, TickInfo storage tickInfo)
        private
        view
        returns (FixedPoint.uq144x112 memory feeGrowthAbove0, FixedPoint.uq144x112 memory feeGrowthAbove1)
    {
        // should never be called on uninitialized ticks
        assert(tickInfo.numPositions > 0);
        // tick is above current tick, meaning growth outside represents growth above
        if (tick > tickCurrent) {
            feeGrowthAbove0 = tickInfo.feeGrowthOutside0;
            feeGrowthAbove1 = tickInfo.feeGrowthOutside1;
        } else {
            feeGrowthAbove0 = FixedPoint.uq144x112(feeGrowthGlobal0._x - tickInfo.feeGrowthOutside0._x);
            feeGrowthAbove1 = FixedPoint.uq144x112(feeGrowthGlobal1._x - tickInfo.feeGrowthOutside1._x);
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
        returns (FixedPoint.uq144x112 memory feeGrowthInside0, FixedPoint.uq144x112 memory feeGrowthInside1)
    {
        (FixedPoint.uq144x112 memory feeGrowthBelow0, FixedPoint.uq144x112 memory feeGrowthBelow1) = _getFeeGrowthBelow(
            tickLower,
            tickInfoLower
        );
        (FixedPoint.uq144x112 memory feeGrowthAbove0, FixedPoint.uq144x112 memory feeGrowthAbove1) = _getFeeGrowthAbove(
            tickUpper,
            tickInfoUpper
        );
        feeGrowthInside0 = FixedPoint.uq144x112(feeGrowthGlobal0._x - feeGrowthBelow0._x - feeGrowthAbove0._x);
        feeGrowthInside1 = FixedPoint.uq144x112(feeGrowthGlobal1._x - feeGrowthBelow1._x - feeGrowthAbove1._x);
    }

    // TODO think about how we should prevent total in range liquidity from exceeding uint112
    function getLiquidity() public view override returns (uint112) {
        // load all liquidity into memory
        uint112[NUM_FEE_OPTIONS] memory _liquidityCurrent = [
            liquidityCurrent[0],
            liquidityCurrent[1],
            liquidityCurrent[2],
            liquidityCurrent[3],
            liquidityCurrent[4],
            liquidityCurrent[5]
        ];

        uint256 liquidity;
        for (uint8 feeVoteIndex = 0; feeVoteIndex < NUM_FEE_OPTIONS; feeVoteIndex++) {
            liquidity += _liquidityCurrent[feeVoteIndex];
        }

        return liquidity.toUint112();
    }

    // check for one-time initialization
    function isInitialized() public view override returns (bool) {
        return priceCurrent._x != 0; // sufficient check
    }

    // find the median fee vote, and return the fee in bips
    function getFee() public view override returns (uint16 fee) {
        // load all virtual supplies into memory
        uint112[NUM_FEE_OPTIONS] memory _liquidityCurrent = [
            liquidityCurrent[0],
            liquidityCurrent[1],
            liquidityCurrent[2],
            liquidityCurrent[3],
            liquidityCurrent[4],
            liquidityCurrent[5]
        ];

        uint256 threshold = (uint256(_liquidityCurrent[0]) +
            _liquidityCurrent[1] +
            _liquidityCurrent[2] +
            _liquidityCurrent[3] +
            _liquidityCurrent[4] +
            _liquidityCurrent[5]) / 2;

        uint256 liquidityCumulative;
        for (uint8 feeVoteIndex = 0; feeVoteIndex < NUM_FEE_OPTIONS - 1; feeVoteIndex++) {
            liquidityCumulative += _liquidityCurrent[feeVoteIndex];
            if (liquidityCumulative >= threshold) return FEE_OPTIONS(feeVoteIndex);
        }
        return FEE_OPTIONS(NUM_FEE_OPTIONS - 1);
    }

    // helper for reading the cumulative price as of the current block
    function getCumulativePrices()
        public
        view
        override
        returns (FixedPoint.uq144x112 memory price0Cumulative, FixedPoint.uq144x112 memory price1Cumulative)
    {
        require(isInitialized(), 'UniswapV3Pair::getCumulativePrices: pair not initialized');
        uint32 blockTimestamp = _blockTimestamp();

        if (blockTimestampLast != blockTimestamp) {
            // overflow desired in both of the following lines
            uint32 timeElapsed = blockTimestamp - blockTimestampLast;
            return (
                FixedPoint.uq144x112(price0CumulativeLast._x + priceCurrent.mul(timeElapsed)._x),
                FixedPoint.uq144x112(price1CumulativeLast._x + priceCurrent.reciprocal().mul(timeElapsed)._x)
            );
        }

        return (price0CumulativeLast, price1CumulativeLast);
    }

    function getVirtualReservesDeltaAtPrice(FixedPoint.uq112x112 memory price, int256 liquidity)
        public
        pure
        returns (int256, int256)
    {
        if (liquidity == 0) return (0, 0);

        // we want to round up when liquidity is >0, i.e. being added
        if (liquidity > 0) {
            (uint112 amount0, uint112 amount1) = PriceMath.getVirtualReservesAtPrice(price, uint256(liquidity), true);
            return (amount0, amount1);
        } else {
            // we want to round down when liquidity is <0, i.e. being removed
            (uint112 amount0, uint112 amount1) = PriceMath.getVirtualReservesAtPrice(price, uint256(-liquidity), false);
            return (-int256(amount0), -int256(amount1));
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
    }

    // returns the block timestamp % 2**32
    // the timestamp is truncated to 32 bits because the pair only ever uses it for relative timestamp computations
    // overridden for tests
    function _blockTimestamp() internal view virtual returns (uint32) {
        return uint32(block.timestamp); // truncation is desired
    }

    // on the first interaction per block, update the fee and oracle price accumulator
    function _update() private {
        uint32 blockTimestamp = _blockTimestamp();

        if (blockTimestampLast != blockTimestamp) {
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
        uint112 liquidity,
        int16 tick,
        uint8 feeVote
    ) external override lock {
        require(isInitialized() == false, 'UniswapV3Pair::initialize: pair already initialized');
        require(liquidity >= LIQUIDITY_MIN, 'UniswapV3Pair::initialize: insufficient liquidity');
        require(tick >= TickMath.MIN_TICK, 'UniswapV3Pair::initialize: tick must be greater than or equal to min tick');
        require(tick < TickMath.MAX_TICK, 'UniswapV3Pair::initialize: tick must be less than max tick');
        require(feeVote < NUM_FEE_OPTIONS, 'UniswapV3Pair::initialize: fee vote must be a valid option');

        FixedPoint.uq112x112 memory price = TickMath.getRatioAtTick(tick);

        // take the tokens
        (int256 amount0, int256 amount1) = PriceMath.getVirtualReservesAtPrice(price, liquidity, true);
        TransferHelper.safeTransferFrom(token0, msg.sender, address(this), uint256(amount0));
        TransferHelper.safeTransferFrom(token1, msg.sender, address(this), uint256(amount1));

        // initialize oracle timestamp and fee
        blockTimestampLast = _blockTimestamp();
        feeLast = FEE_OPTIONS(feeVote);

        // initialize liquidity, price, and tick (note that this votes indelibly with the burned liquidity)
        liquidityCurrent[feeVote] = liquidity;
        priceCurrent = price;
        tickCurrent = tick;

        // this is basically _setPosition for address 0
        TickInfo storage minTick = tickInfos[TickMath.MIN_TICK];
        TickInfo storage maxTick = tickInfos[TickMath.MAX_TICK];
        _initializeTick(TickMath.MIN_TICK, minTick);
        _initializeTick(TickMath.MAX_TICK, maxTick);

        // set the permanent LIQUIDITY_MIN position
        Position storage position = _getPosition(address(0), TickMath.MIN_TICK, TickMath.MAX_TICK, feeVote);
        position.liquidity = LIQUIDITY_MIN;
        // emit PositionSet(address(0), TickMath.MIN_TICK, TickMath.MAX_TICK, feeVote, int112(LIQUIDITY_MIN));

        // set the user's position if necessary
        if (liquidity > LIQUIDITY_MIN) {
            position = _getPosition(msg.sender, TickMath.MIN_TICK, TickMath.MAX_TICK, feeVote);
            position.liquidity = liquidity - LIQUIDITY_MIN;
            minTick.numPositions++;
            maxTick.numPositions++;
            // emit PositionSet(
            //     msg.sender,
            //     TickMath.MIN_TICK,
            //     TickMath.MAX_TICK,
            //     feeVote,
            //     (liquidity - LIQUIDITY_MIN).toInt112()
            // );
        }
        // emit Initialized(amount0, amount1, tick, feeVote);
    }

    function _initializeTick(int16 tick, TickInfo storage tickInfo) private {
        // by convention, we assume that all growth before a tick was initialized happened _below_ the tick
        if (tick <= tickCurrent) {
            tickInfo.feeGrowthOutside0 = feeGrowthGlobal0;
            tickInfo.feeGrowthOutside1 = feeGrowthGlobal1;
            tickInfo.secondsOutside = _blockTimestamp();
        }
        tickInfo.numPositions = 1;
    }

    struct SetPositionParams {
        int16 tickLower;
        int16 tickUpper;
        uint8 feeVote;
        int256 liquidityDelta;
    }

    function setPosition(
        int16 tickLower,
        int16 tickUpper,
        uint8 feeVote,
        int256 liquidityDelta
    ) external lock returns (int256 amount0, int256 amount1) {
        require(isInitialized(), 'UniswapV3Pair::setPosition: pair not initialized');
        require(tickLower < tickUpper, 'UniswapV3Pair::setPosition: tickLower must be less than tickUpper');
        require(tickLower >= TickMath.MIN_TICK, 'UniswapV3Pair::setPosition: tickLower cannot be less than min tick');
        require(
            tickUpper <= TickMath.MAX_TICK,
            'UniswapV3Pair::setPosition: tickUpper cannot be greater than max tick'
        );
        require(feeVote < NUM_FEE_OPTIONS, 'UniswapV3Pair::setPosition: fee vote must be a valid option');

        return
            _setPosition(
                SetPositionParams({
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    feeVote: feeVote,
                    liquidityDelta: liquidityDelta
                })
            );
    }

    // add or remove a specified amount of liquidity from a specified range, and/or change feeVote for that range
    // also sync a position and return accumulated fees from it to user as tokens
    // liquidityDelta is sqrt(reserve0Virtual * reserve1Virtual), so does not incorporate fees
    function _setPosition(SetPositionParams memory params) private returns (int256 amount0, int256 amount1) {
        _update();

        {
            // gather the storage pointers
            TickInfo storage tickInfoLower = tickInfos[params.tickLower];
            TickInfo storage tickInfoUpper = tickInfos[params.tickUpper];
            Position storage position = _getPosition(msg.sender, params.tickLower, params.tickUpper, params.feeVote);

            // if necessary, initialize both ticks and increment the position counter
            if (position.liquidity == 0 && params.liquidityDelta > 0) {
                if (tickInfoLower.numPositions == 0) _initializeTick(params.tickLower, tickInfoLower);
                else tickInfoLower.numPositions++;
                if (tickInfoUpper.numPositions == 0) _initializeTick(params.tickUpper, tickInfoUpper);
                else tickInfoUpper.numPositions++;
            }

            {
                (
                    FixedPoint.uq144x112 memory feeGrowthInside0,
                    FixedPoint.uq144x112 memory feeGrowthInside1
                ) = _getFeeGrowthInside(params.tickLower, params.tickUpper, tickInfoLower, tickInfoUpper);

                // check if this condition has accrued any untracked fees and credit them to the caller
                // TODO is this right?
                if (position.liquidity > 0) {
                    if (feeGrowthInside0._x > position.feeGrowthInside0Last._x) {
                        amount0 = -FullMath
                            .mulDiv(
                            feeGrowthInside0._x - position.feeGrowthInside0Last._x,
                            position
                                .liquidity,
                            uint256(1) << 112
                        )
                            .toInt256();
                    }
                    if (feeGrowthInside1._x > position.feeGrowthInside1Last._x) {
                        amount1 = -FullMath
                            .mulDiv(
                            feeGrowthInside1._x - position.feeGrowthInside1Last._x,
                            position
                                .liquidity,
                            uint256(1) << 112
                        )
                            .toInt256();
                    }
                }

                // update the position
                position.liquidity = position.liquidity.addi(params.liquidityDelta).toUint112();
                position.feeGrowthInside0Last = feeGrowthInside0;
                position.feeGrowthInside1Last = feeGrowthInside1;
            }

            // when the lower (upper) tick is crossed left to right (right to left), liquidity must be added (removed)
            tickInfoLower.liquidityDelta[params.feeVote] = tickInfoLower.liquidityDelta[params.feeVote]
                .add(params.liquidityDelta)
                .toInt112();
            tickInfoUpper.liquidityDelta[params.feeVote] = tickInfoUpper.liquidityDelta[params.feeVote]
                .sub(params.liquidityDelta)
                .toInt112();

            // if necessary, uninitialize both ticks and increment the position counter
            if (position.liquidity == 0 && params.liquidityDelta < 0) {
                if (tickInfoLower.numPositions == 1) delete tickInfos[params.tickLower];
                else tickInfoLower.numPositions--;
                if (tickInfoUpper.numPositions == 1) delete tickInfos[params.tickUpper];
                else tickInfoUpper.numPositions--;

                // reset fee growth
                delete position.feeGrowthInside0Last;
                delete position.feeGrowthInside1Last;
            }
        }

        // calculate how much the specified liquidity delta is worth at the lower and upper ticks
        // amount0Lower :> amount0Upper
        // amount1Upper :> amount1Lower
        (int256 amount0Lower, int256 amount1Lower) = getVirtualReservesDeltaAtPrice(
            TickMath.getRatioAtTick(params.tickLower),
            params.liquidityDelta
        );
        (int256 amount0Upper, int256 amount1Upper) = getVirtualReservesDeltaAtPrice(
            TickMath.getRatioAtTick(params.tickUpper),
            params.liquidityDelta
        );

        // the current price is below the passed range, so the liquidity can only become in range by crossing from left
        // to right, at which point we'll need _more_ token0 (it's becoming more valuable) so the user must provide it
        if (tickCurrent < params.tickLower) {
            amount0 = amount0.add(amount0Lower.sub(amount0Upper));
        } else if (tickCurrent < params.tickUpper) {
            // the current price is inside the passed range
            (int256 amount0Current, int256 amount1Current) = getVirtualReservesDeltaAtPrice(
                priceCurrent,
                params.liquidityDelta
            );
            amount0 = amount0.add(amount0Current.sub(amount0Upper));
            amount1 = amount1.add(amount1Current.sub(amount1Lower));

            liquidityCurrent[params.feeVote] = liquidityCurrent[params.feeVote].addi(params.liquidityDelta).toUint112();
        } else {
            // the current price is above the passed range, so liquidity can only become in range by crossing from right
            // to left, at which point we need _more_ token1 (it's becoming more valuable) so the user must provide it
            amount1 = amount1.add(amount1Upper.sub(amount1Lower));
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
        // the amount in remaining to be swapped of the input asset
        uint112 amountInRemaining;
        // the current tick
        int16 tick;
        // the virtual liquidity
        uint112 liquidity;
        // the price
        FixedPoint.uq112x112 price;
        // protocol fees of the input token
        uint256 feeToFees;
        // the global fee growth of the input token
        FixedPoint.uq144x112 feeGrowthGlobal;
    }

    struct StepComputations {
        // price for the target tick (1/0)
        FixedPoint.uq112x112 priceNext;
        // the fee that will be paid in this step, in bips
        uint16 fee;
        // (computed) virtual reserves of token0
        uint112 reserve0Virtual;
        // (computed) virtual reserves of token1
        uint112 reserve1Virtual;
        // how much is being swapped in in this step
        uint112 amountIn;
        // how much is being swapped out in the current step
        uint112 amountOut;
    }

    function _swap(SwapParams memory params) internal returns (uint112 amountOut) {
        _update(); // update the oracle and feeLast

        // the floor for the fee, used to prevent sandwiching attacks, static on a per-swap basis
        uint16 feeFloor = feeLast;

        SwapState memory state = SwapState({
            amountInRemaining: params.amountIn,
            tick: tickCurrent,
            liquidity: getLiquidity(),
            price: priceCurrent,
            feeToFees: params.zeroForOne ? feeToFees0 : feeToFees1,
            feeGrowthGlobal: params.zeroForOne ? feeGrowthGlobal0 : feeGrowthGlobal1
        });

        while (state.amountInRemaining > 0) {
            StepComputations memory step;
            // get the price for the next tick we're moving toward
            step.priceNext = params.zeroForOne
                ? TickMath.getRatioAtTick(state.tick)
                : TickMath.getRatioAtTick(state.tick + 1);

            // it should always be the case that if params.zeroForOne is true, we should be at or above the target price
            // similarly, if it's false we should be below the target price
            // TODO we can remove this if/when we're confident they never trigger
            if (params.zeroForOne) assert(state.price._x >= step.priceNext._x);
            else assert(state.price._x < step.priceNext._x);

            // if there might be room to move in the current tick, continue calculations
            if (params.zeroForOne == false || (state.price._x > step.priceNext._x)) {
                // protect LPs by adjusting the fee only if the current fee is greater than the stored fee
                step.fee = uint16(Math.max(feeFloor, getFee()));

                // recompute reserves given the current price/liquidity
                (step.reserve0Virtual, step.reserve1Virtual) = PriceMath.getVirtualReservesAtPrice(
                    state.price,
                    state.liquidity,
                    false
                );

                // compute the amount of input token required to push the price to the target (and max output token)
                (uint112 amountInMax, uint112 amountOutMax) = PriceMath.getInputToRatio(
                    step.reserve0Virtual,
                    step.reserve1Virtual,
                    state.liquidity,
                    step.priceNext,
                    step.fee,
                    params.zeroForOne
                );

                // swap to the next tick, or stop early if we've exhausted all the input
                step.amountIn = uint112(Math.min(amountInMax, state.amountInRemaining));

                // decrement remaining input amount
                state.amountInRemaining -= step.amountIn;

                // discount the input amount by the fee
                uint112 amountInLessFee = uint112(
                    (uint256(step.amountIn) * (PriceMath.LP_FEE_BASE - step.fee)) / PriceMath.LP_FEE_BASE
                );

                // handle the fee accounting
                uint112 feePaid = step.amountIn - amountInLessFee;
                if (feePaid > 0) {
                    // take the protocol fee if it's on
                    if (feeTo != address(0)) {
                        uint112 feeToFee = feePaid / 6;
                        // decrement feePaid
                        feePaid -= feeToFee;
                        // increment feeToFees--overflow is not possible
                        state.feeToFees += feeToFee;
                    }

                    // update global fee tracker
                    state.feeGrowthGlobal._x += FixedPoint.fraction(feePaid, state.liquidity)._x;
                }

                // handle the swap
                if (amountInLessFee > 0) {
                    // calculate the owed output amount on the discounted input amount
                    step.amountOut = params.zeroForOne
                        ? PriceMath.getAmountOut(step.reserve0Virtual, step.reserve1Virtual, amountInLessFee)
                        : PriceMath.getAmountOut(step.reserve1Virtual, step.reserve0Virtual, amountInLessFee);

                    // cap the output amount
                    step.amountOut = uint112(Math.min(step.amountOut, amountOutMax));

                    // increment amountOut
                    amountOut = (uint256(amountOut) + step.amountOut).toUint112();
                }

                // update the price
                // if we've consumed the input required to get to the target price, that's the price now!
                if (step.amountIn == amountInMax) {
                    state.price = step.priceNext;
                } else {
                    // if not, the price is the new ratio of (computed) reserves, capped at the target price
                    if (params.zeroForOne) {
                        FixedPoint.uq112x112 memory priceEstimate = FixedPoint.fraction(
                            step.reserve1Virtual.sub(step.amountOut).toUint112(),
                            (uint256(step.reserve0Virtual) + amountInLessFee).toUint112()
                        );
                        state.price = FixedPoint.uq112x112(uint224(Math.max(step.priceNext._x, priceEstimate._x)));
                        assert(state.price._x < TickMath.getRatioAtTick(state.tick + 1)._x);
                    } else {
                        FixedPoint.uq112x112 memory priceEstimate = FixedPoint.fraction(
                            (uint256(step.reserve1Virtual) + amountInLessFee).toUint112(),
                            step.reserve0Virtual.sub(step.amountOut).toUint112()
                        );
                        state.price = FixedPoint.uq112x112(uint224(Math.min(step.priceNext._x, priceEstimate._x)));
                        assert(state.price._x >= TickMath.getRatioAtTick(state.tick)._x);
                    }
                }
            }

            // we have to shift to the next tick if either of two conditions are true:
            // 1) a positive input amount remains
            // 2) if we're moving right and the price is exactly on the target tick
            // TODO ensure that there's no off-by-one error here while transitioning ticks in either direction
            if (state.amountInRemaining > 0 || (params.zeroForOne == false && state.price._x == step.priceNext._x)) {
                TickInfo storage tickInfo = tickInfos[state.tick];

                // if the tick is initialized, update it
                if (tickInfo.numPositions > 0) {
                    // update tick info
                    tickInfo.feeGrowthOutside0 = FixedPoint.uq144x112(
                        feeGrowthGlobal0._x - tickInfo.feeGrowthOutside0._x
                    );
                    tickInfo.feeGrowthOutside1 = FixedPoint.uq144x112(
                        feeGrowthGlobal1._x - tickInfo.feeGrowthOutside1._x
                    );
                    tickInfo.secondsOutside = _blockTimestamp() - tickInfo.secondsOutside; // overflow is desired

                    int256 liquidityDeltaNet;
                    // loop through each entry in liquidityDelta
                    for (uint8 i = 0; i < NUM_FEE_OPTIONS; i++) {
                        int256 liquidityDelta = tickInfo.liquidityDelta[i];
                        // increment net liquidityDelta
                        liquidityDeltaNet = liquidityDeltaNet.add(liquidityDelta);

                        // update liquidityCurrent, subi from right to left, addi from left to right
                        // TODO put this into state? bit tricky
                        if (params.zeroForOne)
                            liquidityCurrent[i] = liquidityCurrent[i].subi(liquidityDelta).toUint112();
                        else liquidityCurrent[i] = liquidityCurrent[i].addi(liquidityDelta).toUint112();
                    }

                    // update liquidity, subi from right to left, addi from left to right
                    if (params.zeroForOne) state.liquidity = state.liquidity.subi(liquidityDeltaNet).toUint112();
                    else state.liquidity = state.liquidity.addi(liquidityDeltaNet).toUint112();
                }

                // update tick
                if (params.zeroForOne) {
                    state.tick--;
                    require(state.tick >= TickMath.MIN_TICK, 'UniswapV3Pair::_swap: crossed min tick');
                } else {
                    state.tick++;
                    require(state.tick < TickMath.MAX_TICK, 'UniswapV3Pair::_swap: crossed max tick');
                }
            }
        }

        priceCurrent = state.price;
        tickCurrent = state.tick;

        if (params.zeroForOne) {
            feeToFees0 = state.feeToFees;
            feeGrowthGlobal0 = state.feeGrowthGlobal;
        } else {
            feeToFees1 = state.feeToFees;
            feeGrowthGlobal1 = state.feeGrowthGlobal;
        }

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
        require(amount0In > 0, 'UniswapV3Pair::swap0For1: amountIn must be greater than 0');

        SwapParams memory params = SwapParams({zeroForOne: true, amountIn: amount0In, to: to, data: data});
        return _swap(params);
    }

    // move from left to right (token 0 is becoming more valuable)
    function swap1For0(
        uint112 amount1In,
        address to,
        bytes calldata data
    ) external override lock returns (uint112 amount0Out) {
        require(amount1In > 0, 'UniswapV3Pair::swap1For0: amountIn must be greater than 0');

        SwapParams memory params = SwapParams({zeroForOne: false, amountIn: amount1In, to: to, data: data});
        return _swap(params);
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
