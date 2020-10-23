// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.12;

import './TestERC20.sol';
import '../UniswapV3Pair.sol';
import '../UniswapV3Factory.sol';

contract UniswapV3PairEchidnaTest {
    TestERC20 token0;
    TestERC20 token1;
    UniswapV3Factory factory;
    UniswapV3Pair pair;

    constructor() public {
        TestERC20 tokenA = new TestERC20(1e24);
        TestERC20 tokenB = new TestERC20(1e24);
        (token0, token1) = (address(tokenA) < address(tokenB) ? (tokenA, tokenB) : (tokenB, tokenA));
        factory = new UniswapV3Factory(address(this));
        pair = UniswapV3Pair(factory.createPair(address(tokenA), address(tokenB)));
    }

    function initializePair(uint112 amount0, uint112 amount1, uint8 feeVote) external {
        token0.approve(address(pair), amount0);
        token1.approve(address(pair), amount1);
        pair.initialize(
            amount0,
            amount1,
            0,
            feeVote % pair.NUM_FEE_OPTIONS()
        );
    }

    function echidna_isInitialized() external view returns (bool) {
        return (address(token0) != address(0) && address(token1) != address(0) && address(factory) != address(0) && address(pair) != address(0));
    }
}
