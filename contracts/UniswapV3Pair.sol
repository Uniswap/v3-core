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
import './libraries/TickMath.sol';
import './libraries/ReverseTickMath.sol';
import './libraries/PriceMath.sol';

import './interfaces/IUniswapV3Pair.sol';
import './interfaces/IUniswapV3Factory.sol';
import './interfaces/IUniswapV3Callee.sol';
import './libraries/TickBitMap.sol';
import './libraries/FixedPoint128.sol';

/// @title The Uniswap V3 Pair Contract.
/// @notice The V3 pair allows liquidity provisioning within user specified positions.
/// @dev Liquidity positions are partitioned into "ticks", each tick is equally spaced and may have an arbitrary depth of liquidity.
contract UniswapV3Pair is IUniswapV3Pair {
    using SafeMath for uint128;
    using SafeMath for uint256;
    using SignedSafeMath for int128;
    using SignedSafeMath for int256;
    using SafeCast for int256;
    using SafeCast for uint256;
    using MixedSafeMath for uint128;
    using FixedPoint128 for FixedPoint128.uq128x128;
    using TickBitMap for mapping(uint256 => uint256);

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

    // TODO figure out the best way to pack state variables
    address public override feeTo;

    /// @notice Mapping of tickBitMap to uint - see TickBitMap.sol
    mapping(uint256 => uint256) public override tickBitMap;

    /// @notice The timestamp of the current block, used for safety when initializing positions.
    uint32 public override blockTimestampLast;

    /// @notice All in-range liquidity.
    uint128 public override liquidityCurrent;

    /// @notice (token1 / token0) price.
    FixedPoint128.uq128x128 public override priceCurrent;

    /// @notice First tick at or below priceCurrent.
    int24 public override tickCurrent;

    /// @notice Global fee growth per unit of liquidity.
    /// @dev feeGrowthGlobal on its own is not enough to figure out fees due to a given position, but it is used in the calculation of it.
    /// @dev This number is used to calculate how many fees are due per liquidity provision in a given tick.
    FixedPoint128.uq128x128 public override feeGrowthGlobal0;
    FixedPoint128.uq128x128 public override feeGrowthGlobal1;

    /// @notice Accumulated protocol fees.
    /// @dev There is no value in packing these values, since we only ever set one at a time.
    uint256 public override feeToFees0;
    uint256 public override feeToFees1;

    /// @notice The TickInfo struct.
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

    /// @notice A position is a given allocation of liquidity by a user.
    /// @dev Uniquely identified by user address/lower tick/upper tick/fee vote.
    struct Position {
        uint128 liquidity;
        // fee growth per unit of liquidity as of the last modification
        FixedPoint128.uq128x128 feeGrowthInside0Last;
        FixedPoint128.uq128x128 feeGrowthInside1Last;
    }
    mapping(bytes32 => Position) public positions;

    /// @notice The reentrancy guard.
    uint256 private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, 'UniswapV3Pair::lock: reentrancy prohibited');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    /// @notice Gets a given users position: a given allocation of liquidity as determined by owner / tickLower / tickUpper.
    /// @param owner A given liquidity providers address.
    /// @param tickLower The lower boundary tick.
    /// @param tickUppder The upper boundary tick.
    /// @return The position struct.
    function _getPosition(
        address owner,
        int24 tickLower,
        int24 tickUpper
    ) private view returns (Position storage position) {
        position = positions[keccak256(abi.encodePacked(owner, tickLower, tickUpper))];
    }

    /// @notice Part of the _getFeeGrowthInside function.
    /// @notice Calculates the fee growth below a given tick range, in order to calculate the fee growth within a given range.
    function _getFeeGrowthBelow(int24 tick, TickInfo storage tickInfo)
        private
        view
        returns (FixedPoint128.uq128x128 memory feeGrowthBelow0, FixedPoint128.uq128x128 memory feeGrowthBelow1)
    {
        // tick is above the current tick, meaning growth outside represents growth above, not below
        if (tick > tickCurrent) {
            feeGrowthBelow0 = FixedPoint128.uq128x128(feeGrowthGlobal0._x - tickInfo.feeGrowthOutside0._x);
            feeGrowthBelow1 = FixedPoint128.uq128x128(feeGrowthGlobal1._x - tickInfo.feeGrowthOutside1._x);
        } else {
            feeGrowthBelow0 = tickInfo.feeGrowthOutside0;
            feeGrowthBelow1 = tickInfo.feeGrowthOutside1;
        }
    }

    /// @notice Part of the _getFeeGrowthInside function.
    /// @notice Calculates the fee growth above a given tick range, in order to calculate the fee growth within a given range.
    function _getFeeGrowthAbove(int24 tick, TickInfo storage tickInfo)
        private
        view
        returns (FixedPoint128.uq128x128 memory feeGrowthAbove0, FixedPoint128.uq128x128 memory feeGrowthAbove1)
    {
        // tick is above current tick, meaning growth outside represents growth above
        if (tick > tickCurrent) {
            feeGrowthAbove0 = tickInfo.feeGrowthOutside0;
            feeGrowthAbove1 = tickInfo.feeGrowthOutside1;
        } else {
            feeGrowthAbove0 = FixedPoint128.uq128x128(feeGrowthGlobal0._x - tickInfo.feeGrowthOutside0._x);
            feeGrowthAbove1 = FixedPoint128.uq128x128(feeGrowthGlobal1._x - tickInfo.feeGrowthOutside1._x);
        }
    }

    /// @notice The main fee growth calculation.
    /// @dev Called when a user sets a new position.
    /// @dev Part of determining the quantity of fees, per liquidity, are due in a given tick range.
    /// @dev Calculates the fee growth of a given tick range by calling both _getFeeGrowthAbove and _getFeeGrowthBelow.
    /// @param tickLower The lowest tick of a given range.
    /// @param tickUpper The highest tick of a given range.
    /// @param tickInfoLower The info struct of the lowest tick of a given range.
    /// @param tickInfoUpper The info struct of the highest tick of a given range.
    /// @return feeGrowthInside0 The fee growth in the given range of the token0 pool.
    /// @return feeGrowthInside1 The fee growth in the given range of the token1 pool.
    function _getFeeGrowthInside(
        int24 tickLower,
        int24 tickUpper,
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
        ) = _getFeeGrowthBelow(tickLower, tickInfoLower);
        (
            FixedPoint128.uq128x128 memory feeGrowthAbove0,
            FixedPoint128.uq128x128 memory feeGrowthAbove1
        ) = _getFeeGrowthAbove(tickUpper, tickInfoUpper);
        feeGrowthInside0 = FixedPoint128.uq128x128(feeGrowthGlobal0._x - feeGrowthBelow0._x - feeGrowthAbove0._x);
        feeGrowthInside1 = FixedPoint128.uq128x128(feeGrowthGlobal1._x - feeGrowthBelow1._x - feeGrowthAbove1._x);
    }

    /// @notice Check for one-time initialization.
    /// @return bool determining if there is already a price, thus already an initialized pair.
    function isInitialized() public view override returns (bool) {
        return priceCurrent._x != 0; // sufficient check
    }

    /// @notice The Pair constructor.
    /// @dev Executed only once when a pair is initialized.
    /// @param _factory The Uniswap V3 factory address.
    /// @param _token0 The first token of the desired pair.
    /// @param _token1 The second token of the desired pair.
    /// @param _fee The fee of the desired pair.
    constructor(
        address _factory,
        address _token0,
        address _token1,
        uint24 _fee
    ) public {
        factory = _factory;
        token0 = _token0;
        token1 = _token1;
        fee = _fee;
    }

    /// @notice Overridden for tests.
    /// @return The block timestamp % 2**64.
    function _blockTimestamp() internal view virtual returns (uint32) {
        return uint32(block.timestamp); // truncation is desired
    }

    /// @notice Updates the oracle price accumulator and fee on the first interaction per block.
    function _update() private {
        uint32 blockTimestamp = _blockTimestamp();

        if (blockTimestampLast != blockTimestamp) {
            blockTimestampLast = blockTimestamp;
        }
    }

    /// @notice Sets the destination where the swap fees are routed to.
    /// @param feeto_ address of the desired destination.
    /// @dev only able to be called by "feeToSetter".
    function setFeeTo(address feeTo_) external override {
        require(msg.sender == IUniswapV3Factory(factory).owner(), 'UniswapV3Pair::setFeeTo: caller not owner');
        feeTo = feeTo_;
    }

    /// @notice Updates the tick information upon liquidity provision or removal.
    /// @param tick The given tick.
    /// @param liquidityDelta The delta of the liquidity, which is sqrt(reserve0Virtual * reserve1Virtual), so it does not incorporate fees.
    /// @return The TickInfo struct.
    function _updateTick(int24 tick, int128 liquidityDelta) private returns (TickInfo storage tickInfo) {
        tickInfo = tickInfos[tick];

        if (tickInfo.liquidityGross == 0) {
            assert(liquidityDelta > 0);
            // by convention, we assume that all growth before a tick was initialized happened _below_ the tick
            if (tick <= tickCurrent) {
                tickInfo.feeGrowthOutside0 = feeGrowthGlobal0;
                tickInfo.feeGrowthOutside1 = feeGrowthGlobal1;
                tickInfo.secondsOutside = _blockTimestamp();
            }
            // save because of the prior assert
            tickInfo.liquidityGross = uint128(liquidityDelta);
            tickBitMap.flipTick(tick);
        } else {
            tickInfo.liquidityGross = uint128(tickInfo.liquidityGross.addi(liquidityDelta));
        }
    }

    /// @notice Deletes tick info struct.
    /// @param tick The given tick to delete.
    function _clearTick(int24 tick) private {
        delete tickInfos[tick];
        tickBitMap.flipTick(tick);
    }

    /// @notice Initializes a new tick.
    /// @param tick The given tick to initialize.
    function initialize(int24 tick) external override lock {
        require(!isInitialized(), 'UniswapV3Pair::initialize: pair already initialized');
        require(tick >= TickMath.MIN_TICK, 'UniswapV3Pair::initialize: tick must be greater than or equal to min tick');
        require(tick < TickMath.MAX_TICK, 'UniswapV3Pair::initialize: tick must be less than max tick');

        // initialize oracle timestamp and fee
        blockTimestampLast = _blockTimestamp();

        // initialize current price and tick
        priceCurrent = TickMath.getRatioAtTick(tick);
        tickCurrent = tick;

        // set permanent 1 wei position
        _setPosition(
            SetPositionParams({
                owner: address(0),
                tickLower: TickMath.MIN_TICK,
                tickUpper: TickMath.MAX_TICK,
                liquidityDelta: 1
            })
        );

        emit Initialized(tick);
    }

    /// @notice The parameters of a given liquidity position.
    struct SetPositionParams {
        address owner;
        int24 tickLower;
        int24 tickUpper;
        int128 liquidityDelta;
    }

    /// @notice Sets the position of a given liquidity provision.
    /// @param  tickLower The lower boundary of the position.
    /// @param tickUpper The upper boundary of the position.
    /// @param liquidityDelta The liquidity delta. (TODO what is it).
    /// @return amount0, the amount of the first token.
    /// @return amount1, the amount of the second token.
    function setPosition(
        int24 tickLower,
        int24 tickUpper,
        int128 liquidityDelta
    ) external override lock returns (int256 amount0, int256 amount1) {
        require(isInitialized(), 'UniswapV3Pair::setPosition: pair not initialized');
        require(tickLower < tickUpper, 'UniswapV3Pair::setPosition: tickLower must be less than tickUpper');
        require(tickLower >= TickMath.MIN_TICK, 'UniswapV3Pair::setPosition: tickLower cannot be less than min tick');
        require(
            tickUpper <= TickMath.MAX_TICK,
            'UniswapV3Pair::setPosition: tickUpper cannot be greater than max tick'
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

    /// @notice Add or remove a specified amount of liquidity from a specified range, and/or change feeVote for that range.
    /// @notice Also sync a position and return accumulated fees from it to user as tokens.
    /// @dev LiquidityDelta is sqrt(reserve0Virtual * reserve1Virtual), so it does not incorporate fees.
    /// @param setPositionParams parameters passed from the calling function setPosition.
    /// @return amount0 The amount of token zero.
    /// @return amount1 The amount of token one.
    function _setPosition(SetPositionParams memory params) private returns (int256 amount0, int256 amount1) {
        _update();

        {
            Position storage position = _getPosition(params.owner, params.tickLower, params.tickUpper);

            if (params.liquidityDelta == 0) {
                require(
                    position.liquidity != 0,
                    'UniswapV3Pair::_setPosition: cannot collect fees on 0 liquidity position'
                );
            } else if (params.liquidityDelta < 0) {
                require(
                    position.liquidity >= uint128(-params.liquidityDelta),
                    'UniswapV3Pair::_setPosition: cannot remove more than current position liquidity'
                );
            }

            TickInfo storage tickInfoLower = _updateTick(params.tickLower, params.liquidityDelta);
            TickInfo storage tickInfoUpper = _updateTick(params.tickUpper, params.liquidityDelta);

            require(
                tickInfoLower.liquidityGross <= MAX_LIQUIDITY_GROSS_PER_TICK,
                'UniswapV3Pair::_setPosition: liquidity overflow in lower tick'
            );
            require(
                tickInfoUpper.liquidityGross <= MAX_LIQUIDITY_GROSS_PER_TICK,
                'UniswapV3Pair::_setPosition: liquidity overflow in upper tick'
            );

            {
                (
                    FixedPoint128.uq128x128 memory feeGrowthInside0,
                    FixedPoint128.uq128x128 memory feeGrowthInside1
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
                            uint256(1) << 128
                        )
                            .toInt256();
                    }
                    if (feeGrowthInside1._x > position.feeGrowthInside1Last._x) {
                        amount1 = -FullMath
                            .mulDiv(
                            feeGrowthInside1._x - position.feeGrowthInside1Last._x,
                            position
                                .liquidity,
                            uint256(1) << 128
                        )
                            .toInt256();
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

        // the current price is below the passed range, so the liquidity can only become in range by crossing from left
        // to right, at which point we'll need _more_ token0 (it's becoming more valuable) so the user must provide it
        if (tickCurrent < params.tickLower) {
            amount0 = amount0.add(
                PriceMath.getAmount0Delta(
                    TickMath.getRatioAtTick(params.tickLower),
                    TickMath.getRatioAtTick(params.tickUpper),
                    params.liquidityDelta
                )
            );
        } else if (tickCurrent < params.tickUpper) {
            // the current price is inside the passed range
            amount0 = amount0.add(
                PriceMath.getAmount0Delta(
                    priceCurrent,
                    TickMath.getRatioAtTick(params.tickUpper),
                    params.liquidityDelta
                )
            );
            amount1 = amount1.add(
                PriceMath.getAmount1Delta(
                    TickMath.getRatioAtTick(params.tickLower),
                    priceCurrent,
                    params.liquidityDelta
                )
            );

            liquidityCurrent = liquidityCurrent.addi(params.liquidityDelta).toUint128();
        } else {
            // the current price is above the passed range, so liquidity can only become in range by crossing from right
            // to left, at which point we need _more_ token1 (it's becoming more valuable) so the user must provide it
            amount1 = amount1.add(
                PriceMath.getAmount1Delta(
                    TickMath.getRatioAtTick(params.tickLower),
                    TickMath.getRatioAtTick(params.tickUpper),
                    params.liquidityDelta
                )
            );
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

    /// @notice The swap parameters struct
    /// @dev Used on every swap.
    struct SwapParams {
        // whether the swap is from token 0 to 1, or 1 for 0
        bool zeroForOne;
        // how much is being swapped in
        uint256 amountIn;
        // the recipient address
        address to;
        // any data that should be sent to the address with the call
        bytes data;
    }

    /// @notice The top level state of the swap, the results of which are recorded in storage at the end.
    struct SwapState {
        // the amount in remaining to be swapped of the input asset
        uint256 amountInRemaining;
        // the tick associated with the current price
        int24 tick;
        // the price
        FixedPoint128.uq128x128 price;
        // protocol fees of the input token
        uint256 feeToFees;
        // the global fee growth of the input token
        FixedPoint128.uq128x128 feeGrowthGlobal;
        // whether the swap has crossed an initialized tick
        bool crossedInitializedTick;
        // the liquidity in range
        uint128 liquidityCurrent;
    }

    /// @notice The StepComputations struct.
    struct StepComputations {
        // the next initialized tick from the tickCurrent in the swap direction
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

    /// @notice The internal swap function.
    /// @param params The SwapParams struct.
    /// @return Returns the outbound amount of tokens.
    function _swap(SwapParams memory params) private returns (uint256 amountOut) {
        _update(); // update the oracle and feeFloor

        SwapState memory state = SwapState({
            amountInRemaining: params.amountIn,
            tick: tickCurrent,
            price: priceCurrent,
            feeToFees: params.zeroForOne ? feeToFees0 : feeToFees1,
            feeGrowthGlobal: params.zeroForOne ? feeGrowthGlobal0 : feeGrowthGlobal1,
            crossedInitializedTick: false,
            liquidityCurrent: liquidityCurrent
        });

        while (state.amountInRemaining > 0) {
            StepComputations memory step;

            (step.tickNext, ) = tickBitMap.nextInitializedTickWithinOneWord(state.tick, params.zeroForOne);

            // get the price for the next tick we're moving toward
            step.priceNext = TickMath.getRatioAtTick(step.tickNext);

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
                    // take the protocol fee if it's on
                    if (feeTo != address(0)) {
                        uint256 feeToFee = feePaid / 6;
                        // decrement feePaid
                        feePaid -= feeToFee;
                        // increment feeToFees--overflow is not possible
                        state.feeToFees += feeToFee;
                    }

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
                    state.crossedInitializedTick = true;
                }

                // this is ok because we still have amountInRemaining so price is guaranteed to be less than the tick
                // after swapping the remaining amount in
                state.tick = params.zeroForOne ? step.tickNext - 1 : step.tickNext;
            } else {
                state.tick = params.zeroForOne
                    ? ReverseTickMath.getTickFromPrice(state.price, step.tickNext, state.tick + 1)
                    : ReverseTickMath.getTickFromPrice(state.price, state.tick, step.tickNext);
            }
        }

        priceCurrent = state.price;
        if (params.zeroForOne) require(state.tick >= TickMath.MIN_TICK, 'UniswapV3Pair::_swap: crossed min tick');
        else require(state.tick < TickMath.MAX_TICK, 'UniswapV3Pair::_swap: crossed max tick');
        tickCurrent = state.tick;

        if (state.crossedInitializedTick) {
            liquidityCurrent = state.liquidityCurrent;
        }

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

    /// @notice The first main swap function.
    /// @notice Used when moving from right to left (token 1 is becoming more valuable).
    /// @param amount0In Amount of token you are sending.
    /// @param to The destination address of the tokens.
    /// @param calldata The call data of the swap.
    function swap0For1(
        uint256 amount0In,
        address to,
        bytes calldata data
    ) external override lock returns (uint256 amount1Out) {
        require(amount0In > 0, 'UniswapV3Pair::swap0For1: amountIn must be greater than 0');

        SwapParams memory params = SwapParams({zeroForOne: true, amountIn: amount0In, to: to, data: data});
        return _swap(params);
    }

    /// @notice The second main swap function.
    /// @notice Used when moving from left to right (token 0 is becoming more valuable).
    /// @param amount1In amount of token you are sending.
    /// @param to The destination address of the tokens.
    /// @param data The call data of the swap.
    function swap1For0(
        uint256 amount1In,
        address to,
        bytes calldata data
    ) external override lock returns (uint256 amount0Out) {
        require(amount1In > 0, 'UniswapV3Pair::swap1For0: amountIn must be greater than 0');

        SwapParams memory params = SwapParams({zeroForOne: false, amountIn: amount1In, to: to, data: data});
        return _swap(params);
    }

    /// @notice Recovers tokens accidentally sent to the pair contract.
    /// @param token The token address.
    /// @param to The destination address of the transfer.
    /// @param amount The amount of the token to be recovered.
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
