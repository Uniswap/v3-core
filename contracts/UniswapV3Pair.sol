// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.6.8;
pragma experimental ABIEncoderV2;

import '@uniswap/lib/contracts/libraries/TransferHelper.sol';
import '@uniswap/lib/contracts/libraries/FixedPoint.sol';
import '@uniswap/lib/contracts/libraries/Babylonian.sol';

import './interfaces/IUniswapV3Pair.sol';
import { Aggregate, AggregateFunctions } from './libraries/AggregateFeeVote.sol';
import { Position, PositionFunctions } from './libraries/Position.sol';
import './libraries/SafeMath.sol';
import './libraries/SafeMath112.sol';
import './interfaces/IUniswapV3Factory.sol';
import './interfaces/IUniswapV3Callee.sol';
import './libraries/FixedPointExtra.sol';

contract UniswapV3Pair is IUniswapV3Pair {
    using SafeMath for uint;
    using SafeMath112 for uint112;
    using SafeMath112 for int112;
    using AggregateFunctions for Aggregate;
    using PositionFunctions for Position;
    using FixedPoint for FixedPoint.uq112x112;
    using FixedPointExtra for FixedPoint.uq112x112;
    using FixedPoint for FixedPoint.uq144x112;

    uint112 public constant override MINIMUM_LIQUIDITY = uint112(10**3);
    int16 public constant MAX_TICK = type(int16).max;
    int16 public constant MIN_TICK = type(int16).min;
    uint16 public constant MAX_FEEVOTE = 6000; // 60 bps
    uint16 public constant MIN_FEEVOTE = 0; // 0 bps

    address public immutable override factory;
    address public immutable override token0;
    address public immutable override token1;

    uint112 public totalFeeVote;

    uint112 private reserve0;           // uses single storage slot, accessible via getReserves
    uint112 private reserve1;           // uses single storage slot, accessible via getReserves
    uint32  private blockTimestampLast; // uses single storage slot, accessible via getReserves

    uint public override price0CumulativeLast;
    uint public override price1CumulativeLast;
    uint public override kLast; // reserve0 * reserve1, as of immediately after the most recent liquidity event

    uint112 private virtualSupply;  // current virtual supply;
    uint64 private timeInitialized; // timestamp when pool was initialized

    int16 public currentTick; // the current tick for the token0 price (rounded down)

    uint private unlocked = 1;
    
    struct TickInfo {
        uint32 secondsGrowthOutside;         // measures number of seconds spent while pool was on other side of this tick (from the current price)
        FixedPoint.uq112x112 kGrowthOutside; // measures growth due to fees while pool was on the other side of this tick (from the current price)
    }

    mapping (int16 => TickInfo) tickInfos;  // mapping from tick indexes to information about that tick
    mapping (int16 => int112) deltas;       // mapping from tick indexes to amount of token0 kicked in or out when tick is crossed going from left to right (token0 price going up)

    Aggregate aggregateFeeVote;
    mapping (int16 => Aggregate) deltaFeeVotes;       // mapping from tick indexes to amount of token0 kicked in or out when tick is crossed
    mapping (int16 => int112) deltaVotingShares;       // mapping from tick indexes to amount of token0 kicked in or out when tick is crossed

    // TODO: is this really the best way to map (address, int16, int16)
    // user address, lower tick, upper tick
    mapping (address => mapping (int16 => mapping (int16 => Position))) positions;

    modifier lock() {
        require(unlocked == 1, 'UniswapV3: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    // get LP fee in 100ths of a bp
    function getLpFee() public view returns (uint16) {
        return aggregateFeeVote.averageFee();
    }

    // returns sqrt(x*y)/shares
    function getInvariant() public view returns (FixedPoint.uq112x112 memory k) {
        uint112 rootXY = uint112(Babylonian.sqrt(uint256(reserve0) * uint256(reserve1)));
        return FixedPoint.encode(rootXY).div(virtualSupply);
    }

    function getGrowthAbove(int16 tickIndex, int16 _currentTick, FixedPoint.uq112x112 memory _k) public view returns (FixedPoint.uq112x112 memory) {
        TickInfo memory _tickInfo = tickInfos[tickIndex];
        if (_tickInfo.secondsGrowthOutside == 0) {
            return FixedPoint.encode(1);
        }
        FixedPoint.uq112x112 memory kGrowthOutside = tickInfos[tickIndex].kGrowthOutside;
        if (_currentTick >= tickIndex) {
            // this range is currently active
            return _k.uqdiv112(kGrowthOutside);
        } else {
            // this range is currently inactive
            return kGrowthOutside;
        }
    }

    function getGrowthBelow(int16 tickIndex, int16 _currentTick, FixedPoint.uq112x112 memory _k) public view returns (FixedPoint.uq112x112 memory) {
        FixedPoint.uq112x112 memory kGrowthOutside = tickInfos[tickIndex].kGrowthOutside;
        if (_currentTick < tickIndex) {
            // this range is currently active
            return _k.uqdiv112(kGrowthOutside);
        } else {
            // this range is currently inactive
            return kGrowthOutside;
        }
    }

    // gets the growth in K for within a particular range
    function getGrowthInside(int16 _lowerTick, int16 _upperTick) public view returns (FixedPoint.uq112x112 memory growth) {
        // TODO: simpler or more precise way to compute this?
        FixedPoint.uq112x112 memory _k = getInvariant();
        int16 _currentTick = currentTick;
        FixedPoint.uq112x112 memory growthAbove = getGrowthAbove(_upperTick, _currentTick, _k);
        FixedPoint.uq112x112 memory growthBelow = getGrowthBelow(_lowerTick, _currentTick, _k);
        return growthAbove.uqmul112(growthBelow).reciprocal().uqmul112(_k);
    }

    function getReserves() public override view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    constructor(address token0_, address token1_) public {
        factory = msg.sender;
        token0 = token0_;
        token1 = token1_;
    }

    // update reserves and, on the first call per block, price accumulators
    function _update(uint112 _oldReserve0, uint112 _oldReserve1, uint112 _newReserve0, uint112 _newReserve1) private {
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired
        if (timeElapsed > 0 && _oldReserve0 != 0 && _oldReserve1 != 0) {
            // + overflow is desired
            price0CumulativeLast += FixedPoint.encode(_oldReserve1).div(_oldReserve0).mul(timeElapsed).decode144();
            price1CumulativeLast += FixedPoint.encode(_oldReserve0).div(_oldReserve1).mul(timeElapsed).decode144();
        }
        reserve0 = _newReserve0;
        reserve1 = _newReserve1;
        blockTimestampLast = blockTimestamp;
    }

    // if fee is on, mint liquidity equivalent to 1/6th of the growth in sqrt(k)
    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        address feeTo = IUniswapV3Factory(factory).feeTo();
        feeOn = feeTo != address(0);
        uint _kLast = kLast; // gas savings
        uint112 _virtualSupply = virtualSupply;
        if (feeOn) {
            if (_kLast != 0) {
                uint rootK = Babylonian.sqrt(uint(_reserve0).mul(_reserve1));
                uint rootKLast = Babylonian.sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint numerator = uint(_virtualSupply).mul(rootK.sub(rootKLast));
                    uint denominator = rootK.mul(5).add(rootKLast);
                    uint112 liquidity = uint112(numerator / denominator);
                    if (liquidity > 0) {
                        positions[feeTo][0][0].liquidity += liquidity;
                        virtualSupply = _virtualSupply + liquidity;
                    }
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }

    function getBalancesAtPrice(int112 liquidity, FixedPoint.uq112x112 memory price) internal pure returns (int112 balance0, int112 balance1) {
        balance0 = price.reciprocal().sqrt().smul112(liquidity);
        balance1 = price.smul112(balance0);
    }

    function getBalancesAtTick(int112 liquidity, int16 tick) internal pure returns (int112 balance0, int112 balance1) {
        if (tick == MIN_TICK || tick == MAX_TICK) {
            // TODO: reason about this
            return (0, 0);
        }
        FixedPoint.uq112x112 memory price = getTickPrice(tick);
        return getBalancesAtPrice(liquidity, price);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function initialAdd(uint112 amount0, uint112 amount1, int16 startingTick, uint16 feeVote) external override lock returns (uint112 liquidity) {
        require(virtualSupply == 0, "UniswapV3: ALREADY_INITIALIZED");
        require(feeVote >= MIN_FEEVOTE && feeVote <= MAX_FEEVOTE, "UniswapV3: INVALID_FEE_VOTE");
        FixedPoint.uq112x112 memory price = FixedPoint.encode(amount1).div(amount0);
        require(price._x > getTickPrice(startingTick)._x && price._x < getTickPrice(startingTick + 1)._x);
        bool feeOn = _mintFee(0, 0);
        liquidity = uint112(Babylonian.sqrt(uint256(amount0).mul(uint256(amount1))).sub(MINIMUM_LIQUIDITY));
        require(liquidity > 0, 'UniswapV3: INSUFFICIENT_LIQUIDITY_MINTED');
        positions[address(0)][MIN_TICK][MAX_TICK] = Position({
            liquidity: MINIMUM_LIQUIDITY,
            lastAdjustedLiquidity: MINIMUM_LIQUIDITY,
            feeVote: feeVote
        });
        positions[msg.sender][MIN_TICK][MAX_TICK] = Position({
            liquidity: liquidity,
            lastAdjustedLiquidity: liquidity,
            feeVote: feeVote
        });
        uint112 totalLiquidity = liquidity + MINIMUM_LIQUIDITY;
        virtualSupply = totalLiquidity;
        aggregateFeeVote = Aggregate({
            numerator: int112(feeVote).mul(int112(totalLiquidity)),
            denominator: int112(totalLiquidity)
        });
        uint112 _reserve0 = amount0;
        uint112 _reserve1 = amount1;
        _update(0, 0, _reserve0, _reserve1);
        currentTick = startingTick;
        TransferHelper.safeTransferFrom(token0, msg.sender, address(this), amount0);
        TransferHelper.safeTransferFrom(token1, msg.sender, address(this), amount1);
        if (feeOn) kLast = uint(_reserve0).mul(_reserve1);
        emit SetPosition(address(0), int112(MINIMUM_LIQUIDITY), MIN_TICK, MAX_TICK, feeVote);
        emit SetPosition(msg.sender, int112(liquidity), MIN_TICK, MAX_TICK, feeVote);
    }

    // add or remove a specified amount of liquidity from a specified range, and/or change feeVote for that range
    function setPosition(int112 liquidity, int16 lowerTick, int16 upperTick, uint16 feeVote) external override lock {
        require(feeVote > MIN_FEEVOTE && feeVote < MAX_FEEVOTE, "UniswapV3: INVALID_FEE_VOTE");
        require(lowerTick < upperTick, "UniswapV3: BAD_TICKS");
        Position memory _position = positions[msg.sender][lowerTick][upperTick];
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint112 _virtualSupply = virtualSupply; // gas savings, must be defined here since virtualSupply can update in _mintFee
        require(_virtualSupply > 0, 'UniswapV3: NOT_INITIALIZED');
        // adjust liquidity values based on fees accumulated in the range
        FixedPoint.uq112x112 memory adjustmentFactor = getGrowthInside(lowerTick, upperTick);
        int112 adjustedExistingLiquidity = adjustmentFactor.smul112(int112(_position.liquidity));
        int112 adjustedNewLiquidity = adjustmentFactor.smul112(liquidity);
        uint112 totalAdjustedLiquidity = uint112(adjustedExistingLiquidity).sadd(adjustedNewLiquidity);
        // update position
        Position memory newPosition = Position({
            lastAdjustedLiquidity: totalAdjustedLiquidity,
            liquidity: _position.liquidity.sadd(liquidity),
            feeVote: feeVote
        });
        positions[msg.sender][lowerTick][upperTick] = newPosition;
        // before moving on, withdraw any collected fees
        // until fees are collected, they are like unlevered pool shares that do not earn fees outside the range
        FixedPoint.uq112x112 memory currentPrice = FixedPoint.encode(reserve1).div(reserve0);
        int112 feeLiquidity = adjustedExistingLiquidity - int112(_position.lastAdjustedLiquidity);
        // negative amount means the amount is sent out
        (int112 amount0, int112 amount1) = getBalancesAtPrice(-feeLiquidity, currentPrice);
        // update vote deltas. since adjusted liquidity and vote could change, remove all votes and add new ones
        Aggregate memory deltaFeeVote = newPosition.totalFeeVote().sub(_position.totalFeeVote());
        deltaFeeVotes[lowerTick] = deltaFeeVotes[lowerTick].add(deltaFeeVote);
        deltaFeeVotes[upperTick] = deltaFeeVotes[upperTick].sub(deltaFeeVote);
        // calculate how much the newly added/removed shares are worth at lower ticks and upper ticks
        (int112 lowerToken0Balance, int112 lowerToken1Balance) = getBalancesAtTick(adjustedNewLiquidity, lowerTick);
        (int112 upperToken0Balance, int112 upperToken1Balance) = getBalancesAtTick(adjustedNewLiquidity, upperTick);
        // update token0 deltas
        deltas[lowerTick] = deltas[lowerTick].add(lowerToken0Balance);
        deltas[upperTick] = deltas[upperTick].sub(upperToken0Balance);
        if (currentTick < lowerTick) {
            amount1 = amount1.add(lowerToken1Balance.sub(upperToken1Balance));
        } else if (currentTick < upperTick) {
            (int112 virtualAmount0, int112 virtualAmount1) = getBalancesAtPrice(adjustedNewLiquidity, currentPrice);
            amount0 += virtualAmount0 - lowerToken0Balance;
            amount1 += virtualAmount1 - upperToken1Balance;
            // price doesn't change, so no need to update oracle
            virtualSupply = _virtualSupply.sadd(int112(int(virtualAmount0) * int(_virtualSupply) / int(reserve0)));
            reserve0 = _reserve0.sadd(virtualAmount0);
            reserve1 = _reserve1.sadd(virtualAmount1);
            aggregateFeeVote = aggregateFeeVote.add(deltaFeeVote);
        } else {
            amount0 = amount0.add(upperToken0Balance.sub(lowerToken0Balance));
        }
        if (amount0 >= 0) {
            TransferHelper.safeTransferFrom(token0, msg.sender, address(this), uint112(amount0));
        } else {
            TransferHelper.safeTransfer(token0, msg.sender, uint112(-amount0));
        }
        if (amount1 >= 0) {
            TransferHelper.safeTransferFrom(token1, msg.sender, address(this), uint112(amount1));
        } else {
            TransferHelper.safeTransfer(token1, msg.sender, uint112(-amount1));
        }
        if (feeOn) kLast = uint(_reserve0).mul(_reserve1);
        emit SetPosition(msg.sender, liquidity, lowerTick, upperTick, feeVote);
    }

    function getTradeToRatio(uint112 y0, uint112 x0, FixedPoint.uq112x112 memory price, uint112 _lpFee) internal pure returns (uint112) {
        // todo: clean up this monstrosity, which won't even compile because the stack is too deep
        // simplification of https://www.wolframalpha.com/input/?i=solve+%28x0+-+x0*%281-g%29*y%2F%28y0+%2B+%281-g%29*y%29%29%2F%28y0+%2B+y%29+%3D+p+for+y
        // uint112 numerator = price.sqrt().mul112(uint112(Babylonian.sqrt(y0))).mul112(uint112(Babylonian.sqrt(price.mul112(y0).mul112(lpFee).mul112(lpFee).div(1000000).add(price.mul112(4 * x0).mul112(1000000 - lpFee)).decode()))).decode();
        // uint112 denominator = price.mul112(1000000 - lpFee).div(1000000).mul112(2).decode();
        return uint112(1);
    }

    // TODO: implement swap1for0, or integrate it into this
    function swap0for1(uint amountIn, address to, bytes calldata data) external lock {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        (uint112 _oldReserve0, uint112 _oldReserve1) = (_reserve0, _reserve1);
        int16 _currentTick = currentTick;
        uint112 _virtualSupply = virtualSupply;

        uint112 totalAmountOut = 0;

        uint112 amountInLeft = uint112(amountIn);
        uint112 amountOut = 0;
        uint112 _lpFee = getLpFee();

        while (amountInLeft > 0) {
            FixedPoint.uq112x112 memory price = getTickPrice(_currentTick);

            // compute how much would need to be traded to get to the next tick down
            uint112 maxAmount = getTradeToRatio(_reserve0, _reserve1, price, _lpFee);
        
            uint112 amountToTrade = (amountInLeft > maxAmount) ? maxAmount : amountInLeft;

            // execute the sell of amountToTrade
            uint112 adjustedAmountToTrade = amountToTrade * (1000000 - _lpFee) / 1000000;
            uint112 amountOutStep = (adjustedAmountToTrade * _reserve1) / (_reserve0 + adjustedAmountToTrade);

            amountOut += amountOutStep;
            _reserve0 -= amountOutStep;
            // TODO: handle overflow?
            _reserve1 += amountToTrade;

            amountInLeft = amountInLeft - amountToTrade;
            if (amountInLeft == 0) { // shift past the tick
                FixedPoint.uq112x112 memory k = FixedPoint.encode(uint112(Babylonian.sqrt(uint(_reserve0) * uint(_reserve1)))).div(virtualSupply);
                TickInfo memory _oldTickInfo = tickInfos[_currentTick];
                FixedPoint.uq112x112 memory _oldKGrowthOutside = _oldTickInfo.secondsGrowthOutside != 0 ? _oldTickInfo.kGrowthOutside : FixedPoint.encode(uint112(1));
                // get delta of token0
                int112 _delta = deltas[_currentTick] * -1; // * -1 because we're crossing the tick from right to left 
                // TODO: try to mint protocol fee in some way that batches the calls and updates across multiple ticks
                bool feeOn = _mintFee(_reserve0, _reserve1);
                // kick in/out liquidity
                _reserve0 = _reserve0.sadd(_delta);
                _reserve1 = _reserve1.sadd(price.smul112(_delta));
                int112 shareDelta = int112(int(_virtualSupply) * int(_delta) / int(_reserve0));
                _virtualSupply = _virtualSupply.sadd(shareDelta);
                // kick in/out fee votes
                Aggregate memory deltaFeeVote = deltaFeeVotes[_currentTick];
                aggregateFeeVote = aggregateFeeVote.sub(deltaFeeVote); // sub because we're crossing the tick from right to left
                // update tick info
                tickInfos[_currentTick] = TickInfo({
                    // TODO: the overflow trick may not work here... we may need to switch to uint40 for timestamp
                    secondsGrowthOutside: uint32(block.timestamp % 2**32) - uint32(timeInitialized) - _oldTickInfo.secondsGrowthOutside,
                    kGrowthOutside: k.uqdiv112(_oldKGrowthOutside)
                });
                emit Shift(_currentTick);
                if (feeOn) kLast = uint(_reserve0).mul(_reserve1);
                _currentTick -= 1;
            }
        }
        currentTick = _currentTick;
        TransferHelper.safeTransfer(token1, msg.sender, amountOut);
        if (data.length > 0) IUniswapV3Callee(to).uniswapV3Call(msg.sender, 0, totalAmountOut, data);
        TransferHelper.safeTransferFrom(token0, msg.sender, address(this), amountIn);
        _update(_oldReserve0, _oldReserve1, _reserve0, _reserve1);
        emit Swap(msg.sender, false, amountIn, amountOut, to);
    }

    function getTickPrice(int16 index) public pure returns (FixedPoint.uq112x112 memory) {
        // returns a UQ112x112 representing the price of token0 in terms of token1, at the tick with that index

        if (index == 0) {
            return FixedPoint.encode(1);
        }

        uint16 absIndex = index > 0 ? uint16(index) : uint16(-index);

        // compute 1.01^abs(index)
        // TODO: improve and fix this math, which is currently totally wrong
        // adapted from https://ethereum.stackexchange.com/questions/10425/is-there-any-efficient-way-to-compute-the-exponentiation-of-a-fraction-and-an-in
        FixedPoint.uq112x112 memory price = FixedPoint.encode(0);
        FixedPoint.uq112x112 memory N = FixedPoint.encode(1);
        uint112 B = 1;
        uint112 q = 100;
        uint precision = 50;
        for (uint i = 0; i < precision; ++i){
            price.add(N.div(B).div(q));
            N  = N.mul112(uint112(absIndex - uint112(i)));
            B = B * uint112(i+1);
            q = q * 100;
        }

        if (index < 0) {
            return price.reciprocal();
        }

        return price;
    }
}