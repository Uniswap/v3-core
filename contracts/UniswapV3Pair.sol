// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.12;
pragma experimental ABIEncoderV2;

import '@uniswap/lib/contracts/libraries/FixedPoint.sol';
import '@uniswap/lib/contracts/libraries/Babylonian.sol';
import '@uniswap/lib/contracts/libraries/TransferHelper.sol';

import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/math/SignedSafeMath.sol';

import './libraries/SafeCast.sol';
import './libraries/MixedSafeMath.sol';
import './libraries/TickMath.sol';
import './libraries/PriceMath.sol';

import './interfaces/IUniswapV3Pair.sol';
import './interfaces/IUniswapV3Factory.sol';
import './interfaces/IUniswapV3Callee.sol';

contract UniswapV3Pair is IUniswapV3Pair {
    using SafeMath for uint256;
    using SafeMath for uint112;
    using SignedSafeMath for int256;
    using SignedSafeMath for int112;
    using SafeCast for *;
    using MixedSafeMath for *;
    using FixedPoint for *;

    // Number of fee options
    uint8 public constant override NUM_FEE_OPTIONS = 6;

    // list of fee options expressed as bips
    // uint16 because the maximum value is 10_000
    // options are 0.05%, 0.10%, 0.30%, 0.60%, 1.00%, 2.00%
    // ideally this would be a constant array, but constant arrays are not supported in solidity
    function FEE_OPTIONS() public pure returns (uint16[NUM_FEE_OPTIONS] memory) {
        return [uint16(5), 10, 30, 60, 100, 200];
    }

    uint112 public constant override LIQUIDITY_MIN = 1000;

    // TODO could this be 100, or does it need to be 102, or higher?
    // TODO this could potentially affect how many ticks we need to support
    uint8 public constant override TOKEN_MIN = 101;

    address public immutable override factory;
    address public immutable override token0;
    address public immutable override token1;

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
    uint16 public feeLast;

    // the amount of virtual supply active within the current tick, for each fee vote
    uint112[NUM_FEE_OPTIONS] public override virtualSupplies;

    uint256 public override price0CumulativeLast; // cumulative (reserve1Virtual / reserve0Virtual) oracle price
    uint256 public override price1CumulativeLast; // cumulative (reserve0Virtual / reserve1Virtual) oracle price

    struct TickInfo {
        // fee growth on the _other_ side of this tick (relative to the current tick)
        // only has relative meaning, not absolute — the value depends on when the tick is initialized
        FixedPoint.uq112x112 growthOutside;
        // seconds spent on the _other_ side of this tick (relative to the current tick)
        // only has relative meaning, not absolute — the value depends on when the tick is initialized
        uint32 secondsOutside;
        // amount of token0 added when ticks are crossed from left to right
        // (i.e. as the (reserve1Virtual / reserve0Virtual) price goes up), for each fee vote
        int112[NUM_FEE_OPTIONS] token0VirtualDeltas;
    }
    mapping(int16 => TickInfo) public tickInfos;

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
    mapping(bytes32 => Position) public positions;

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
        assert(tickLower >= TickMath.MIN_TICK);
        assert(tickUpper <= TickMath.MAX_TICK);
        position = positions[keccak256(abi.encodePacked(owner, tickLower, tickUpper, feeVote))];
    }

    // sum the virtual supply across all fee votes to get the total
    function getVirtualSupply() public view override returns (uint112 virtualSupply) {
        virtualSupply =
            virtualSupplies[0] +
            virtualSupplies[1] +
            virtualSupplies[2] +
            virtualSupplies[3] +
            virtualSupplies[4] +
            virtualSupplies[5];
    }

    // find the median fee vote, and return the fee in bips
    function getFee() public view override returns (uint16 fee) {
        uint112 virtualSupplyCumulative;
        // load all virtual supplies into memory
        uint112[NUM_FEE_OPTIONS] memory virtualSupplies_ = [
            virtualSupplies[0],
            virtualSupplies[1],
            virtualSupplies[2],
            virtualSupplies[3],
            virtualSupplies[4],
            virtualSupplies[5]
        ];
        uint112 threshold = (virtualSupplies_[0] +
            virtualSupplies_[1] +
            virtualSupplies_[2] +
            virtualSupplies_[3] +
            virtualSupplies_[4] +
            virtualSupplies_[5]) / 2;
        uint16[NUM_FEE_OPTIONS] memory feeOptions = FEE_OPTIONS();
        for (uint8 feeVoteIndex = 0; feeVoteIndex < NUM_FEE_OPTIONS - 1; feeVoteIndex++) {
            virtualSupplyCumulative += virtualSupplies_[feeVoteIndex];
            if (virtualSupplyCumulative >= threshold) {
                return feeOptions[feeVoteIndex];
            }
        }
        return feeOptions[NUM_FEE_OPTIONS - 1];
    }

    // get fee growth (sqrt(reserve0Virtual * reserve1Virtual) / virtualSupply)
    function getG() public view returns (FixedPoint.uq112x112 memory g) {
        // safe, because uint(reserve0Virtual) * reserve1Virtual is guaranteed to fit in a uint224
        uint112 rootK = uint112(Babylonian.sqrt(uint256(reserve0Virtual) * reserve1Virtual));
        g = FixedPoint.fraction(rootK, getVirtualSupply());
    }

    // gets the growth in g between two ticks
    // this only has relative meaning, not absolute
    // TODO: simpler or more precise way to compute this?
    function _getGrowthBelow(
        int16 tick,
        TickInfo storage tickInfo,
        FixedPoint.uq112x112 memory g
    ) private view returns (FixedPoint.uq112x112 memory growthBelow) {
        growthBelow = tickInfo.growthOutside;
        assert(growthBelow._x != 0);
        // tick is above the current tick, meaning growth outside represents growth above, not below, so adjust
        if (tick > tickCurrent) {
            growthBelow = g.divuq(growthBelow);
        }
    }

    function _getGrowthAbove(
        int16 tick,
        TickInfo storage tickInfo,
        FixedPoint.uq112x112 memory g
    ) private view returns (FixedPoint.uq112x112 memory growthAbove) {
        growthAbove = tickInfo.growthOutside;
        assert(growthAbove._x != 0);
        // tick is at or below the current tick, meaning growth outside represents growth below, not above, so adjust
        if (tick <= tickCurrent) {
            growthAbove = g.divuq(growthAbove);
        }
    }

    function _getGrowthInside(
        int16 tickLower,
        int16 tickUpper,
        TickInfo storage tickInfoLower,
        TickInfo storage tickInfoUpper
    ) private view returns (FixedPoint.uq112x112 memory growthInside) {
        FixedPoint.uq112x112 memory g = getG();
        FixedPoint.uq112x112 memory growthBelow = _getGrowthBelow(tickLower, tickInfoLower, g);
        FixedPoint.uq112x112 memory growthAbove = _getGrowthAbove(tickUpper, tickInfoUpper, g);
        growthInside = g.divuq(growthBelow.muluq(growthAbove));
    }

    // given a price and a liquidity amount, return the value of that liquidity at the price
    // note: this is imprecise (potentially by >1 bit?) because it uses reciprocal and sqrt
    // note: this may not return in the _exact_ ratio of the passed price (amount1 accurate to < 1 bit given amonut0)
    function getValueAtPrice(FixedPoint.uq112x112 memory price, int112 liquidity)
        public
        pure
        returns (int112 amount0, int112 amount1)
    {
        amount0 = price.reciprocal().sqrt().muli(liquidity).toInt112();
        amount1 = price.muli(amount0).toInt112();
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
        TickInfo storage tick = tickInfos[TickMath.MIN_TICK];
        tick.growthOutside = FixedPoint.encode(1);
        tick = tickInfos[TickMath.MAX_TICK];
        tick.growthOutside = FixedPoint.encode(1);
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

    // the reason this can't _just_ burn but needs to mint is because otherwise it would incentivize bad starting prices
    function initialize(
        uint112 amount0,
        uint112 amount1,
        int16 tick,
        uint8 feeVote
    ) external lock returns (uint112 liquidity) {
        require(getVirtualSupply() == 0, 'UniswapV3: ALREADY_INITIALIZED'); // sufficient check
        require(amount0 >= TOKEN_MIN, 'UniswapV3: AMOUNT_0_TOO_SMALL');
        require(amount1 >= TOKEN_MIN, 'UniswapV3: AMOUNT_1_TOO_SMALL');
        require(tick >= TickMath.MIN_TICK, 'UniswapV3: TICK_TOO_SMALL');
        require(tick < TickMath.MAX_TICK, 'UniswapV3: TICK_TOO_LARGE');

        // ensure the tick witness is correct
        FixedPoint.uq112x112 memory price = FixedPoint.fraction(amount1, amount0);
        require(TickMath.getRatioAtTick(tick)._x <= price._x, 'UniswapV3: STARTING_TICK_TOO_LARGE');
        require(TickMath.getRatioAtTick(tick + 1)._x > price._x, 'UniswapV3: STARTING_TICK_TOO_SMALL');

        // ensure that at a minimum amount of liquidity will be generated
        liquidity = uint112(Babylonian.sqrt(uint256(amount0) * amount1));
        require(liquidity >= LIQUIDITY_MIN, 'UniswapV3: LIQUIDITY_TOO_SMALL');

        // take the tokens
        TransferHelper.safeTransferFrom(token0, msg.sender, address(this), amount0);
        TransferHelper.safeTransferFrom(token1, msg.sender, address(this), amount1);

        // initialize reserves and oracle timestamp
        reserve0Virtual = amount0;
        reserve1Virtual = amount1;
        blockTimestampLast = _blockTimestamp();

        // initialize virtualSupplies (note that this votes indelibly with the burned liquidity)
        virtualSupplies[feeVote] = liquidity;

        // initialize tick and fee
        tickCurrent = tick;
        feeLast = getFee();

        // set the permanent LIQUIDITY_MIN position
        Position storage position = _getPosition(address(0), TickMath.MIN_TICK, TickMath.MAX_TICK, feeVote);
        position.liquidity = LIQUIDITY_MIN;
        position.liquidityAdjusted = LIQUIDITY_MIN;
        emit PositionSet(address(0), TickMath.MIN_TICK, TickMath.MAX_TICK, feeVote, int112(LIQUIDITY_MIN));

        // set the user's position if necessary
        if (liquidity > LIQUIDITY_MIN) {
            position = _getPosition(msg.sender, TickMath.MIN_TICK, TickMath.MAX_TICK, feeVote);
            position.liquidity = liquidity - LIQUIDITY_MIN;
            position.liquidityAdjusted = liquidity - LIQUIDITY_MIN;
            emit PositionSet(
                msg.sender,
                TickMath.MIN_TICK,
                TickMath.MAX_TICK,
                feeVote,
                int112(liquidity) - int112(LIQUIDITY_MIN)
            );
        }

        emit Initialized(amount0, amount1, tick, feeVote);
    }

    function _initializeTick(int16 tick) private returns (TickInfo storage tickInfo) {
        tickInfo = tickInfos[tick];
        if (tickInfo.growthOutside._x == 0) {
            // by convention, we assume that all growth before a tick was initialized happened _below_ the tick
            if (tick <= tickCurrent) {
                tickInfo.growthOutside = getG();
                tickInfo.secondsOutside = _blockTimestamp();
            } else {
                tickInfo.growthOutside = FixedPoint.encode(1);
            }
        }
    }

    function getLiquidityFee(
        int16 tickLower,
        int16 tickUpper,
        uint8 feeVote
    ) public view returns (int112 amount0, int112 amount1) {
        TickInfo storage tickInfoLower = tickInfos[tickLower];
        TickInfo storage tickInfoUpper = tickInfos[tickUpper];
        FixedPoint.uq112x112 memory growthInside = _getGrowthInside(tickLower, tickUpper, tickInfoLower, tickInfoUpper);

        Position storage position = _getPosition(msg.sender, tickLower, tickUpper, feeVote);
        uint256 liquidityFee = FixedPoint.decode144(growthInside.mul(position.liquidityAdjusted)) > position.liquidity
            ? FixedPoint.decode144(growthInside.mul(position.liquidityAdjusted)) - position.liquidity
            : 0;

        FixedPoint.uq112x112 memory price = FixedPoint.fraction(reserve1Virtual, reserve0Virtual);
        (amount0, amount1) = getValueAtPrice(price, liquidityFee.toInt112());
    }

    // note: this function can cause the price to change
    function updateReservesAndVirtualSupply(int112 liquidityDelta, uint16 feeVote)
        internal
        returns (int112 amount0, int112 amount1)
    {
        FixedPoint.uq112x112 memory price = FixedPoint.fraction(reserve1Virtual, reserve0Virtual);
        (amount0, amount1) = getValueAtPrice(price, liquidityDelta);

        // checkpoint rootK
        uint112 rootKLast = uint112(Babylonian.sqrt(uint256(reserve0Virtual) * reserve1Virtual));

        // update reserves (the price doesn't change, so no need to update the oracle/current tick)
        // TODO: the price _can_ change because of rounding error
        reserve0Virtual = reserve0Virtual.addi(amount0).toUint112();
        reserve1Virtual = reserve1Virtual.addi(amount1).toUint112();

        require(reserve0Virtual >= TOKEN_MIN, 'UniswapV3: RESERVE_0_TOO_SMALL');
        require(reserve1Virtual >= TOKEN_MIN, 'UniswapV3: RESERVE_1_TOO_SMALL');

        // update virtual supply
        // TODO i believe this consistently results in a smaller g
        uint112 virtualSupply = getVirtualSupply();
        uint112 rootK = uint112(Babylonian.sqrt(uint256(reserve0Virtual) * reserve1Virtual));
        virtualSupplies[feeVote] = virtualSupplies[feeVote]
            .addi(((int256(rootK) - rootKLast) * virtualSupply) / rootKLast)
            .toUint112();

        FixedPoint.uq112x112 memory priceNext = FixedPoint.fraction(reserve1Virtual, reserve0Virtual);
        if (amount0 > 0) {
            assert(priceNext._x <= price._x);
        } else if (amount0 < 0) {
            assert(priceNext._x >= price._x);
        }
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
        require(getVirtualSupply() > 0, 'UniswapV3: NOT_INITIALIZED'); // sufficient check
        require(tickLower >= TickMath.MIN_TICK, 'UniswapV3: LOWER_TICK');
        require(tickUpper <= TickMath.MAX_TICK, 'UniswapV3: UPPER_TICK');
        require(tickLower < tickUpper, 'UniswapV3: TICKS');
        _update();

        TickInfo storage tickInfoLower = _initializeTick(tickLower); // initialize tick idempotently
        TickInfo storage tickInfoUpper = _initializeTick(tickUpper); // initialize tick idempotently

        {
            Position storage position = _getPosition(msg.sender, tickLower, tickUpper, feeVote);
            FixedPoint.uq112x112 memory growthInside = _getGrowthInside(
                tickLower,
                tickUpper,
                tickInfoLower,
                tickInfoUpper
            );

            // check if this condition has accrued any untracked fees
            // to account for rounding errors, we have to short-circuit the calculation if the untracked fees are too low
            // TODO is this calculation correct/precise?
            // TODO technically this can overflow
            // TODO optimize this to save gas
            uint256 liquidityFee = FixedPoint.decode144(growthInside.mul(position.liquidityAdjusted)) >
                position.liquidity
                ? FixedPoint.decode144(growthInside.mul(position.liquidityAdjusted)) - position.liquidity
                : 0;
            if (liquidityFee > 0) {
                address feeTo = IUniswapV3Factory(factory).feeTo();
                // take the protocol fee if it's on (feeTo isn't address(0)) and the sender isn't feeTo
                if (feeTo != address(0) && msg.sender != feeTo) {
                    uint256 liquidityProtocol = liquidityFee / 6;
                    if (liquidityProtocol > 0) {
                        // 1/6 of the user's liquidityFee gets allocated as liquidity between
                        // MIN/MAX for `feeTo`.
                        liquidityFee -= liquidityProtocol;

                        // TODO ensure all of the below is correct
                        // note: this accumulates protocol fees under the user's current fee vote
                        Position storage positionProtocol = _getPosition(
                            feeTo,
                            TickMath.MIN_TICK,
                            TickMath.MAX_TICK,
                            feeVote
                        );
                        FixedPoint.uq112x112 memory g = getG(); // shortcut for _getGrowthInside

                        // accrue any newly earned fee liquidity from the existing protocol position
                        liquidityProtocol = liquidityProtocol.add(
                            FixedPoint.decode144(g.mul(positionProtocol.liquidityAdjusted)) > positionProtocol.liquidity
                                ? FixedPoint.decode144(g.mul(positionProtocol.liquidityAdjusted)) -
                                    positionProtocol.liquidity
                                : 0
                        );
                        // update the reserves to account for the this new liquidity
                        updateReservesAndVirtualSupply(liquidityProtocol.toInt112(), feeVote);

                        // update the position
                        // TODO all the same caveats as above apply
                        positionProtocol.liquidity = positionProtocol.liquidity.add(liquidityProtocol).toUint112();
                        positionProtocol.liquidityAdjusted = uint256(
                            FixedPoint.encode(positionProtocol.liquidity)._x / g._x
                        )
                            .toUint112();
                    }
                }

                // credit the caller for the value of the fee liquidity
                (amount0, amount1) = updateReservesAndVirtualSupply(-(liquidityFee.toInt112()), feeVote);
            }

            // update position
            position.liquidity = position.liquidity.addi(liquidityDelta).toUint112();
            position.liquidityAdjusted = uint256(FixedPoint.encode(position.liquidity)._x / growthInside._x)
                .toUint112();
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

        // regardless of current price, when lower tick is crossed from left to right, amount0Lower should be added
        if (tickLower > TickMath.MIN_TICK) {
            tickInfoLower.token0VirtualDeltas[feeVote] = tickInfoLower.token0VirtualDeltas[feeVote]
                .add(amount0Lower)
                .toInt112();
        }
        // regardless of current price, when upper tick is crossed from left to right amount0Upper should be removed
        if (tickUpper < TickMath.MAX_TICK) {
            tickInfoUpper.token0VirtualDeltas[feeVote] = tickInfoUpper.token0VirtualDeltas[feeVote]
                .sub(amount0Upper)
                .toInt112();
        }

        // the current price is below the passed range, so the liquidity can only become in range by crossing from left
        // to right, at which point we'll need _more_ token0 (it's becoming more valuable) so the user must provide it
        if (tickCurrent < tickLower) {
            amount0 = amount0.add(amount0Lower.sub(amount0Upper)).toInt112();
        } else if (tickCurrent < tickUpper) {
            // the current price is inside the passed range
            (int112 amount0Current, int112 amount1Current) = updateReservesAndVirtualSupply(liquidityDelta, feeVote);

            // charge the user whatever is required to cover their position
            amount0 = amount0.add(amount0Current.sub(amount0Upper)).toInt112();
            amount1 = amount1.add(amount1Current.sub(amount1Lower)).toInt112();
        } else {
            // the current price is above the passed range, so the liquidity can only become in range by crossing from right
            // to left, at which point we'll need _more_ token1 (it's becoming more valuable) so the user must provide it
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

    struct StepComputations {
        // price for the tick
        FixedPoint.uq112x112 nextPrice;
        // how much is being swapped in in this step
        uint112 amountIn;
        // how much is being swapped out in the current step
        uint112 amountOut;
    }

    function _swap(SwapParams memory params) internal lock returns (uint112 amountOut) {
        require(params.amountIn > 0, 'UniswapV3: INSUFFICIENT_INPUT_AMOUNT');
        _update(); // update the oracle and feeLast

        // use the fee from the previous block as the floor
        uint16 fee = feeLast;
        int16 tick = tickCurrent;

        uint112 amountInRemaining = params.amountIn;
        while (amountInRemaining > 0) {
            // TODO these conditions almost certainly need to be tweaked/put in a different place
            assert(tick >= TickMath.MIN_TICK);
            assert(tick <= TickMath.MAX_TICK);
            // ensure that there is enough liquidity to guarantee we can get a price within the next tick
            require(reserve0Virtual >= TOKEN_MIN && reserve1Virtual >= TOKEN_MIN, 'UniswapV3: INSUFFICIENT_LIQUIDITY');

            // get the inclusive lower bound price for the current tick
            StepComputations memory step;
            step.nextPrice = params.zeroForOne ? TickMath.getRatioAtTick(tick) : TickMath.getRatioAtTick(tick + 1);

            // adjust the fee we will use if the current fee is greater than the stored fee to protect liquidity providers
            uint16 currentFee = getFee();
            if (fee < currentFee) fee = currentFee;

            (uint112 reserveInVirtual, uint112 reserveOutVirtual) = params.zeroForOne
                ? (reserve0Virtual, reserve1Virtual)
                : (reserve1Virtual, reserve0Virtual);
            // compute the amount of token0 required s.t. the price is ~the lower bound for the current tick
            // TODO adjust this amount (or amountOutStep) so that we're guaranteed the ratio is as close (or equal)
            // to the lower bound _without_ exceeding it as possible
            uint112 amountInRequiredForShift = PriceMath.getInputToRatio(
                reserveInVirtual,
                reserveOutVirtual,
                fee,
                params.zeroForOne ? step.nextPrice.reciprocal() : step.nextPrice
            );

            // only trade as much as we need to
            if (amountInRequiredForShift > 0) {
                uint144 reserveInTarget = uint144(step.nextPrice._x > type(uint144).max ? (1 << 112) >> 80 : 1 << 112);
                uint144 reserveOutTarget = uint144(
                    step.nextPrice._x > type(uint144).max ? step.nextPrice._x >> 80 : step.nextPrice._x
                );
                uint112 reserveInVirtualNext = (uint256(reserveInVirtual) + amountInRequiredForShift).toUint112();
                uint112 amountOutMaximum = reserveOutVirtual
                    .sub((reserveOutTarget * reserveInVirtualNext) / reserveInTarget)
                    .toUint112();

                step.amountIn = amountInRemaining > amountInRequiredForShift
                    ? amountInRequiredForShift
                    : amountInRemaining;
                // adjust the step amount by the current fee
                uint112 amountInAdjusted = uint112(
                    (uint256(step.amountIn) * (PriceMath.LP_FEE_BASE - fee)) / PriceMath.LP_FEE_BASE
                );
                // calculate the output amount
                step.amountOut = ((uint256(reserveOutVirtual) * amountInAdjusted) /
                    (uint256(reserveInVirtual) + amountInAdjusted))
                    .toUint112();
                step.amountOut = step.amountOut > amountOutMaximum ? amountOutMaximum : step.amountOut;
                if (params.zeroForOne) {
                    reserve0Virtual = (uint256(reserve0Virtual) + step.amountIn).toUint112();
                    reserve1Virtual = reserve1Virtual.sub(step.amountOut).toUint112();
                } else {
                    reserve1Virtual = (uint256(reserve1Virtual) + step.amountIn).toUint112();
                    reserve0Virtual = reserve0Virtual.sub(step.amountOut).toUint112();
                }
                amountInRemaining = amountInRemaining.sub(step.amountIn).toUint112();
                amountOut = (uint256(amountOut) + step.amountOut).toUint112();
            }

            // if a positive input amount still remains, we have to shift down to the next tick
            if (amountInRemaining > 0) {
                TickInfo storage tickInfo = tickInfos[tick];

                // if the tick is initialized, we must update it
                if (tickInfo.growthOutside._x != 0) {
                    // calculate the amount of reserves + liquidity to kick in/out
                    int112 token0VirtualDelta;
                    for (uint8 i = 0; i < NUM_FEE_OPTIONS; i++) {
                        token0VirtualDelta += tickInfo.token0VirtualDeltas[i];
                    }
                    // TODO we have to do this in an overflow-safe way
                    // TODO this should always move the price _down_ (if it has to move at all), because that's the
                    // direction we're moving...floor division should ensure that this is the case with positive deltas,
                    // but not with negative
                    int112 token1VirtualDelta = step.nextPrice.muli(token0VirtualDelta).toInt112();
                    // TODO i think we could squeeze out a tiny bit more precision under certain circumstances by doing:
                    // a) summing total negative and positive token0VirtualDeltas
                    // b) calculating the total negative and positive virtualSupply delta
                    // c) allocating these deltas proportionally across virtualSupplies
                    // (where the sign of the delta determines which total to use and the value determines proportion)
                    // note: this may be overkill/unnecessary
                    uint112 virtualSupply = getVirtualSupply();
                    for (uint8 i = 0; i < NUM_FEE_OPTIONS; i++) {
                        int112 virtualSupplyDelta = (tickInfo.token0VirtualDeltas[i].mul(virtualSupply) /
                            reserveInVirtual)
                            .toInt112();
                        // TODO are these SSTOREs optimized/packed?
                        virtualSupplies[i] = virtualSupplies[i].subi(virtualSupplyDelta).toUint112();
                    }

                    // subi because we're moving from right to left
                    if (params.zeroForOne) {
                        reserve0Virtual = reserve0Virtual.subi(token0VirtualDelta).toUint112();
                        reserve1Virtual = reserve1Virtual.subi(token1VirtualDelta).toUint112();
                    } else {
                        // TODO: addi?
                        reserve0Virtual = reserve0Virtual.addi(token0VirtualDelta).toUint112();
                        reserve1Virtual = reserve1Virtual.addi(token1VirtualDelta).toUint112();
                    }

                    // update tick info
                    // overflow is desired
                    tickInfo.growthOutside = getG().divuq(tickInfo.growthOutside);
                    tickInfo.secondsOutside = _blockTimestamp() - tickInfo.secondsOutside;
                }

                tick += params.zeroForOne ? int16(-1) : int16(1);
            }
        }

        tickCurrent = tick;
        TransferHelper.safeTransfer(params.zeroForOne ? token1 : token0, params.to, amountOut); // optimistically transfer tokens
        if (params.data.length > 0) IUniswapV3Callee(params.to).uniswapV3Call(msg.sender, 0, amountOut, params.data);
        TransferHelper.safeTransferFrom(
            params.zeroForOne ? token0 : token1,
            msg.sender,
            address(this),
            params.amountIn
        ); // this is different than v2
    }

    // move from right to left (token 1 is becoming more valuable)
    function swap0For1(
        uint112 amount0In,
        address to,
        bytes calldata data
    ) external returns (uint112 amount1Out) {
        SwapParams memory params = SwapParams({zeroForOne: true, amountIn: amount0In, to: to, data: data});
        return _swap(params);
    }

    // move from left to right (token 0 is becoming more valuable)
    function swap1For0(
        uint112 amount1In,
        address to,
        bytes calldata data
    ) external returns (uint112 amount0Out) {
        SwapParams memory params = SwapParams({zeroForOne: false, amountIn: amount1In, to: to, data: data});
        return _swap(params);
    }

    // Helper for reading the cumulative price as of the current block
    function getCumulativePrices() public view override returns (uint256 price0Cumulative, uint256 price1Cumulative) {
        uint32 blockTimestamp = _blockTimestamp();

        if (blockTimestampLast != blockTimestamp) {
            uint32 timeElapsed = blockTimestamp - blockTimestampLast;
            price0Cumulative =
                price0CumulativeLast +
                FixedPoint.fraction(reserve1Virtual, reserve0Virtual).mul(timeElapsed)._x;
            price1Cumulative =
                price1CumulativeLast +
                FixedPoint.fraction(reserve0Virtual, reserve1Virtual).mul(timeElapsed)._x;
        } else {
            price0Cumulative = price0CumulativeLast;
            price1Cumulative = price1CumulativeLast;
        }
    }
}
