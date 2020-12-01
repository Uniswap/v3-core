// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.12;

import '@uniswap/lib/contracts/libraries/FullMath.sol';

import '@openzeppelin/contracts/math/SafeMath.sol';

import './TestERC20.sol';
import '../UniswapV3Pair.sol';
import '../UniswapV3Factory.sol';
import '../libraries/SafeCast.sol';

contract UniswapV3PairEchidnaTest {
    using SafeMath for uint256;
    using SafeCast for uint256;

    TestERC20 token0;
    TestERC20 token1;

    UniswapV3Factory factory;
    UniswapV3Pair pair;

    constructor() public {
        factory = new UniswapV3Factory(address(this));
        initializeTokens();
        createNewPair(30);
        token0.approve(address(pair), uint256(-1));
        token1.approve(address(pair), uint256(-1));
    }

    function initializeTokens() private {
        TestERC20 tokenA = new TestERC20(uint256(-1));
        TestERC20 tokenB = new TestERC20(uint256(-1));
        (token0, token1) = (address(tokenA) < address(tokenB) ? (tokenA, tokenB) : (tokenB, tokenA));
    }

    function createNewPair(uint24 fee) private {
        pair = UniswapV3Pair(factory.createPair(address(token0), address(token1), fee));
    }

    function initializePair(uint256 price) public {
        pair.initialize(price);
    }

    function swap0For1(uint256 amount0In) external {
        require(amount0In < 1e18);
        pair.swap0For1(amount0In, address(this), '');
    }

    function swap1For0(uint256 amount1In) external {
        require(amount1In < 1e18);
        pair.swap1For0(amount1In, address(this), '');
    }

    function setPosition(
        int24 tickLower,
        int24 tickUpper,
        int128 liquidityDelta
    ) external {
        pair.setPosition(tickLower, tickUpper, liquidityDelta);
    }

    function turnOnFee() external {
        pair.setFeeTo(address(this));
    }

    function turnOffFee() external {
        pair.setFeeTo(address(0));
    }

    function recoverToken0() external {
        pair.recover(address(token0), address(this), 1);
    }

    function recoverToken1() external {
        pair.recover(address(token1), address(this), 1);
    }

    function echidna_tickIsWithinBounds() external view returns (bool) {
        int24 tick = pair.getTickAtRatio(pair.priceCurrent());
        return (tick < pair.MAX_TICK() && tick >= pair.MIN_TICK());
    }

    function echidna_priceIsWithinTickCurrent() external view returns (bool) {
        int24 tick = pair.getTickAtRatio(pair.priceCurrent());
        FixedPoint128.uq128x128 memory priceCurrent = FixedPoint128.uq128x128(pair.priceCurrent());
        return (pair.getRatioAtTick(tick) <= priceCurrent._x && pair.getRatioAtTick(tick + 1) > priceCurrent._x);
    }

    function echidna_isInitialized() external view returns (bool) {
        return (address(token0) != address(0) &&
            address(token1) != address(0) &&
            address(factory) != address(0) &&
            address(pair) != address(0));
    }
}
