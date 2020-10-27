// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.12;

import '@uniswap/lib/contracts/libraries/FullMath.sol';
import '@uniswap/lib/contracts/libraries/FixedPoint.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

import './TestERC20.sol';
import '../UniswapV3Pair.sol';
import '../UniswapV3Factory.sol';
import '../libraries/SafeCast.sol';

contract UniswapV3PairEchidnaTest {
    using SafeMath for uint256;
    using SafeCast for uint256;

    UniswapV3Factory factory;

    TestERC20 token0;
    TestERC20 token1;
    UniswapV3Pair pair;

    constructor() public {
        factory = new UniswapV3Factory(address(this));
        createNewPair(0, 1e18, 2);
    }

    function createNewPair(
        int16 tick,
        uint112 amount0,
        uint8 feeVote
    ) private {
        TestERC20 tokenA = new TestERC20(0);
        TestERC20 tokenB = new TestERC20(0);
        (token0, token1) = (address(tokenA) < address(tokenB) ? (tokenA, tokenB) : (tokenB, tokenA));
        pair = UniswapV3Pair(factory.createPair(address(tokenA), address(tokenB)));
        initialize(tick, amount0, feeVote);
    }

    function initialize(
        int16 tick,
        uint112 amount0,
        uint8 feeVote
    ) private {
        require(tick < TickMath.MAX_TICK && tick > TickMath.MIN_TICK);

        FixedPoint.uq112x112 memory price = TickMath.getRatioAtTick(tick);
        uint112 amount1 = FullMath.mulDiv(amount0, price._x, uint256(1) << 112).toUint112();

        token0.mint(address(this), amount0);
        token1.mint(address(this), amount1);

        token0.approve(address(pair), amount0);
        token1.approve(address(pair), amount1);

        pair.initialize(amount0, amount1, tick, feeVote % pair.NUM_FEE_OPTIONS());
    }

    //    function swap0For1(uint112 amount0In) external {
    //        token0.mint(address(this), amount0In);
    //        token0.approve(address(pair), amount0In);
    //        pair.swap0For1(amount0In, address(this), '');
    //    }

    function echidna_isInitialized() external view returns (bool) {
        return (address(token0) != address(0) &&
            address(token1) != address(0) &&
            address(factory) != address(0) &&
            address(pair) != address(0));
    }
}
