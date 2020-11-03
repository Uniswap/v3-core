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

    TestERC20 token0;
    TestERC20 token1;

    UniswapV3Factory factory;
    UniswapV3Pair pair;

    constructor() public {
        factory = new UniswapV3Factory(address(this));
        initializeTokens();
        createNewPair();
        token0.approve(address(pair), uint256(-1));
        token1.approve(address(pair), uint256(-1));
        initializePair(0, 1e18, 2);
    }

    function initializeTokens() private {
        TestERC20 tokenA = new TestERC20(uint256(-1));
        TestERC20 tokenB = new TestERC20(uint256(-1));
        (token0, token1) = (address(tokenA) < address(tokenB) ? (tokenA, tokenB) : (tokenB, tokenA));
    }

    function createNewPair() private {
        pair = UniswapV3Pair(factory.createPair(address(token0), address(token1)));
    }

    function initializePair(
        int16 tick,
        uint112 amount0,
        uint8 feeVote
    ) private {
        FixedPoint.uq112x112 memory price = TickMath.getRatioAtTick(tick);
        uint112 amount1 = FullMath.mulDiv(amount0, price._x, uint256(1) << 112).toUint112();
        pair.initialize(amount0, amount1, tick, feeVote % pair.NUM_FEE_OPTIONS());
    }

    function swap0For1(uint112 amount0In) external {
        require(amount0In < 1e18);
        pair.swap0For1(amount0In, address(this), '');
    }

    function swap1For0(uint112 amount1In) external {
        require(amount1In < 1e18);
        pair.swap1For0(amount1In, address(this), '');
    }

    function setPosition(
        int16 tickLower,
        int16 tickUpper,
        uint8 feeVote,
        int112 liquidityDelta
    ) external {
        pair.setPosition(tickLower, tickUpper, feeVote % pair.NUM_FEE_OPTIONS(), liquidityDelta);
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

    function echidna_isInitialized() external view returns (bool) {
        return (address(token0) != address(0) &&
            address(token1) != address(0) &&
            address(factory) != address(0) &&
            address(pair) != address(0));
    }
}
