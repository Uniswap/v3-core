// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.11;
pragma experimental ABIEncoderV2;

import '@uniswap/lib/contracts/libraries/FixedPoint.sol';
import '@uniswap/lib/contracts/libraries/Babylonian.sol';
import '@uniswap/lib/contracts/libraries/TransferHelper.sol';

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

    enum FeeVote {
        FeeVote0, //  .10%
        FeeVote1, //  .30%
        FeeVote2, //  .50%
        FeeVote3  // 1.00%
    }

    uint112 public constant override LIQUIDITY_MIN = 1000;
    // TODO could this be 100, or does it need to be 102, or higher?
    // TODO this could potentially affect how many ticks we need to support
    uint8   public constant override TOKEN_MIN     = 101;

    address public immutable override factory;
    address public immutable override token0;
    address public immutable override token1;

    // ⬇ single storage slot ⬇
    uint112 public override reserve0Virtual;
    uint112 public override reserve1Virtual;
    uint32  public override blockTimestampLast;
    // ⬆ single storage slot ⬆

    // the first price tick _at_ or _below_ the current (reserve1Virtual / reserve0Virtual) price
    // stored to avoid computing log_1.01(reserve1Virtual / reserve0Virtual) on-chain
    int16 public override tickCurrent;

    // the amount of virtual supply active within the current tick, for each fee vote
    uint112[4] public override virtualSupplies;

    FixedPoint.uq144x112 public price0CumulativeLast; // cumulative (reserve1Virtual / reserve0Virtual) oracle price
    FixedPoint.uq144x112 public price1CumulativeLast; // cumulative (reserve0Virtual / reserve1Virtual) oracle price
    
    struct TickInfo {
        // fee growth on the _other_ side of this tick (relative to the current tick)
        // only has relative meaning, not absolute — the value depends on when the tick is initialized
        FixedPoint.uq112x112 growthOutside;
        // seconds spent on the _other_ side of this tick (relative to the current tick)
        // only has relative meaning, not absolute — the value depends on when the tick is initialized
        uint32               secondsOutside;

        // amount of token0 added when ticks are crossed from left to right
        // (i.e. as the (reserve1Virtual / reserve0Virtual) price goes up), for each fee vote
        int112[4]            token0VirtualDeltas;
    }
    mapping (int16 => TickInfo) public tickInfos;

    struct Position {
        // the amount of liquidity (sqrt(amount0 * amount1)).
        // does not increase automatically as fees accumulate, it remains sqrt(amount0 * amount1) until modified.
        // fees may be collected directly by calling setPosition with liquidityDelta set to 0.
        // fees may be compounded by calling setPosition with liquidityDelta set to the accumulated fees.
        uint112 liquidity;
        // the amount of liquidity adjusted for fee growth (liquidity / growthInside) as of the last modification.
        // will be smaller than liquidity if any fees have been earned in range.
        uint112 liquidityAdjusted;
    }
    mapping (bytes32 => Position) public positions;

    uint public unlocked = 1;
    modifier lock() {
        require(unlocked == 1, 'UniswapV3: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    function _getPosition(address owner, int16 tickLower, int16 tickUpper, FeeVote feeVote)
        private
        view
        returns (Position storage position)
    {
        assert(tickLower >= TickMath.MIN_TICK);
        assert(tickUpper <= TickMath.MAX_TICK);
        position = positions[keccak256(abi.encodePacked(owner, tickLower, tickUpper, feeVote))];
    }

    // sum the virtual supply across all fee votes to get the total
    function getVirtualSupply() public view returns (uint112 virtualSupply) {
        virtualSupply =
            virtualSupplies[uint8(FeeVote.FeeVote0)] +
            virtualSupplies[uint8(FeeVote.FeeVote1)] +
            virtualSupplies[uint8(FeeVote.FeeVote2)] +
            virtualSupplies[uint8(FeeVote.FeeVote3)];
    }

    // find the median fee vote, and return the fee in pips
    function getFee() public view returns (uint16 fee) {
        FeeVote feeVote = FeeVote.FeeVote0;
        uint112 virtualSupplyCumulative = virtualSupplies[uint8(feeVote)];
        uint112 virtualSupply = getVirtualSupply();
        while (virtualSupplyCumulative < (virtualSupply / 2)) {
            feeVote =
                feeVote == FeeVote.FeeVote0 ? FeeVote.FeeVote1 :
                feeVote == FeeVote.FeeVote1 ? FeeVote.FeeVote2 : FeeVote.FeeVote3;
            virtualSupplyCumulative += virtualSupplies[uint8(feeVote)];
        }
        fee =
            feeVote == FeeVote.FeeVote0 ? 1000 :
            feeVote == FeeVote.FeeVote1 ? 3000 :
            feeVote == FeeVote.FeeVote2 ? 5000 : 10000;
    }

    // get fee growth (sqrt(reserve0Virtual * reserve1Virtual) / virtualSupply)
    function getG() public view returns (FixedPoint.uq112x112 memory g) {
        // safe, because uint(reserve0Virtual) * reserve1Virtual is guaranteed to fit in a uint224
        uint112 rootK = uint112(Babylonian.sqrt(uint(reserve0Virtual) * reserve1Virtual));
        g = FixedPoint.fraction(rootK, getVirtualSupply());
    }

    // gets the growth in g between two ticks
    // this only has relative meaning, not absolute
    // TODO: simpler or more precise way to compute this?
    function _getGrowthBelow(int16 tick, TickInfo storage tickInfo, FixedPoint.uq112x112 memory g)
        private
        view
        returns (FixedPoint.uq112x112 memory growthBelow)
    {
        growthBelow = tickInfo.growthOutside;
        assert(growthBelow._x != 0);
        // tick is above the current tick, meaning growth outside represents growth above, not below, so adjust
        if (tick > tickCurrent) {
            growthBelow = FixedPointExtra.divuq(g, growthBelow);
        }
    }
    function _getGrowthAbove(int16 tick, TickInfo storage tickInfo, FixedPoint.uq112x112 memory g)
        private
        view
        returns (FixedPoint.uq112x112 memory growthAbove)
    {
        growthAbove = tickInfo.growthOutside;
        assert(growthAbove._x != 0);
        // tick is at or below the current tick, meaning growth outside represents growth below, not above, so adjust
        if (tick <= tickCurrent) {
            growthAbove = FixedPointExtra.divuq(g, growthAbove);
        }
    }
    function _getGrowthInside(
        int16 tickLower,
        int16 tickUpper,
        TickInfo storage tickInfoLower,
        TickInfo storage tickInfoUpper
    )
        private
        view
        returns (FixedPoint.uq112x112 memory growthInside)
    {
        FixedPoint.uq112x112 memory g = getG();
        FixedPoint.uq112x112 memory growthBelow = _getGrowthBelow(tickLower, tickInfoLower, g);
        FixedPoint.uq112x112 memory growthAbove = _getGrowthAbove(tickUpper, tickInfoUpper, g);
        growthInside = FixedPointExtra.divuq(g, FixedPointExtra.muluq(growthBelow, growthAbove));
    }

    // given a price and a liquidity amount, return the value of that liquidity at the price
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
        // initialize min and max ticks
        TickInfo storage tick = tickInfos[TickMath.MIN_TICK];
        tick.growthOutside = FixedPoint.encode(1);
        tick = tickInfos[TickMath.MAX_TICK];
        tick.growthOutside = FixedPoint.encode(1);
    }

    // update reserves and, on the first interaction per block, price accumulators
    function _update() private {
        uint32 blockTimestamp = uint32(block.timestamp); // truncation is desired
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired
        if (timeElapsed > 0) {
            // TODO these may not be necessary, or we may have to short-circuit if either are true
            assert(reserve0Virtual != 0);
            assert(reserve1Virtual != 0);
            // overflow is desired
            price0CumulativeLast = FixedPoint.uq144x112(
                price0CumulativeLast._x + FixedPoint.fraction(reserve1Virtual, reserve0Virtual).mul(timeElapsed)._x
            );
            price1CumulativeLast = FixedPoint.uq144x112(
                price1CumulativeLast._x + FixedPoint.fraction(reserve0Virtual, reserve1Virtual).mul(timeElapsed)._x
            );
            blockTimestampLast = blockTimestamp;
        }
    }

    // the reason this can't _just_ burn but needs to mint is because otherwise it would incentivize bad starting prices
    function initialize(uint112 amount0, uint112 amount1, int16 tick, FeeVote feeVote)
        external lock returns (uint112 liquidity)
    {
        require(getVirtualSupply() == 0,   'UniswapV3: ALREADY_INITIALIZED'); // sufficient check
        require(amount0 >= TOKEN_MIN,      'UniswapV3: AMOUNT_0_TOO_SMALL');
        require(amount1 >= TOKEN_MIN,      'UniswapV3: AMOUNT_1_TOO_SMALL');
        require(tick >= TickMath.MIN_TICK, 'UniswapV3: TICK_TOO_SMALL');
        require(tick <  TickMath.MAX_TICK, 'UniswapV3: TICK_TOO_LARGE');

        // ensure the tick witness is correct
        FixedPoint.uq112x112 memory price = FixedPoint.fraction(amount1, amount0);
        require(TickMath.getRatioAtTick(tick    )._x <= price._x, 'UniswapV3: STARTING_TICK_TOO_LARGE');
        require(TickMath.getRatioAtTick(tick + 1)._x >  price._x, 'UniswapV3: STARTING_TICK_TOO_SMALL');

        // ensure that at a minimum amount of liquidity will be generated
        liquidity = uint112(Babylonian.sqrt(uint(amount0) * amount1));
        require(liquidity >= LIQUIDITY_MIN, 'UniswapV3: LIQUIDITY_TOO_SMALL');

        // take the tokens
        TransferHelper.safeTransferFrom(token0, msg.sender, address(this), amount0);
        TransferHelper.safeTransferFrom(token1, msg.sender, address(this), amount1);

        // initialize reserves and oracle timestamp
        reserve0Virtual = amount0;
        reserve1Virtual = amount1;
        blockTimestampLast = uint32(block.timestamp);

        // initialize tick
        tickCurrent = tick;

        // initialize virtualSupplies (note that this votes indelibly with the burned liquidity)
        virtualSupplies[uint8(feeVote)] = liquidity;

        // set the permanent LIQUIDITY_MIN position
        Position storage position = _getPosition(address(0), TickMath.MIN_TICK, TickMath.MAX_TICK, feeVote);
        position.liquidity         = LIQUIDITY_MIN;
        position.liquidityAdjusted = LIQUIDITY_MIN;

        // set the user's position if necessary
        if (liquidity > LIQUIDITY_MIN) {
            position = _getPosition(msg.sender, TickMath.MIN_TICK, TickMath.MAX_TICK, feeVote);
            position.liquidity         = liquidity - LIQUIDITY_MIN;
            position.liquidityAdjusted = liquidity - LIQUIDITY_MIN;
        }
    }

    function _initializeTick(int16 tick) private returns (TickInfo storage tickInfo) {
        tickInfo = tickInfos[tick];
        if (tickInfo.growthOutside._x == 0) {
            // by convention, we assume that all growth before a tick was initialized happened _below_ the tick
            if (tick <= tickCurrent) {
                tickInfo.growthOutside = getG();
                tickInfo.secondsOutside = uint32(block.timestamp);
            } else {
                tickInfo.growthOutside = FixedPoint.encode(1);
            }
        }
    }

    function getLiquidityFee(int16 tickLower, int16 tickUpper, FeeVote feeVote) public view returns (int112 amount0, int112 amount1) {
        TickInfo storage tickInfoLower = tickInfos[tickLower];
        TickInfo storage tickInfoUpper = tickInfos[tickUpper];
        FixedPoint.uq112x112 memory growthInside = _getGrowthInside(tickLower, tickUpper, tickInfoLower, tickInfoUpper);

        FixedPoint.uq112x112 memory price = FixedPoint.fraction(reserve1Virtual, reserve0Virtual);

        Position storage position = _getPosition(msg.sender, tickLower, tickUpper, feeVote);
        uint liquidityFee =
            uint(FixedPoint.decode144(growthInside.mul(position.liquidityAdjusted))).sub(position.liquidity);

        (amount0, amount1) = getValueAtPrice(price, liquidityFee.toInt112());
    }

    // add or remove a specified amount of liquidity from a specified range, and/or change feeVote for that range
    // also sync a position and return accumulated fees from it to user as tokens
    // liquidityDelta is sqrt(reserve0Virtual * reserve1Virtual), so does not incorporate fees
    function setPosition(int16 tickLower, int16 tickUpper, FeeVote feeVote, int112 liquidityDelta)
        external lock returns (int112 amount0, int112 amount1)
    {
        require(getVirtualSupply() > 0,         'UniswapV3: NOT_INITIALIZED'); // sufficient check
        require(tickLower >= TickMath.MIN_TICK, 'UniswapV3: LOWER_TICK');
        require(tickUpper <= TickMath.MAX_TICK, 'UniswapV3: UPPER_TICK');
        require(tickLower <  tickUpper,         'UniswapV3: TICKS');

        TickInfo storage tickInfoLower = _initializeTick(tickLower); // initialize tick idempotently
        TickInfo storage tickInfoUpper = _initializeTick(tickUpper); // initialize tick idempotently

        FixedPoint.uq112x112 memory price = FixedPoint.fraction(reserve1Virtual, reserve0Virtual);
        {
        Position storage position = _getPosition(msg.sender, tickLower, tickUpper, feeVote);
        FixedPoint.uq112x112 memory growthInside = _getGrowthInside(tickLower, tickUpper, tickInfoLower, tickInfoUpper);

        // this condition is a heuristic for whether the position _could_ have unaccrued fees
        if (position.liquidityAdjusted > 0) {
            // TODO is this calculation correct/precise?
            uint liquidityFee =
                uint(FixedPoint.decode144(growthInside.mul(position.liquidityAdjusted))).sub(position.liquidity);

            // if the position in fact does have accrued fees, handle them
            if (liquidityFee > 0) {
                address feeTo = IUniswapV3Factory(factory).feeTo();
                bool feeOn = feeTo != address(0);
                // take the protocol fee if it's on and te sender isn't feeTo
                if (feeOn && msg.sender != feeTo) {
                    // TODO figure out how we want to actually issue liquidityProtocol to feeTo
                    uint liquidityProtocol = liquidityFee / 6;
                    liquidityFee -= liquidityProtocol;
                }

                // credit the caller for the value of the fee liquidity
                (amount0, amount1) = getValueAtPrice(price, -(liquidityFee.toInt112()));
            }
        }

        // update position
        position.liquidity = position.liquidity.addi(liquidityDelta).toUint112();
        position.liquidityAdjusted =
            uint(FixedPoint.decode144(growthInside.reciprocal().mul(position.liquidity))).toUint112();
        }

        // calculate how much the specified liquidity delta is worth at the lower and upper ticks
        // amount0Lower :> amount0Upper
        // amount1Upper :> amount1Lower
        (int112 amount0Lower, int112 amount1Lower) =
            getValueAtPrice(TickMath.getRatioAtTick(tickLower), liquidityDelta);
        (int112 amount0Upper, int112 amount1Upper) =
            getValueAtPrice(TickMath.getRatioAtTick(tickUpper), liquidityDelta);

        // regardless of current price, when lower tick is crossed from left to right, amount0Lower should be added
        if (tickLower > TickMath.MIN_TICK) {
            tickInfoLower.token0VirtualDeltas[uint8(feeVote)] =
                tickInfoLower.token0VirtualDeltas[uint8(feeVote)].iadd(amount0Lower).itoInt112();
        }
        // regardless of current price, when upper tick is crossed from left to right amount0Upper should be removed
        if (tickUpper < TickMath.MAX_TICK) {
            tickInfoUpper.token0VirtualDeltas[uint8(feeVote)] =
                tickInfoUpper.token0VirtualDeltas[uint8(feeVote)].isub(amount0Upper).itoInt112();
        }

        // the current price is below the passed range, so the liquidity can only become in range by crossing from left
        // to right, at which point we'll need _more_ token0 (it's becoming more valuable) so the user must provide it
        if (tickCurrent < tickLower) {
            amount0 = amount0.iadd(amount0Lower.isub(amount0Upper)).itoInt112();
        }
        // the current price is inside the passed range
        else if (tickCurrent < tickUpper) {
            // value the liquidity delta at the current price
            {
            (int112 amount0Current, int112 amount1Current) = getValueAtPrice(price, liquidityDelta);

            // charge the user whatever is required to cover their position
            amount0 = amount0.iadd(amount0Current.isub(amount0Upper)).itoInt112();
            amount1 = amount1.iadd(amount1Current.isub(amount1Lower)).itoInt112();

            // update reserves (the price doesn't change, so no need to update the oracle or current tick)
            reserve0Virtual = reserve0Virtual.addi(amount0Current).toUint112();
            reserve1Virtual = reserve1Virtual.addi(amount1Current).toUint112();
            require(reserve0Virtual >= TOKEN_MIN, 'UniswapV3: RESERVE_0_TOO_SMALL');
            require(reserve1Virtual >= TOKEN_MIN, 'UniswapV3: RESERVE_1_TOO_SMALL');
            }
            // update liquidity
            virtualSupplies[uint8(feeVote)] = virtualSupplies[uint8(feeVote)].addi(liquidityDelta).toUint112();
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
    function swap0For1(uint112 amount0In, address to, bytes calldata data) external lock returns (uint112 amount1Out) {
        require(amount0In > 0, 'UniswapV3: INSUFFICIENT_INPUT_AMOUNT');
        _update(); // update the oracle

        uint112 amount0InRemaining = amount0In;
        while (amount0InRemaining > 0) {
            // TODO these conditions almost certainly need to be tweaked/put in a different place
            assert(tickCurrent >= TickMath.MIN_TICK);
            // ensure that there is enough liquidity to guarantee we can get a price within the next tick
            require(reserve0Virtual >= TOKEN_MIN, 'UniswapV3: INSUFFICIENT_LIQUIDITY');
            require(reserve1Virtual >= TOKEN_MIN, 'UniswapV3: INSUFFICIENT_LIQUIDITY');

            // get the inclusive lower bound price for the current tick
            FixedPoint.uq112x112 memory price = TickMath.getRatioAtTick(tickCurrent);
            // get the current fee
            uint16 fee = getFee();
            // compute the amount of token0 required s.t. the price is ~the lower bound for the current tick
            // TODO adjust this amount (or amount1OutStep) so that we're guaranteed the ratio is as close (or equal)
            // to the lower bound _without_ exceeding it as possible
            uint112 amount0InRequiredForShift = PriceMath.getInputToRatio(
                reserve0Virtual, reserve1Virtual, fee, price.reciprocal()
            );

            // only trade as much as we need to
            {
            uint112 amount0InStep = amount0InRemaining > amount0InRequiredForShift ?
                amount0InRequiredForShift :
                amount0InRemaining;
            // adjust the step amount by the current fee
            uint112 amount0InAdjusted = uint112(
                uint(amount0InStep) * (PriceMath.LP_FEE_BASE - fee) / PriceMath.LP_FEE_BASE
            );
            // calculate the output amount
            uint112 amount1OutStep = (
                uint(reserve1Virtual) * amount0InAdjusted / (uint(reserve0Virtual) + amount0InAdjusted)
            ).toUint112();
            reserve0Virtual = (uint(reserve0Virtual) + amount0InStep).toUint112();
            reserve1Virtual = reserve1Virtual.sub(amount1OutStep).toUint112();
            amount0InRemaining = amount0InRemaining.sub(amount0InStep).toUint112();
            amount1Out = (uint(amount1Out) + amount1OutStep).toUint112();
            }

            // if a positive input amount still remains, we have to shift down to the next tick
            if (amount0InRemaining > 0) {
                TickInfo storage tickInfo = tickInfos[tickCurrent];
                // if the current tick is uninitialized, we can short-circuit the tick transition logic
                if (tickInfo.growthOutside._x == 0) {
                    tickCurrent -= 1;
                    continue;
                }

                // calculate the amount of reserves + liquidity to kick in/out
                int112 token0VirtualDelta =
                    tickInfo.token0VirtualDeltas[uint8(FeeVote.FeeVote0)] +
                    tickInfo.token0VirtualDeltas[uint8(FeeVote.FeeVote1)] +
                    tickInfo.token0VirtualDeltas[uint8(FeeVote.FeeVote2)] +
                    tickInfo.token0VirtualDeltas[uint8(FeeVote.FeeVote3)];
                // TODO we have to do this in an overflow-safe way 
                // TODO this should always move the price _down_ (if it has to move at all), because that's the
                // direction we're moving...floor division should ensure that this is the case with positive deltas,
                // but not with negative
                int112 token1VirtualDelta = FixedPointExtra.muli(price, token0VirtualDelta).itoInt112();
                // TODO i think we could squeeze out a tiny bit more precision under certain circumstances by doing:
                // a) summing total negative and positive token0VirtualDeltas
                // b) calculating the total negative and positive virtualSupply delta
                // c) allocating these deltas proportionally across virtualSupplies
                // (where the sign of the delta determines which total to use and the value determines proportion)
                // note: this may be overkill/unnecessary
                uint112 virtualSupply = getVirtualSupply();
                int112[4] memory virtualSupplyDeltas = [
                    (tickInfo.token0VirtualDeltas[uint8(FeeVote.FeeVote0)].imul(virtualSupply) / reserve0Virtual)
                        .itoInt112(),
                    (tickInfo.token0VirtualDeltas[uint8(FeeVote.FeeVote1)].imul(virtualSupply) / reserve0Virtual)
                        .itoInt112(),
                    (tickInfo.token0VirtualDeltas[uint8(FeeVote.FeeVote2)].imul(virtualSupply) / reserve0Virtual)
                        .itoInt112(),
                    (tickInfo.token0VirtualDeltas[uint8(FeeVote.FeeVote3)].imul(virtualSupply) / reserve0Virtual)
                        .itoInt112()
                ];

                // subi because we're moving from right to left
                reserve0Virtual = reserve0Virtual.subi(token0VirtualDelta).toUint112();
                reserve1Virtual = reserve1Virtual.subi(token1VirtualDelta).toUint112();
                virtualSupplies[uint8(FeeVote.FeeVote0)] = virtualSupplies[uint8(FeeVote.FeeVote0)]
                    .subi(virtualSupplyDeltas[uint8(FeeVote.FeeVote0)]).toUint112();
                virtualSupplies[uint8(FeeVote.FeeVote1)] = virtualSupplies[uint8(FeeVote.FeeVote1)]
                    .subi(virtualSupplyDeltas[uint8(FeeVote.FeeVote1)]).toUint112();
                virtualSupplies[uint8(FeeVote.FeeVote2)] = virtualSupplies[uint8(FeeVote.FeeVote2)]
                    .subi(virtualSupplyDeltas[uint8(FeeVote.FeeVote2)]).toUint112();
                virtualSupplies[uint8(FeeVote.FeeVote3)] = virtualSupplies[uint8(FeeVote.FeeVote3)]
                    .subi(virtualSupplyDeltas[uint8(FeeVote.FeeVote3)]).toUint112();

                // update tick info
                // overflow is desired
                tickInfo.growthOutside = FixedPointExtra.divuq(getG(), tickInfo.growthOutside);
                tickInfo.secondsOutside = uint32(block.timestamp) - tickInfo.secondsOutside;

                tickCurrent -= 1;
            }
        }

        TransferHelper.safeTransfer(token1, to, amount1Out); // optimistically transfer tokens
        if (data.length > 0) IUniswapV3Callee(to).uniswapV3Call(msg.sender, 0, amount1Out, data);
        TransferHelper.safeTransferFrom(token0, msg.sender, address(this), amount0In); // this is different than v2
    }
}
