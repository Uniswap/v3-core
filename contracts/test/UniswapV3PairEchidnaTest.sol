// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import '../UniswapV3Pair.sol';
import '../UniswapV3PairDeployer.sol';
import './TestERC20.sol';
import './TestUniswapV3Callee.sol';

contract UniswapV3PairEchidnaTest is UniswapV3PairDeployer {
    TestERC20 private token0;
    TestERC20 private token1;
    UniswapV3Pair private pair;
    TestUniswapV3Callee private callee;

    constructor() {
        token0 = new TestERC20(type(uint256).max);
        token1 = new TestERC20(type(uint256).max);
        if (token1 < token0) (token0, token1) = (token1, token0);
        pair = UniswapV3Pair(deploy(address(this), address(token0), address(token1), 3000, 60));
        callee = new TestUniswapV3Callee();
        token0.approve(address(callee), type(uint256).max);
        token1.approve(address(callee), type(uint256).max);
    }

    // since the factory is this contract
    function owner() external view returns (address) {
        return address(this);
    }

    function mint(
        int24 tickLower,
        int24 tickUpper,
        uint128 amount
    ) external {
        callee.mint(address(pair), address(this), tickLower, tickUpper, amount);
    }

    function burn(
        int24 tickLower,
        int24 tickUpper,
        uint128 amount
    ) external {
        pair.burn(address(this), tickLower, tickUpper, amount);
    }

    function collectAll(int24 tickLower, int24 tickUpper) external {
        pair.collect(address(this), tickLower, tickUpper, type(uint128).max, type(uint128).max);
    }

    function swapExact0For1(uint256 amount0In, uint160 sqrtPriceLimitX96) external {
        callee.swapExact0For1(address(pair), amount0In, address(this), sqrtPriceLimitX96);
    }

    function swapExact1For0(uint256 amount1In, uint160 sqrtPriceLimitX96) external {
        callee.swapExact1For0(address(pair), amount1In, address(this), sqrtPriceLimitX96);
    }
}
