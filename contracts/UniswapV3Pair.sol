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

contract UniswapV3Pair is IUniswapV3Pair {
    using SafeMath for uint128;
    using SafeMath for uint256;
    using SignedSafeMath for int128;
    using SignedSafeMath for int256;
    using SafeCast for int256;
    using SafeCast for uint256;
    using MixedSafeMath for uint128;
    using FixedPoint128 for FixedPoint128.uq128x128;
    using TickBitMap for uint256[58];

    // Number of fee options
    uint8 public constant override NUM_FEE_OPTIONS = 6;

    // if we constrain the liquidity associated to a single tick, then we can guarantee that the total
    // liquidityCurrent never exceeds uint128
    // the max liquidity for a single tick fee vote is then:
    //   floor(type(uint128).max / (number of ticks))
    //     = (2n ** 128n - 1n) / (2n ** 16n)
    // this is about 112 bits
    uint128 private constant MAX_LIQUIDITY_GROSS_PER_TICK = 5192296858534827628530496329220095;

    // list of fee options expressed as bips
    // uint16 because the maximum value is 10_000
    // options are 0.05%, 0.10%, 0.30%, 0.60%, 1.00%, 2.00%
    // ideally this would be a constant array, but constant arrays are not supported in solidity
    function FEE_OPTIONS(uint8 i) public pure override returns (uint16) {
        if (i < 3) {
            if (i == 0) return 6;
            if (i == 1) return 12;
            return 30;
        }
        if (i == 3) return 60;
        if (i == 4) return 120;
        assert(i == 5);
        return 240;
    }

    address public immutable override factory;
    address public immutable override token0;
    address public immutable override token1;

    // TODO figure out the best way to pack state variables
    address public override feeTo;

    // see TickBitMap.sol
    uint256[58] public override tickBitMap;

    uint64 public override blockTimestampLast;

    // the fee as of the end of the last block with a swap or setPosition/initialize
    // this is stored to protect liquidity providers from add/swap/remove sandwiching attacks
    uint16 public override feeFloor;

    uint128[NUM_FEE_OPTIONS] public override liquidityCurrent; // all in-range liquidity, segmented across fee options
    FixedPoint128.uq128x128 public override priceCurrent; // (token1 / token0) price
    int16 public override tickCurrent; // first tick at or below priceCurrent

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
        uint64 secondsOutside;
        // fee growth per unit of liquidity on the _other_ side of this tick (relative to the current tick)
        // only has relative meaning, not absolute — the value depends on when the tick is initialized
        FixedPoint128.uq128x128 feeGrowthOutside0;
        FixedPoint128.uq128x128 feeGrowthOutside1;
        // amount of liquidity added (subtracted) when tick is crossed from left to right (right to left),
        // i.e. as the price goes up (down), for each fee vote
        int128[NUM_FEE_OPTIONS] liquidityDelta;
    }
    mapping(int16 => TickInfo) public tickInfos;

    struct Position {
        uint128 liquidity;
        // fee growth per unit of liquidity as of the last modification
        FixedPoint128.uq128x128 feeGrowthInside0Last;
        FixedPoint128.uq128x128 feeGrowthInside1Last;
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

    function _getFeeGrowthAbove(int16 tick, TickInfo storage tickInfo)
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

    function _getFeeGrowthInside(
        int16 tickLower,
        int16 tickUpper,
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

    function getLiquidity() external view override returns (uint128 liquidity) {
        // load all liquidity into memory
        uint128[NUM_FEE_OPTIONS] memory _liquidityCurrent = [
            liquidityCurrent[0],
            liquidityCurrent[1],
            liquidityCurrent[2],
            liquidityCurrent[3],
            liquidityCurrent[4],
            liquidityCurrent[5]
        ];

        // guaranteed not to overflow because of conditions enforced outside this function
        for (uint8 feeVoteIndex = 0; feeVoteIndex < NUM_FEE_OPTIONS; feeVoteIndex++)
            liquidity += _liquidityCurrent[feeVoteIndex];
    }

    // check for one-time initialization
    function isInitialized() public view override returns (bool) {
        return priceCurrent._x != 0; // sufficient check
    }

    // find the median fee vote, and return the fee in bips
    function getFee() public view override returns (uint16 fee) {
        // load all virtual supplies into memory
        uint128[NUM_FEE_OPTIONS] memory _liquidityCurrent = [
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

    function computeLiquidityAndFee(uint128[NUM_FEE_OPTIONS] memory _liquidityCurrent)
        private
        pure
        returns (uint128 liquidity, uint16 fee)
    {
        liquidity =
            _liquidityCurrent[0] +
            _liquidityCurrent[1] +
            _liquidityCurrent[2] +
            _liquidityCurrent[3] +
            _liquidityCurrent[4] +
            _liquidityCurrent[5];

        uint128 threshold = liquidity / 2;

        uint128 liquidityCumulative;
        for (uint8 feeVoteIndex = 0; feeVoteIndex < NUM_FEE_OPTIONS; feeVoteIndex++) {
            liquidityCumulative += _liquidityCurrent[feeVoteIndex];
            if (liquidityCumulative >= threshold) {
                fee = FEE_OPTIONS(feeVoteIndex);
                break;
            }
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

    // returns the block timestamp % 2**64
    // overridden for tests
    function _blockTimestamp() internal view virtual returns (uint64) {
        return uint64(block.timestamp); // truncation is desired
    }

    // on the first interaction per block, update the oracle price accumulator and fee
    function _update() private {
        uint64 blockTimestamp = _blockTimestamp();

        if (blockTimestampLast != blockTimestamp) {
            blockTimestampLast = blockTimestamp;
            feeFloor = getFee();
        }
    }

    function setFeeTo(address feeTo_) external override {
        require(
            msg.sender == IUniswapV3Factory(factory).feeToSetter(),
            'UniswapV3Pair::setFeeTo: caller not feeToSetter'
        );
        feeTo = feeTo_;
    }

    function _updateTick(int16 tick, int128 liquidityDelta) private returns (TickInfo storage tickInfo) {
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

    function _clearTick(int16 tick) private {
        delete tickInfos[tick];
        tickBitMap.flipTick(tick);
    }

    function initialize(int16 tick) external override lock {
        require(!isInitialized(), 'UniswapV3Pair::initialize: pair already initialized');
        require(tick >= TickMath.MIN_TICK, 'UniswapV3Pair::initialize: tick must be greater than or equal to min tick');
        require(tick < TickMath.MAX_TICK, 'UniswapV3Pair::initialize: tick must be less than max tick');

        uint8 feeVote = 0;

        // initialize oracle timestamp and fee
        blockTimestampLast = _blockTimestamp();
        feeFloor = FEE_OPTIONS(feeVote);

        // initialize current price and tick
        priceCurrent = TickMath.getRatioAtTick(tick);
        tickCurrent = tick;

        // set permanent 1 wei position
        _setPosition(
            SetPositionParams({
                owner: address(0),
                tickLower: TickMath.MIN_TICK,
                tickUpper: TickMath.MAX_TICK,
                feeVote: feeVote,
                liquidityDelta: 1
            })
        );

        emit Initialized(tick);
    }

    struct SetPositionParams {
        address owner;
        int16 tickLower;
        int16 tickUpper;
        uint8 feeVote;
        int128 liquidityDelta;
    }

    function setPosition(
        int16 tickLower,
        int16 tickUpper,
        uint8 feeVote,
        int128 liquidityDelta
    ) external override lock returns (int256 amount0, int256 amount1) {
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
                    owner: msg.sender,
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
            Position storage position = _getPosition(params.owner, params.tickLower, params.tickUpper, params.feeVote);

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
            tickInfoLower.liquidityDelta[params.feeVote] = tickInfoLower.liquidityDelta[params.feeVote]
                .add(params.liquidityDelta)
                .toInt128();
            tickInfoUpper.liquidityDelta[params.feeVote] = tickInfoUpper.liquidityDelta[params.feeVote]
                .sub(params.liquidityDelta)
                .toInt128();

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

            liquidityCurrent[params.feeVote] = liquidityCurrent[params.feeVote].addi(params.liquidityDelta).toUint128();
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

    // the top level state of the swap, the results of which are recorded in storage at the end
    struct SwapState {
        // the floor for the fee, used to prevent sandwiching attacks
        uint16 feeFloor;
        // the amount in remaining to be swapped of the input asset
        uint256 amountInRemaining;
        // the tick associated with the current price
        int16 tick;
        // the liquidity in range segmented by fee vote
        uint128[NUM_FEE_OPTIONS] liquidityCurrent;
        // whether the swap has crossed an initialized tick
        bool crossedInitializedTick;
        // the price
        FixedPoint128.uq128x128 price;
        // protocol fees of the input token
        uint256 feeToFees;
        // the global fee growth of the input token
        FixedPoint128.uq128x128 feeGrowthGlobal;
    }

    struct StepComputations {
        // the next initialized tick from the tickCurrent in the swap direction
        int16 tickNext;
        // price for the target tick (1/0)
        FixedPoint128.uq128x128 priceNext;
        // the virtual liquidity
        uint128 liquidity;
        // the fee that will be paid in this step, in bips
        uint16 fee;
        // (computed) virtual reserves of token0
        uint256 reserve0Virtual;
        // (computed) virtual reserves of token1
        uint256 reserve1Virtual;
        // how much is being swapped in in this step
        uint256 amountIn;
        // how much is being swapped out in the current step
        uint256 amountOut;
    }

    function _swap(SwapParams memory params) private returns (uint256 amountOut) {
        _update(); // update the oracle and feeFloor

        SwapState memory state = SwapState({
            feeFloor: feeFloor,
            amountInRemaining: params.amountIn,
            tick: tickCurrent,
            price: priceCurrent,
            feeToFees: params.zeroForOne ? feeToFees0 : feeToFees1,
            feeGrowthGlobal: params.zeroForOne ? feeGrowthGlobal0 : feeGrowthGlobal1,
            crossedInitializedTick: false,
            liquidityCurrent: [
                liquidityCurrent[0],
                liquidityCurrent[1],
                liquidityCurrent[2],
                liquidityCurrent[3],
                liquidityCurrent[4],
                liquidityCurrent[5]
            ]
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
                (step.liquidity, step.fee) = computeLiquidityAndFee(state.liquidityCurrent);
                // protect LPs by adjusting the fee only if the current fee is greater than the stored fee
                step.fee = uint16(Math.max(state.feeFloor, step.fee));

                // recompute reserves given the current price/liquidity
                (step.reserve0Virtual, step.reserve1Virtual) = PriceMath.getVirtualReservesAtPrice(
                    state.price,
                    step.liquidity,
                    false
                );

                // compute the amount of input token required to push the price to the target (and max output token)
                (uint256 amountInMax, uint256 amountOutMax) = PriceMath.getInputToRatio(
                    step.reserve0Virtual,
                    step.reserve1Virtual,
                    step.liquidity,
                    step.priceNext,
                    step.fee,
                    params.zeroForOne
                );

                // swap to the next tick, or stop early if we've exhausted all the input
                step.amountIn = Math.min(amountInMax, state.amountInRemaining);

                // decrement remaining input amount
                state.amountInRemaining -= step.amountIn;

                // discount the input amount by the fee
                uint256 amountInLessFee = step.amountIn.mul(PriceMath.LP_FEE_BASE - step.fee) / PriceMath.LP_FEE_BASE;

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
                    state.feeGrowthGlobal._x += FixedPoint128.fraction(feePaid, step.liquidity)._x;
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

                    int128[NUM_FEE_OPTIONS] memory tickLiquidityDeltas = [
                        tickInfo.liquidityDelta[0],
                        tickInfo.liquidityDelta[1],
                        tickInfo.liquidityDelta[2],
                        tickInfo.liquidityDelta[3],
                        tickInfo.liquidityDelta[4],
                        tickInfo.liquidityDelta[5]
                    ];
                    // update liquidityCurrent, subi from right to left, addi from left to right
                    if (params.zeroForOne) {
                        for (uint8 i = 0; i < NUM_FEE_OPTIONS; i++)
                            state.liquidityCurrent[i] = uint128(state.liquidityCurrent[i].subi(tickLiquidityDeltas[i]));
                    } else {
                        for (uint8 i = 0; i < NUM_FEE_OPTIONS; i++)
                            state.liquidityCurrent[i] = uint128(state.liquidityCurrent[i].addi(tickLiquidityDeltas[i]));
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
            liquidityCurrent[0] = state.liquidityCurrent[0];
            liquidityCurrent[1] = state.liquidityCurrent[1];
            liquidityCurrent[2] = state.liquidityCurrent[2];
            liquidityCurrent[3] = state.liquidityCurrent[3];
            liquidityCurrent[4] = state.liquidityCurrent[4];
            liquidityCurrent[5] = state.liquidityCurrent[5];
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

    // move from right to left (token 1 is becoming more valuable)
    function swap0For1(
        uint256 amount0In,
        address to,
        bytes calldata data
    ) external override lock returns (uint256 amount1Out) {
        require(amount0In > 0, 'UniswapV3Pair::swap0For1: amountIn must be greater than 0');

        SwapParams memory params = SwapParams({zeroForOne: true, amountIn: amount0In, to: to, data: data});
        return _swap(params);
    }

    // move from left to right (token 0 is becoming more valuable)
    function swap1For0(
        uint256 amount1In,
        address to,
        bytes calldata data
    ) external override lock returns (uint256 amount0Out) {
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
