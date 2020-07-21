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
    using SafeMath for uint112;
    using SafeMath for  int;
    using SafeMath for  int112;
    using FixedPoint for FixedPoint.uq112x112;

    // TODO: size
    uint112 public constant override LIQUIDITY_MIN = 10**3;
    uint16  public constant override FEE_VOTE_MAX  =  6000; // 6000 pips / 60 bips / 0.60%

    address public immutable override factory;
    address public immutable override token0;
    address public immutable override token1;

    // ⬇ single storage slot ⬇
    // TODO: size
    uint112 public override reserve0Virtual;
    // TODO: size
    uint112 public override reserve1Virtual;
    uint32  public override blockTimestampLast;
    // ⬆ single storage slot ⬆

    // the first price tick _at_ or _below_ the current (reserve1Virtual / reserve0Virtual) price
    int16 public override tickCurrent;
    // TODO: size
    uint112 public override liquidityVirtual; // the amount of virtual liquidity active for the current tick

    FeeVoting.Aggregate public feeVoteCurrent;

    FixedPoint.uq144x112 public price0CumulativeLast; // cumulative (reserve1Virtual / reserve0Virtual) oracle price
    FixedPoint.uq144x112 public price1CumulativeLast; // cumulative (reserve0Virtual / reserve1Virtual) oracle price

    // (reserve0Virtual * reserve1Virtual), as of immediately after the most recent liquidity event
    uint224 public override kLast;
    
    struct TickInfo {
        // seconds spent on the _other_ side of this tick (relative to the current tick)
        // only has relative meaning, not absolute — the value depends on when the tick is initialized
        uint32               secondsGrowthOutside;
        // fee growth on the _other_ side of this tick (relative to the current tick)
        // only has relative meaning, not absolute — the value depends on when the tick is initialized
        FixedPoint.uq112x112 growthOutside;

        // amount of token0 added when ticks are crossed from left to right,
        // i.e. as the (reserve1Virtual / reserve0Virtual) price goes up
        // TODO: size
        int112               token0VirtualDelta;

        // fee vote delta added when ticks are crossed from left to right,
        // i.e. as the (reserve1Virtual / reserve0Virtual) price goes up
        FeeVoting.Aggregate  feeVoteDelta;
    }
    mapping (int16 => TickInfo) public tickInfos;

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
        uint16  feeVote;
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

    // get fee growth (sqrt(reserve0Virtual * reserve1Virtual) / liquidity)
    function getG() public view returns (FixedPoint.uq112x112 memory g) {
        // safe, because uint(reserve0Virtual) * reserve1Virtual is guaranteed to fit in a uint224
        uint rootK = Babylonian.sqrt(uint(reserve0Virtual) * reserve1Virtual);
        // safe, if Babylonian.sqrt is correct, as what's being rooted is guaranteed to fit in a uint224
        g = FixedPoint.fraction(uint112(rootK), liquidityVirtual);
    }

    function _getGrowthBelow(int16 tick, FixedPoint.uq112x112 memory g)
        private
        view
        returns (FixedPoint.uq112x112 memory growthBelow)
    {
        growthBelow = tickInfos[tick].growthOutside;
        // tick is above currentTick, meaning growth outside is not sufficient
        if (tick > tickCurrent) {
            growthBelow = FixedPointExtra.divuq(g, growthBelow);
        }
    }

    function _getGrowthAbove(int16 tick, FixedPoint.uq112x112 memory g)
        private
        view
        returns (FixedPoint.uq112x112 memory growthAbove)
    {
        growthAbove = tickInfos[tick].growthOutside;
        // tick is at or below currentTick, meaning growth outside is not sufficient
        if (tick <= tickCurrent) {
            growthAbove = FixedPointExtra.divuq(g, growthAbove);
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
        growthInside = FixedPointExtra.muluq(FixedPointExtra.muluq(growthAbove, growthBelow).reciprocal(), g);
    }

    // given a price and a liquidity amount, return the value of that liquidity at the price
    // TODO ensure this is correct/safe
    function getValueAtPrice(FixedPoint.uq112x112 memory price, int112 liquidity)
        public
        pure
        returns (int112 amount0, int112 amount1)
    {
        amount0 = FixedPointExtra.muli(price.reciprocal().sqrt(), liquidity).itoInt112();
        amount1 = FixedPointExtra.muli(price, amount0).itoInt112();
    }

    constructor(address _token0, address _token1) public {
        factory = msg.sender;
        token0 = _token0;
        token1 = _token1;
    }

    // update reserves and, on the first call per block, price accumulators
    function _update(uint112 reserve0VirtualNext, uint112 reserve1VirtualNext) private {
        uint32 blockTimestamp = uint32(block.timestamp); // truncation is desired
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired
        if (timeElapsed > 0 && reserve0Virtual != 0 && reserve1Virtual != 0) {
            // overflow is desired
            price0CumulativeLast = FixedPoint.uq144x112(
                price0CumulativeLast._x + FixedPoint.fraction(reserve1Virtual, reserve0Virtual).mul(timeElapsed)._x
            );
            price1CumulativeLast = FixedPoint.uq144x112(
                price1CumulativeLast._x + FixedPoint.fraction(reserve0Virtual, reserve1Virtual).mul(timeElapsed)._x
            );
        }
        reserve0Virtual = reserve0VirtualNext;
        reserve1Virtual = reserve1VirtualNext;
        blockTimestampLast = blockTimestamp;
    }

    // if fee is on, mint liquidity equivalent to 1/6th of the growth in sqrt(k)
    // TODO: fix
    function _mintFee(uint112 _reserve0Virtual, uint112 _reserve1Virtual) private returns (bool feeOn) {
        address feeTo = IUniswapV3Factory(factory).feeTo();
        feeOn = feeTo != address(0);
        if (feeOn) {
            if (kLast != 0) {
                uint rootK = Babylonian.sqrt(uint(_reserve0Virtual) * _reserve1Virtual);
                uint rootKLast = Babylonian.sqrt(kLast);
                if (rootK > rootKLast) {
                    uint numerator = liquidityVirtual.mul(rootK.sub(rootKLast));
                    uint denominator = rootK.mul(5).add(rootKLast);
                    uint liquidity = numerator / denominator;
                    if (liquidity > 0) {
                        // TODO check this (set position.liquidityScalar/feeVote?)
                        Position storage position = _getPosition(feeTo, TickMath.MIN_TICK, TickMath.MAX_TICK);
                        liquidityVirtual = liquidityVirtual.add(liquidity).toUint112();
                        position.liquidity = position.liquidity.add(liquidity).toUint112();
                    }
                }
            }
        }
        // if the fee is not on, and kLast is not 0, set it to 0
        else if (kLast != 0) {
            kLast = 0;
        }
    }

    function initialize(uint112 amount0, uint112 amount1, int16 tick, uint16 feeVote) external lock {
        require(liquidityVirtual == 0, 'UniswapV3: ALREADY_INITIALIZED'); // valid check because of LIQUIDITY_MIN
        require(feeVote <= FEE_VOTE_MAX, 'UniswapV3: FEE_VOTE_TOO_LARGE');

        // ensure the tick witness is correct
        FixedPoint.uq112x112 memory price = FixedPoint.fraction(amount1, amount0);
        require(TickMath.getPrice(tick)._x <= price._x, 'UniswapV3: STARTING_TICK_TOO_LARGE');
        require(TickMath.getPrice(tick + 1)._x > price._x, 'UniswapV3: STARTING_TICK_TOO_SMALL');
        tickCurrent = tick;

        TransferHelper.safeTransferFrom(token0, msg.sender, address(this), amount0);
        TransferHelper.safeTransferFrom(token1, msg.sender, address(this), amount1);

        bool feeOn = _mintFee(0, 0);

        // will throw if amounts are insufficient to generate at least LIQUIDITY_MIN liquidity
        uint112 liquidity = uint112(Babylonian.sqrt(uint(amount0) * amount1).sub(LIQUIDITY_MIN));
        liquidityVirtual = liquidity + LIQUIDITY_MIN;

        // set a permanent LIQUIDITY_MIN position
        Position storage positionLiquidityMin = _getPosition(address(0), TickMath.MIN_TICK, TickMath.MAX_TICK);
        positionLiquidityMin.liquidity = LIQUIDITY_MIN;
        positionLiquidityMin.liquidityScalar = LIQUIDITY_MIN;
        positionLiquidityMin.feeVote = 0;

        // set the user's position
        Position storage position = _getPosition(msg.sender, TickMath.MIN_TICK, TickMath.MAX_TICK);
        position.liquidity = liquidity;
        position.liquidityScalar = liquidity;
        position.feeVote = feeVote;

        feeVoteCurrent = FeeVoting.totalFeeVote(position); // only vote with non-burned liquidity

        _update(amount0, amount1);
        if (feeOn) kLast = uint224(reserve0Virtual) * reserve1Virtual; // reserve{0,1}Virtual are up-to-date
    }

    function _initializeTick(int16 tick) private returns (TickInfo storage tickInfo) {
        tickInfo = tickInfos[tick];
        if (tickInfo.growthOutside._x == 0) {
            // by convention, we assume that all growth before a tick was initialized happened _below_ the tick
            if (tick <= tickCurrent) {
                tickInfo.secondsGrowthOutside = uint32(block.timestamp);
                tickInfo.growthOutside = getG();
            } else {
                tickInfo.secondsGrowthOutside = 0;
                tickInfo.growthOutside = FixedPoint.encode(1);
            }
        }
    }

    function _updateLiquidityVirtual(int112 liquidity)
        private
        returns (int112 amount0, int112 amount1)
    {
        bool feeOn = _mintFee(reserve0Virtual, reserve1Virtual);

        (amount0, amount1) = getValueAtPrice(FixedPoint.fraction(reserve1Virtual, reserve0Virtual), liquidity);
        // the price isn't changing, so no need to update the oracle
        reserve0Virtual = reserve0Virtual.addi(amount0).toUint112();
        reserve1Virtual = reserve1Virtual.addi(amount1).toUint112();
        liquidityVirtual = liquidityVirtual.addi(liquidity).toUint112();

        if (feeOn) kLast = uint224(reserve0Virtual) * reserve1Virtual;
    }

    // add or remove a specified amount of liquidity from a specified range, and/or change feeVote for that range
    // also sync a position and return accumulated fees from it to user as tokens
    // liquidityDelta is sqrt(reserve0Virtual * reserve1Virtual), so does not incorporate fees
    function setPosition(int16 tickLower, int16 tickUpper, int112 liquidityDelta, uint16 feeVote) external lock {
        require(liquidityVirtual > 0, 'UniswapV3: NOT_INITIALIZED'); // valid check because of LIQUIDITY_MIN
        require(tickLower < tickUpper, 'UniswapV3: BAD_TICKS');
        require(feeVote <= FEE_VOTE_MAX, 'UniswapV3: INVALID_FEE_VOTE');

        TickInfo storage tickInfoLower = _initializeTick(tickLower); // initialize tick idempotently
        TickInfo storage tickInfoUpper = _initializeTick(tickUpper); // initialize tick idempotently

        int112 amount0;
        int112 amount1;
        FeeVoting.Aggregate memory feeVoteDelta;

        {
        Position storage position = _getPosition(msg.sender, tickLower, tickUpper);
        FeeVoting.Aggregate memory feeVoteLast = FeeVoting.totalFeeVote(position);

        // rebate any collected fees to user (recompound by setting liquidityDelta to accumulated fees)
        FixedPoint.uq112x112 memory growthInside = getGrowthInside(tickLower, tickUpper);
        uint feeLiquidity = uint(FixedPoint.decode144(growthInside.mul(position.liquidityScalar)))
            .sub(position.liquidity);
        // credit the user for the value of their fee liquidity at the current price
        (amount0, amount1) = getValueAtPrice(
            FixedPoint.fraction(reserve1Virtual, reserve0Virtual), -(feeLiquidity.toInt112())
        );

        // update position
        position.liquidity = position.liquidity.addi(liquidityDelta).toUint112();
        position.liquidityScalar = uint(FixedPoint.decode144(growthInside.reciprocal().mul(position.liquidity)))
            .toUint112();
        position.feeVote = feeVote;

        feeVoteDelta = FeeVoting.sub(FeeVoting.totalFeeVote(position), feeVoteLast);
        }

        // calculate how much the specified virtual liquidity is worth at the prices determined by the lower and upper ticks
        // amount0Lower :> amount0Upper
        // amount1Upper :> amount1Lower
        (int112 amount0Lower, int112 amount1Lower) = getValueAtPrice(TickMath.getPrice(tickLower), liquidityDelta);
        (int112 amount0Upper, int112 amount1Upper) = getValueAtPrice(TickMath.getPrice(tickUpper), liquidityDelta);

        // regardless of current price, when lower tick is crossed from left to right amount0Lower should be added
        tickInfoLower.token0VirtualDelta = tickInfoLower.token0VirtualDelta.iadd(amount0Lower).itoInt112();
        // regardless of current price, when upper tick is crossed from left to right amount0Upper should be removed
        tickInfoUpper.token0VirtualDelta = tickInfoUpper.token0VirtualDelta.isub(amount0Upper).itoInt112();

        tickInfoLower.feeVoteDelta = FeeVoting.add(tickInfoLower.feeVoteDelta, feeVoteDelta);
        tickInfoUpper.feeVoteDelta = FeeVoting.sub(tickInfoUpper.feeVoteDelta, feeVoteDelta);

        // the current price is below the passed range, so the liquidity can only become in range by crossing from left
        // to right, at which point we'll need _more_ token0 (it's becoming more valuable) so the user must provide it
        if (tickCurrent < tickLower) {
            amount0 = amount0.iadd(amount0Lower.isub(amount0Upper)).itoInt112();
        }
        // the current price is inside the passed range
        else if (tickCurrent < tickUpper) {
            // the value of the liquidity at the current price
            (int112 amount0Virtual, int112 amount1Virtual) = _updateLiquidityVirtual(liquidityDelta);
            // update the fee vote
            feeVoteCurrent = FeeVoting.add(feeVoteCurrent, feeVoteDelta);
            // charge the user for the value of the liquidity at the current price
            amount0 = amount0.iadd(amount0Virtual.isub(amount0Upper)).itoInt112();
            amount1 = amount1.iadd(amount1Virtual.isub(amount1Lower)).itoInt112();
        }
        // the current price is above the passed range, so the liquidity can only become in range by crossing from right
        // to left, at which point we'll need _more_ token1 (it's becoming more valuable) so the user must provide it
        else {
            amount1 = amount1.iadd(amount1Upper.isub(amount1Lower)).itoInt112();
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
    function swap0For1(uint112 amount0In, address to, bytes calldata data) external lock {
        require(reserve0Virtual > 0 && reserve1Virtual > 0, 'UniswapV3: NO_LIQUIDITY');
        uint112 amount0InRemaining = amount0In;
        uint112 amount1Out;

        while (amount0InRemaining > 0) {
            FixedPoint.uq112x112 memory price = TickMath.getPrice(tickCurrent);

            {
            // compute how much token0 is required to push the price down to the next tick
            uint112 amount0InRequiredForShift = PriceMath.getTradeToRatio(
                reserve0Virtual, reserve1Virtual, FeeVoting.averageFee(feeVoteCurrent), price.reciprocal()
            );
            uint112 amount0InStep = amount0InRemaining > amount0InRequiredForShift ?
                amount0InRequiredForShift :
                amount0InRemaining;
            // adjust the step amount by the current fee
            uint112 amount0InAdjusted = uint112(
                uint(amount0InStep) *
                (PriceMath.LP_FEE_BASE - FeeVoting.averageFee(feeVoteCurrent)) /
                PriceMath.LP_FEE_BASE
            );
            uint112 amount1OutStep = (
                (uint(reserve1Virtual) * amount0InAdjusted) / (uint(reserve0Virtual) + amount0InAdjusted)
            ).toUint112();
            reserve0Virtual = (uint(reserve0Virtual) + amount0InStep).toUint112();
            reserve1Virtual = reserve1Virtual.sub(amount1OutStep).toUint112();
            amount0InRemaining = amount0InRemaining.sub(amount0InStep).toUint112();
            amount1Out = (uint(amount1Out) + amount1OutStep).toUint112();
            }

            // if a positive input amount still remains, we have to shift down to the next tick
            if (amount0InRemaining > 0) {
                TickInfo storage tickInfo = tickInfos[tickCurrent];
                if (tickInfo.growthOutside._x == 0) {
                    tickCurrent -= 1;
                    continue;
                }
                // TODO (eventually): batch all updates, including from mintFee
                bool feeOn = _mintFee(reserve0Virtual, reserve1Virtual);

                // kick in/out liquidity
                int112 token0VirtualDelta = tickInfo.token0VirtualDelta;
                int112 token1VirtualDelta = FixedPointExtra.muli(price, token0VirtualDelta).itoInt112();
                int112 liquidityVirtualDelta = (token0VirtualDelta.imul(liquidityVirtual) / reserve0Virtual)
                    .itoInt112();
                // subi because we're moving from right to left
                reserve0Virtual = reserve0Virtual.subi(token0VirtualDelta).toUint112();
                reserve1Virtual = reserve1Virtual.subi(token1VirtualDelta).toUint112();
                liquidityVirtual = liquidityVirtual.subi(liquidityVirtualDelta).toUint112();
                // kick in/out fee votes
                // sub because we're moving from right to left
                feeVoteCurrent = FeeVoting.sub(feeVoteCurrent, tickInfo.feeVoteDelta);
                // update tick info
                // overflow is desired
                tickInfo.secondsGrowthOutside = uint32(block.timestamp) - tickInfo.secondsGrowthOutside;
                tickInfo.growthOutside = FixedPointExtra.divuq(getG(), tickInfo.growthOutside);
                tickCurrent -= 1;
                if (feeOn) kLast = uint224(reserve0Virtual) * reserve1Virtual;
            }
        }
        // TODO: record new fees or something?
        TransferHelper.safeTransfer(token1, msg.sender, amount1Out);
        if (data.length > 0) IUniswapV3Callee(to).uniswapV3Call(msg.sender, 0, amount1Out, data);
        TransferHelper.safeTransferFrom(token0, msg.sender, address(this), amount0In);
        _update(reserve0Virtual, reserve1Virtual);
    }
}