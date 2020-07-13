// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.11;
pragma experimental ABIEncoderV2;

import '@uniswap/lib/contracts/libraries/TransferHelper.sol';
import '@uniswap/lib/contracts/libraries/FixedPoint.sol';
import '@uniswap/lib/contracts/libraries/Babylonian.sol';

import './libraries/FeeVoting.sol';
import './libraries/SafeMath.sol';
import './libraries/FixedPointExtra.sol';
import './libraries/TickMath.sol';
import './libraries/PriceMath.sol';

import './interfaces/IUniswapV3Pair.sol';
import './interfaces/IUniswapV3Factory.sol';
import './interfaces/IUniswapV3Callee.sol';

contract UniswapV3Pair is IUniswapV3Pair {
    using SafeMath for uint;
    using SafeMathUint112 for uint112;
    using SafeMathInt112 for int112;
    using FixedPoint for FixedPoint.uq112x112;
    using FixedPoint for FixedPoint.uq144x112;
    using FixedPointExtra for FixedPoint.uq112x112;

    uint112 public constant override LIQUIDITY_MIN = 10**3;
    uint16 public constant override FEE_VOTE_MAX = 6000; // 6000 pips / 60 bips / 0.60%

    address public immutable override factory;
    address public immutable override token0;
    address public immutable override token1;

    // ⬇ single storage slot ⬇
    uint112 public override reserve0;
    uint112 public override reserve1;
    uint32  public override blockTimestampLast;
    // ⬆ single storage slot ⬆

    int16 public override tickCurrent; // the first price tick _at_ or _below_ the current (reserve1 / reserve0) price
    // TODO what size uint should this be?
    uint112 public override liquidityCurrent; // the amount of liquidity at the current tick

    uint public override price0CumulativeLast; // cumulative (reserve1 / reserve0) oracle price
    uint public override price1CumulativeLast; // cumulative (reserve0 / reserve1) oracle price

    uint224 public override kLast; // (reserve0 * reserve1), as of immediately after the most recent liquidity event
    
    struct TickInfo {
        // seconds spent on the _other_ side of this tick (relative to the current tick)
        uint32 secondsGrowthOutside;
        // fee growth on the _other_ side of this tick (relative to the current tick)
        FixedPoint.uq112x112 growthOutside;
    }
    // these only have relative meaning, not absolute — their value depends on when the tick is initialized
    mapping (int16 => TickInfo) public tickInfos;
    // amount of token0 added or removed (depending on sign) when ticks are crossed from left to right,
    // i.e. as the (reserve1 / reserve0) price goes up
    // TODO what size int (uint?) should this be?
    mapping (int16 => int112) public token0Deltas;

    // TODO these almost certainly need to be different size uints
    FeeVoting.Aggregate public feeVoteAggregate;
    mapping (int16 => FeeVoting.Aggregate) public feeVoteDeltas;

    struct Position {
        // the amount of liquidity (sqrt(amount0 * amount1)).
        // does not increase automatically as fees accumulate, it remains sqrt(amount0 * amount1) until modified.
        // fees may be collected directly by calling setPosition with liquidityDelta set to 0.
        // fees may be compounded by calling setPosition with liquidityDelta set to the accumulated fees.
        uint112 liquidity;
        // the amount of liquidity adjusted for fee growth (liquidity / growthInside).
        // will be smaller than liquidity if any fees have been earned in range.
        uint112 liquidityScalar;
        // vote for the total swap fee, in pips
        uint16 feeVote;
    }
    // TODO: is this the best way to map (address, int16, int16) to a struct?
    mapping (bytes32 => Position) public positions;

    uint private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, 'UniswapV3: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    // helper functions for getting/setting position structs
    function getPositionKey(address owner, int16 tickLower, int16 tickUpper) public pure returns (bytes32 positionKey) {
        assert(tickLower >= TickMath.MIN_TICK);
        assert(tickUpper <= TickMath.MAX_TICK);
        positionKey = keccak256(abi.encodePacked(owner, tickLower, tickUpper));
    }

    function _getPosition(address owner, int16 tickLower, int16 tickUpper)
        private
        view
        returns (Position storage position)
    {
        position = positions[getPositionKey(owner, tickLower, tickUpper)];
    }

    function _setPosition(address owner, int16 tickLower, int16 tickUpper, Position memory position) private {
        positions[getPositionKey(owner, tickLower, tickUpper)] = position;
    }

    // get fee growth (sqrt(reserve0 * reserve1) / liquidity)
    function getG() public view returns (FixedPoint.uq112x112 memory g) {
        uint rootK = Babylonian.sqrt(uint(reserve0) * reserve1);
        g = FixedPoint.encode(uint112(rootK)).div(liquidityCurrent);
    }

    function _getGrowthBelow(int16 tick, FixedPoint.uq112x112 memory g)
        private
        view
        returns (FixedPoint.uq112x112 memory growthBelow)
    {
        growthBelow = tickInfos[tick].growthOutside;
        // tick is above currentTick, meaning growth below  _in addition_ to growthOutside has occurred, so account for it
        if (tick > tickCurrent) {
            growthBelow = g.uqdiv112(growthBelow);
        }
    }

    function _getGrowthAbove(int16 tick, FixedPoint.uq112x112 memory g)
        private
        view
        returns (FixedPoint.uq112x112 memory growthAbove)
    {
        growthAbove = tickInfos[tick].growthOutside;
        // tick is at or below currentTick, meaning growth in addition to growthOutside has occurred, so account for it
        if (tick <= tickCurrent) {
            growthAbove = g.uqdiv112(growthAbove);
        }
    }

    // gets the growth in g within a particular range
    // this only has relative meaning, not absolute
    // TODO: simpler or more precise way to compute this?
    function getGrowthInside(int16 tickLower, int16 tickUpper)
        public
        view
        returns (FixedPoint.uq112x112 memory growthInside)
    {
        assert(tickLower >= TickMath.MIN_TICK);
        assert(tickUpper <= TickMath.MAX_TICK);
        FixedPoint.uq112x112 memory g = getG();
        FixedPoint.uq112x112 memory growthBelow = _getGrowthBelow(tickLower, g);
        FixedPoint.uq112x112 memory growthAbove = _getGrowthAbove(tickUpper, g);
        growthInside = growthAbove.uqmul112(growthBelow).reciprocal().uqmul112(g);
    }

    // given a price and a liquidity amount, return the value of that liquidity at the price
    // TODO ensure this is correct/safe
    function getValueAtPrice(FixedPoint.uq112x112 memory price, int112 liquidity)
        public
        pure
        returns (int112 amount0, int112 amount1)
    {
        amount0 = price.reciprocal().sqrt().smul112(liquidity);
        amount1 = price.smul112(amount0);
    }

    constructor(address _token0, address _token1) public {
        factory = msg.sender;
        token0 = _token0;
        token1 = _token1;
    }

    // update reserves and, on the first call per block, price accumulators
    function _update(uint112 reserve0Next, uint112 reserve1Next) private {
        uint32 blockTimestamp = uint32(block.timestamp);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired
        if (timeElapsed > 0 && reserve0 != 0 && reserve1 != 0) {
            // + overflow is desired
            price0CumulativeLast += FixedPoint.encode(reserve1).div(reserve0).mul(timeElapsed)._x;
            price1CumulativeLast += FixedPoint.encode(reserve0).div(reserve1).mul(timeElapsed)._x;
        }
        reserve0 = reserve0Next;
        reserve1 = reserve1Next;
        blockTimestampLast = blockTimestamp;
    }

    // if fee is on, mint liquidity equivalent to 1/6th of the growth in sqrt(k)
    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        address feeTo = IUniswapV3Factory(factory).feeTo();
        feeOn = feeTo != address(0);
        if (feeOn) {
            if (kLast != 0) {
                uint rootK = Babylonian.sqrt(uint(_reserve0) * _reserve1);
                uint rootKLast = Babylonian.sqrt(kLast);
                if (rootK > rootKLast) {
                    uint numerator = uint(liquidityCurrent).mul(rootK.sub(rootKLast));
                    uint denominator = rootK.mul(5).add(rootKLast);
                    uint liquidity = numerator / denominator;
                    if (liquidity > 0) {
                        // TODO check this
                        Position storage position = _getPosition(feeTo, 0, 0);
                        position.liquidity += uint112(liquidity);
                        liquidityCurrent += uint112(liquidity);
                    }
                }
            }
        }
        // if the fee is not on, and kLast is not 0, set it to 0
        else if (kLast != 0) {
            kLast = 0;
        }
    }

    function initialize(uint112 amount0, uint112 amount1, int16 tickStarting, uint16 feeVote)
        external
        lock
        returns (uint112 liquidity)
    {
        require(liquidityCurrent == 0, 'UniswapV3: ALREADY_INITIALIZED'); // valid check because of LIQUIDITY_MIN
        require(feeVote <= FEE_VOTE_MAX, 'UniswapV3: FEE_VOTE_TOO_LARGE');

        // ensure the tickStarting witness is correct
        FixedPoint.uq112x112 memory priceStarting = FixedPoint.encode(amount1).div(amount0);
        require(TickMath.getPrice(tickStarting)._x <= priceStarting._x, 'UniswapV3: STARTING_TICK_TOO_LARGE');
        require(TickMath.getPrice(tickStarting + 1)._x > priceStarting._x, 'UniswapV3: STARTING_TICK_TOO_SMALL');
        tickCurrent = tickStarting;

        TransferHelper.safeTransferFrom(token0, msg.sender, address(this), amount0);
        TransferHelper.safeTransferFrom(token1, msg.sender, address(this), amount1);

        bool feeOn = _mintFee(0, 0);

        // will throw if amounts are insufficient to generate at least LIQUIDITY_MIN liquidity
        liquidity = uint112(Babylonian.sqrt(uint(amount0) * amount1).sub(LIQUIDITY_MIN));
        liquidityCurrent = liquidity + LIQUIDITY_MIN;

        // set a permanent LIQUIDITY_MIN position
        _setPosition(address(0), TickMath.MIN_TICK, TickMath.MAX_TICK, Position({
            liquidity: LIQUIDITY_MIN,
            liquidityScalar: LIQUIDITY_MIN,
            feeVote: 0
        }));

        // set the user's position
        Position memory position = Position({
            liquidity: liquidity,
            liquidityScalar: liquidity,
            feeVote: feeVote
        });
        _setPosition(msg.sender, TickMath.MIN_TICK, TickMath.MAX_TICK, position);

        // note that this doesn't include the burned LIQUIDITY_MIN weight
        feeVoteAggregate = FeeVoting.totalFeeVote(position);

        _update(amount0, amount1);
        if (feeOn) kLast = uint224(reserve0) * reserve1; // reserve0 and reserve1 are up-to-date
    }

    function _initializeTick(int16 tick) private {
        if (tickInfos[tick].growthOutside._x == 0) {
            // by convention, we assume that all growth before a tick was initialized happened _below_ the tick
            if (tick <= tickCurrent) {
                tickInfos[tick] = TickInfo({
                    secondsGrowthOutside: uint32(block.timestamp),
                    growthOutside: getG()
                });
            } else {
                tickInfos[tick] = TickInfo({
                    secondsGrowthOutside: 0,
                    growthOutside: FixedPoint.encode(1)
                });
            }
        }
    }

    // called when adding or removing liquidity that is within range
    function _updateLiquidity(int112 liquidity, FeeVoting.Aggregate memory feeVoteDelta)
        private
        returns (int112 amount0, int112 amount1)
    {
        bool feeOn = _mintFee(reserve0, reserve1);

        (amount0, amount1) = getValueAtPrice(FixedPoint.encode(reserve1).div(reserve0), liquidity);

        liquidityCurrent = liquidityCurrent.add(int112(int(amount0) * int(liquidityCurrent) / int(reserve0)));
        // the price doesn't change, so no need to update the oracle
        reserve0 = reserve0.add(amount0);
        reserve1 = reserve1.add(amount1);
        feeVoteAggregate = FeeVoting.add(feeVoteAggregate, feeVoteDelta);

        if (feeOn) kLast = uint224(reserve0) * reserve1;
    }

    // add or remove a specified amount of liquidity from a specified range, and/or change feeVote for that range
    // also sync a position and return accumulated fees from it to user as tokens
    // liquidityDelta is sqrt(reserve0 * reserve1), so does not incorporate fees
    function setPosition(int16 tickLower, int16 tickUpper, int112 liquidityDelta, uint16 feeVote) external lock {
        require(liquidityCurrent > 0, 'UniswapV3: NOT_INITIALIZED'); // valid check because of LIQUIDITY_MIN
        require(tickLower < tickUpper, 'UniswapV3: BAD_TICKS');
        require(feeVote <= FEE_VOTE_MAX, 'UniswapV3: INVALID_FEE_VOTE');

        _initializeTick(tickLower); // initialize ticks idempotently
        _initializeTick(tickUpper); // initialize ticks idempotently

        int112 amount0;
        int112 amount1;
        FeeVoting.Aggregate memory feeVoteDelta;

        {
        // get existing position
        Position storage position = _getPosition(msg.sender, tickLower, tickUpper);

        // rebate any collected fees to user (recompound by setting liquidityDelta to accumulated fees)
        FixedPoint.uq112x112 memory growthInside = getGrowthInside(tickLower, tickUpper);
        int112 feeLiquidity = growthInside.smul112(int112(position.liquidityScalar)) - int112(position.liquidity);
        // credit the user for the value of their fee liquidity at the current price
        (amount0, amount1) = getValueAtPrice(FixedPoint.encode(reserve1).div(reserve0), -feeLiquidity);

        FeeVoting.Aggregate memory feeVoteLast = FeeVoting.totalFeeVote(position);

        // update position
        position.liquidity = position.liquidity.add(liquidityDelta);
        position.liquidityScalar = growthInside.reciprocal().mul112(position.liquidity.add(liquidityDelta)).decode();
        position.feeVote = feeVote;

        feeVoteDelta = FeeVoting.sub(FeeVoting.totalFeeVote(position), feeVoteLast);
        }

        // calculate how much the specified liquidity is worth at the prices determined by the lower and upper ticks
        // amount0Lower :> amount0Upper
        // amount1Upper :> amount1Lower
        (int112 amount0Lower, int112 amount1Lower) = getValueAtPrice(TickMath.getPrice(tickLower), liquidityDelta);
        (int112 amount0Upper, int112 amount1Upper) = getValueAtPrice(TickMath.getPrice(tickUpper), liquidityDelta);

        // regardless of current price, when lower tick is crossed from left to right amount0Lower should be added
        token0Deltas[tickLower] = token0Deltas[tickLower].add(amount0Lower);
        // regardless of current price, when upper tick is crossed from left to right amount0Upper should be removed
        token0Deltas[tickUpper] = token0Deltas[tickUpper].sub(amount0Upper);

        feeVoteDeltas[tickLower] = FeeVoting.add(feeVoteDeltas[tickLower], feeVoteDelta);
        feeVoteDeltas[tickUpper] = FeeVoting.sub(feeVoteDeltas[tickUpper], feeVoteDelta);

        // the current price is below the passed range, so the liquidity can only become in range by crossing from left
        // to right, at which point we'll need _more_ token0 (it's becoming more valuable) so the user must provide it
        if (tickCurrent < tickLower) {
            amount0 = amount0.add(amount0Lower.sub(amount0Upper));
        }
        // the current price is inside the passed range
        else if (tickCurrent < tickUpper) {
            // the value of the liquidity at the current price
            (int112 amount0Current, int112 amount1Current) = _updateLiquidity(liquidityDelta, feeVoteDelta);
            amount0 = amount0.add(amount0Current.sub(amount0Upper));
            amount1 = amount1.add(amount1Current.sub(amount1Lower));
        }
        // the current price is above the passed range, so the liquidity can only become in range by crossing from right
        // to left, at which point we'll need _more_ token1 (it's becoming more valuable) so the user must provide it
        else {
            amount1 = amount1.add(amount1Upper.sub(amount1Lower));
        }

        if (amount0 > 0) {
            TransferHelper.safeTransferFrom(token0, msg.sender, address(this), uint(amount0));
        } else if (amount0 < 0) {
            TransferHelper.safeTransfer(token0, msg.sender, uint(-amount0));
        }
        if (amount1 > 0) {
            TransferHelper.safeTransferFrom(token1, msg.sender, address(this), uint(amount1));
        } else if (amount1 < 0) {
            TransferHelper.safeTransfer(token1, msg.sender, uint(-amount1));
        }
    }

    // TODO: implement swap1for0, or integrate it into this
    // move from right to left (token 1 is becoming more valuable)
    function swap0for1(uint amountIn, address to, bytes calldata data) external lock {
        uint112 _reserve0 = reserve0;
        uint112 _reserve1 = reserve1;
        require(_reserve0 > 0 && _reserve1 > 0, 'UniswapV3: NOT_INITIALIZED');
        int16 _currentTick = tickCurrent;
        uint112 amountInLeft = uint112(amountIn);
        uint112 amountOut = 0;
        FeeVoting.Aggregate memory _feeVoteAggregate = feeVoteAggregate;
        while (amountInLeft > 0) {
            FixedPoint.uq112x112 memory price = TickMath.getPrice(_currentTick);
            // compute how much would need to be traded to get to the next tick down
            { // scope
            uint112 maxAmount = PriceMath.getTradeToRatio(_reserve0, _reserve1, FeeVoting.averageFee(feeVoteAggregate), price);
            uint112 amountInStep = (amountInLeft > maxAmount) ? maxAmount : amountInLeft;
            // execute the sell of amountToTrade
            uint112 adjustedAmountToTrade = amountInStep * (1000000 - FeeVoting.averageFee(_feeVoteAggregate)) / 1000000;
            uint112 amountOutStep = (adjustedAmountToTrade * _reserve1) / (_reserve0 + adjustedAmountToTrade);
            amountOut = amountOut.add(amountOutStep);
            _reserve0 = _reserve0.add(amountInStep);
            _reserve1 = _reserve1.sub(amountOutStep);
            amountInLeft = amountInLeft.sub(amountInStep);
            }
            if (amountInLeft > 0) { // shift past the tick
                TickInfo memory _oldTickInfo = tickInfos[_currentTick];
                if (_oldTickInfo.growthOutside._x == 0) {
                    _currentTick -= 1;
                    continue;
                }
                // TODO (eventually): batch all updates, including from mintFee
                bool feeOn = _mintFee(_reserve0, _reserve1);
                FixedPoint.uq112x112 memory _oldGrowthOutside = _oldTickInfo.growthOutside._x != 0 ?
                    _oldTickInfo.growthOutside :
                    FixedPoint.encode(1);
                // kick in/out liquidity
                int112 _delta = token0Deltas[_currentTick] * -1; // * -1 because we're crossing the tick from right to left 
                _reserve0 = _reserve0.add(_delta);
                _reserve1 = _reserve1.add(price.smul112(_delta));
                liquidityCurrent = liquidityCurrent.add(int112(int(liquidityCurrent) * int(_delta) / int(_reserve0)));
                // kick in/out fee votes
                // sub because we're crossing the tick from right to left
                _feeVoteAggregate = FeeVoting.sub(_feeVoteAggregate, feeVoteDeltas[_currentTick]);
                // update tick info
                tickInfos[_currentTick] = TickInfo({
                    // overflow is desired
                    secondsGrowthOutside: uint32(block.timestamp) - _oldTickInfo.secondsGrowthOutside,
                    growthOutside: getG().uqdiv112(_oldGrowthOutside)
                });
                _currentTick -= 1;
                if (feeOn) kLast = uint224(_reserve0) * _reserve1;
            }
        }
        tickCurrent = _currentTick;
        // TODO: record new fees or something?
        TransferHelper.safeTransfer(token1, msg.sender, amountOut);
        if (data.length > 0) IUniswapV3Callee(to).uniswapV3Call(msg.sender, 0, amountOut, data);
        TransferHelper.safeTransferFrom(token0, msg.sender, address(this), amountIn);
        _update(_reserve0, _reserve1);
    }
}