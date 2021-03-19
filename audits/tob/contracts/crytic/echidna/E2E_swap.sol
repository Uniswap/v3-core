pragma solidity =0.7.6;
pragma abicoder v2;

import './Setup.sol';
import '../../../../../contracts/test/TestERC20.sol';
import '../../../../../contracts/libraries/TickMath.sol';
import '../../../../../contracts/UniswapV3Pool.sol';

// import 'hardhat/console.sol';

contract E2E_swap {
    SetupTokens tokens;
    SetupUniswap uniswap;

    UniswapV3Pool pool;

    TestERC20 token0;
    TestERC20 token1;

    UniswapMinter minter;
    UniswapSwapper swapper;

    int24[] usedTicks;
    bool inited;

    struct PoolParams {
        uint24 fee;
        int24 tickSpacing;
        int24 minTick;
        int24 maxTick;
        uint24 tickCount;
        uint160 startPrice;
        int24 startTick;
    }

    struct PoolPositions {
        int24[] tickLowers;
        int24[] tickUppers;
        uint128[] amounts;
    }

    PoolParams poolParams;
    PoolPositions poolPositions;

    constructor() public {
        tokens = new SetupTokens();
        token0 = tokens.token0();
        token1 = tokens.token1();

        uniswap = new SetupUniswap(token0, token1);

        minter = new UniswapMinter(token0, token1);
        swapper = new UniswapSwapper(token0, token1);

        tokens.mintTo(0, address(swapper), 1e9 ether);
        tokens.mintTo(1, address(swapper), 1e9 ether);

        tokens.mintTo(0, address(minter), 1e10 ether);
        tokens.mintTo(1, address(minter), 1e10 ether);
    }

    //
    //
    // Helpers
    //
    //

    function get_random_zeroForOne_priceLimit(int256 _amountSpecified)
        internal
        view
        returns (uint160 sqrtPriceLimitX96)
    {
        // help echidna a bit by calculating a valid sqrtPriceLimitX96 using the amount as random seed
        (uint160 currentPrice, , , , , , ) = pool.slot0();
        uint160 minimumPrice = TickMath.MIN_SQRT_RATIO;
        sqrtPriceLimitX96 =
            minimumPrice +
            uint160(
                (uint256(_amountSpecified > 0 ? _amountSpecified : -_amountSpecified) % (currentPrice - minimumPrice))
            );
    }

    function get_random_oneForZero_priceLimit(int256 _amountSpecified)
        internal
        view
        returns (uint160 sqrtPriceLimitX96)
    {
        // help echidna a bit by calculating a valid sqrtPriceLimitX96 using the amount as random seed
        (uint160 currentPrice, , , , , , ) = pool.slot0();
        uint160 maximumPrice = TickMath.MAX_SQRT_RATIO;
        sqrtPriceLimitX96 =
            currentPrice +
            uint160(
                (uint256(_amountSpecified > 0 ? _amountSpecified : -_amountSpecified) % (maximumPrice - currentPrice))
            );
    }

    //
    //
    // Invariants
    //
    //

    function check_liquidityNet_invariant() internal {
        int128 liquidityNet = 0;
        for (uint256 i = 0; i < usedTicks.length; i++) {
            (, int128 tickLiquidityNet, , ) = pool.ticks(usedTicks[i]);
            int128 result = liquidityNet + tickLiquidityNet;
            assert(
                (tickLiquidityNet >= 0 && result >= liquidityNet) || (tickLiquidityNet < 0 && result < liquidityNet)
            );
            liquidityNet = result;
        }

        // prop #20
        assert(liquidityNet == 0);
    }

    function check_liquidity_invariant() internal {
        (, int24 currentTick, , , , , ) = pool.slot0();
        int128 liquidity = 0;
        for (uint256 i = 0; i < usedTicks.length; i++) {
            int24 tick = usedTicks[i];
            if (tick <= currentTick) {
                (, int128 tickLiquidityNet, , ) = pool.ticks(tick);
                int128 result = liquidity + tickLiquidityNet;
                assert((tickLiquidityNet >= 0 && result >= liquidity) || (tickLiquidityNet < 0 && result < liquidity));
                liquidity = result;
            }
        }

        // prop #21
        assert(uint128(liquidity) == pool.liquidity());
        assert(liquidity >= 0);
    }

    function check_tick_feegrowth_invariant() internal {
        (, int24 currentTick, , , , , ) = pool.slot0();

        if (currentTick == poolParams.maxTick || currentTick == poolParams.minTick) return;

        int24 tickBelow = currentTick - poolParams.tickSpacing;
        int24 tickAbove = currentTick + poolParams.tickSpacing;

        (, , uint256 tB_feeGrowthOutside0X128, uint256 tB_feeGrowthOutside1X128) = pool.ticks(tickBelow);
        (, , uint256 tA_feeGrowthOutside0X128, uint256 tA_feeGrowthOutside1X128) = pool.ticks(tickAbove);

        // prop #22
        assert(tB_feeGrowthOutside0X128 + tA_feeGrowthOutside0X128 <= pool.feeGrowthGlobal0X128());

        // prop #23
        assert(tB_feeGrowthOutside1X128 + tA_feeGrowthOutside1X128 <= pool.feeGrowthGlobal1X128());
    }

    function check_swap_invariants(
        int24 tick_bfre,
        int24 tick_aftr,
        uint128 liq_bfre,
        uint128 liq_aftr,
        uint256 bal_sell_bfre,
        uint256 bal_sell_aftr,
        uint256 bal_buy_bfre,
        uint256 bal_buy_aftr,
        uint256 feegrowth_sell_bfre,
        uint256 feegrowth_sell_aftr,
        uint256 feegrowth_buy_bfre,
        uint256 feegrowth_buy_aftr
    ) internal {
        // prop #17
        if (tick_bfre == tick_aftr) {
            assert(liq_bfre == liq_aftr);
        }

        // prop #13 + #15
        assert(feegrowth_sell_bfre <= feegrowth_sell_aftr);

        // prop #14 + #16
        assert(feegrowth_buy_bfre == feegrowth_buy_aftr);

        // prop #18 + #19
        if (bal_sell_bfre == bal_sell_aftr) {
            assert(bal_buy_bfre == bal_buy_aftr);
        }
    }

    //
    //
    // Helper to reconstruct the "random" init setup of the pool
    //
    //

    function viewRandomInit(uint128 _seed)
        public
        view
        returns (PoolParams memory poolParams, PoolPositions memory poolPositions)
    {
        poolParams = forgePoolParams(_seed);
        poolPositions = forgePoolPositions(_seed, poolParams.tickSpacing, poolParams.tickCount, poolParams.maxTick);
    }

    //
    //
    // Setup functions
    //
    //

    function forgePoolParams(uint128 _seed) internal view returns (PoolParams memory poolParams) {
        //
        // decide on one of the three fees, and corresponding tickSpacing
        //
        if (_seed % 3 == 0) {
            poolParams.fee = uint24(500);
            poolParams.tickSpacing = int24(10);
        } else if (_seed % 3 == 1) {
            poolParams.fee = uint24(3000);
            poolParams.tickSpacing = int24(60);
        } else if (_seed % 3 == 2) {
            poolParams.fee = uint24(10000);
            poolParams.tickSpacing = int24(2000);
        }

        poolParams.maxTick = (int24(887272) / poolParams.tickSpacing) * poolParams.tickSpacing;
        poolParams.minTick = -poolParams.maxTick;
        poolParams.tickCount = uint24(poolParams.maxTick / poolParams.tickSpacing);

        //
        // set the initial price
        //
        poolParams.startTick = int24((_seed % uint128(poolParams.tickCount)) * uint128(poolParams.tickSpacing));
        if (_seed % 3 == 0) {
            // set below 0
            poolParams.startPrice = TickMath.getSqrtRatioAtTick(-poolParams.startTick);
        } else if (_seed % 3 == 1) {
            // set at 0
            poolParams.startPrice = TickMath.getSqrtRatioAtTick(0);
            poolParams.startTick = 0;
        } else if (_seed % 3 == 2) {
            // set above 0
            poolParams.startPrice = TickMath.getSqrtRatioAtTick(poolParams.startTick);
        }
    }

    function forgePoolPositions(
        uint128 _seed,
        int24 _poolTickSpacing,
        uint24 _poolTickCount,
        int24 _poolMaxTick
    ) internal view returns (PoolPositions memory poolPositions_) {
        // between 1 and 10 (inclusive) positions
        uint8 positionsCount = uint8(_seed % 10) + 1;

        poolPositions_.tickLowers = new int24[](positionsCount);
        poolPositions_.tickUppers = new int24[](positionsCount);
        poolPositions_.amounts = new uint128[](positionsCount);

        for (uint8 i = 0; i < positionsCount; i++) {
            int24 tickLower;
            int24 tickUpper;
            uint128 amount;

            int24 randomTick1 = int24((_seed % uint128(_poolTickCount)) * uint128(_poolTickSpacing));

            if (_seed % 2 == 0) {
                // make tickLower positive
                tickLower = randomTick1;

                // tickUpper is somewhere above tickLower
                uint24 poolTickCountLeft = uint24((_poolMaxTick - randomTick1) / _poolTickSpacing);
                int24 randomTick2 = int24((_seed % uint128(poolTickCountLeft)) * uint128(_poolTickSpacing));
                tickUpper = tickLower + randomTick2;
            } else {
                // make tickLower negative or zero
                tickLower = randomTick1 == 0 ? 0 : -randomTick1;

                uint24 poolTickCountNegativeLeft = uint24((_poolMaxTick - randomTick1) / _poolTickSpacing);
                uint24 poolTickCountTotalLeft = poolTickCountNegativeLeft + _poolTickCount;

                uint24 randomIncrement = uint24((_seed % uint128(poolTickCountTotalLeft)) * uint128(_poolTickSpacing));

                if (randomIncrement <= uint24(tickLower)) {
                    // tickUpper will also be negative
                    tickUpper = tickLower + int24(randomIncrement);
                } else {
                    // tickUpper is positive
                    randomIncrement -= uint24(-tickLower);
                    tickUpper = tickLower + int24(randomIncrement);
                }
            }

            amount = uint128(1e8 ether);

            poolPositions_.tickLowers[i] = tickLower;
            poolPositions_.tickUppers[i] = tickUpper;
            poolPositions_.amounts[i] = amount;

            _seed += uint128(tickLower);
        }
    }

    function _init(uint128 _seed) internal {
        //
        // generate random pool params
        //
        poolParams = forgePoolParams(_seed);

        //
        // deploy the pool
        //
        uniswap.createPool(poolParams.fee, poolParams.startPrice);
        pool = uniswap.pool();

        //
        // set the pool inside the minter and swapper contracts
        //
        minter.setPool(pool);
        swapper.setPool(pool);

        //
        // generate random positions
        //
        poolPositions = forgePoolPositions(_seed, poolParams.tickSpacing, poolParams.tickCount, poolParams.maxTick);

        //
        // create the positions
        //
        for (uint8 i = 0; i < poolPositions.tickLowers.length; i++) {
            int24 tickLower = poolPositions.tickLowers[i];
            int24 tickUpper = poolPositions.tickUppers[i];
            uint128 amount = poolPositions.amounts[i];

            minter.doMint(tickLower, tickUpper, amount);

            bool lowerAlreadyUsed = false;
            bool upperAlreadyUsed = false;
            for (uint8 j = 0; j < usedTicks.length; j++) {
                if (usedTicks[j] == tickLower) lowerAlreadyUsed = true;
                else if (usedTicks[j] == tickUpper) upperAlreadyUsed = true;
            }
            if (!lowerAlreadyUsed) usedTicks.push(tickLower);
            if (!upperAlreadyUsed) usedTicks.push(tickUpper);
        }

        inited = true;
    }

    //
    //
    // Functions to fuzz
    //
    //

    function test_swap_exactIn_zeroForOne(uint128 _amount) public {
        require(_amount != 0);

        if (!inited) _init(_amount);

        require(token0.balanceOf(address(swapper)) >= uint256(_amount));
        int256 _amountSpecified = int256(_amount);

        uint160 sqrtPriceLimitX96 = get_random_zeroForOne_priceLimit(_amount);
        // console.log('sqrtPriceLimitX96 = %s', sqrtPriceLimitX96);

        (UniswapSwapper.SwapperStats memory bfre, UniswapSwapper.SwapperStats memory aftr) =
            swapper.doSwap(true, _amountSpecified, sqrtPriceLimitX96);

        check_swap_invariants(
            bfre.tick,
            aftr.tick,
            bfre.liq,
            aftr.liq,
            bfre.bal0,
            aftr.bal0,
            bfre.bal1,
            aftr.bal1,
            bfre.feeGrowthGlobal0X128,
            aftr.feeGrowthGlobal0X128,
            bfre.feeGrowthGlobal1X128,
            aftr.feeGrowthGlobal1X128
        );

        check_liquidityNet_invariant();
        check_liquidity_invariant();
        check_tick_feegrowth_invariant();
    }

    function test_swap_exactIn_oneForZero(uint128 _amount) public {
        require(_amount != 0);

        if (!inited) _init(_amount);

        require(token1.balanceOf(address(swapper)) >= uint256(_amount));
        int256 _amountSpecified = int256(_amount);

        uint160 sqrtPriceLimitX96 = get_random_oneForZero_priceLimit(_amount);
        // console.log('sqrtPriceLimitX96 = %s', sqrtPriceLimitX96);

        (UniswapSwapper.SwapperStats memory bfre, UniswapSwapper.SwapperStats memory aftr) =
            swapper.doSwap(false, _amountSpecified, sqrtPriceLimitX96);

        check_swap_invariants(
            bfre.tick,
            aftr.tick,
            bfre.liq,
            aftr.liq,
            bfre.bal1,
            aftr.bal1,
            bfre.bal0,
            aftr.bal0,
            bfre.feeGrowthGlobal1X128,
            aftr.feeGrowthGlobal1X128,
            bfre.feeGrowthGlobal0X128,
            aftr.feeGrowthGlobal0X128
        );

        check_liquidityNet_invariant();
        check_liquidity_invariant();
        check_tick_feegrowth_invariant();
    }

    function test_swap_exactOut_zeroForOne(uint128 _amount) public {
        require(_amount != 0);

        if (!inited) _init(_amount);

        require(token0.balanceOf(address(swapper)) > 0);
        int256 _amountSpecified = -int256(_amount);

        uint160 sqrtPriceLimitX96 = get_random_zeroForOne_priceLimit(_amount);
        // console.log('sqrtPriceLimitX96 = %s', sqrtPriceLimitX96);

        (UniswapSwapper.SwapperStats memory bfre, UniswapSwapper.SwapperStats memory aftr) =
            swapper.doSwap(true, _amountSpecified, sqrtPriceLimitX96);

        check_swap_invariants(
            bfre.tick,
            aftr.tick,
            bfre.liq,
            aftr.liq,
            bfre.bal0,
            aftr.bal0,
            bfre.bal1,
            aftr.bal1,
            bfre.feeGrowthGlobal0X128,
            aftr.feeGrowthGlobal0X128,
            bfre.feeGrowthGlobal1X128,
            aftr.feeGrowthGlobal1X128
        );

        check_liquidityNet_invariant();
        check_liquidity_invariant();
        check_tick_feegrowth_invariant();
    }

    function test_swap_exactOut_oneForZero(uint128 _amount) public {
        require(_amount != 0);

        if (!inited) _init(_amount);

        require(token0.balanceOf(address(swapper)) > 0);
        int256 _amountSpecified = -int256(_amount);

        uint160 sqrtPriceLimitX96 = get_random_oneForZero_priceLimit(_amount);
        // console.log('sqrtPriceLimitX96 = %s', sqrtPriceLimitX96);

        (UniswapSwapper.SwapperStats memory bfre, UniswapSwapper.SwapperStats memory aftr) =
            swapper.doSwap(false, _amountSpecified, sqrtPriceLimitX96);

        check_swap_invariants(
            bfre.tick,
            aftr.tick,
            bfre.liq,
            aftr.liq,
            bfre.bal1,
            aftr.bal1,
            bfre.bal0,
            aftr.bal0,
            bfre.feeGrowthGlobal1X128,
            aftr.feeGrowthGlobal1X128,
            bfre.feeGrowthGlobal0X128,
            aftr.feeGrowthGlobal0X128
        );

        check_liquidityNet_invariant();
        check_liquidity_invariant();
        check_tick_feegrowth_invariant();
    }
}
