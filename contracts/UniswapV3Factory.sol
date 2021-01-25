// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import './interfaces/IUniswapV3Factory.sol';

import './UniswapV3Pair.sol';
import './UniswapV3PairDeployer.sol';
import './NoDelegateCall.sol';

contract UniswapV3Factory is IUniswapV3Factory, UniswapV3PairDeployer, NoDelegateCall {
    address public override owner;

    mapping(uint24 => int24) public override feeAmountTickSpacing;
    mapping(address => mapping(address => mapping(uint24 => address))) public override getPair;

    constructor() {
        owner = msg.sender;
        emit OwnerChanged(address(0), msg.sender);

        feeAmountTickSpacing[600] = 12;
        emit FeeAmountEnabled(600, 12);
        feeAmountTickSpacing[3000] = 60;
        emit FeeAmountEnabled(3000, 60);
        feeAmountTickSpacing[9000] = 180;
        emit FeeAmountEnabled(9000, 180);
    }

    function createPair(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external override noDelegateCall returns (address pair) {
        require(tokenA != tokenB, 'A=B');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'A=0');
        int24 tickSpacing = feeAmountTickSpacing[fee];
        require(tickSpacing != 0, 'FNA');
        require(getPair[token0][token1][fee] == address(0), 'PAE');
        pair = deploy(address(this), token0, token1, fee, tickSpacing);
        getPair[token0][token1][fee] = pair;
        // populate mapping in the reverse direction, deliberate choice to avoid the cost of comparing addresses
        getPair[token1][token0][fee] = pair;
        emit PairCreated(token0, token1, fee, tickSpacing, pair);
    }

    function setOwner(address _owner) external override {
        require(msg.sender == owner, 'OO');
        emit OwnerChanged(owner, _owner);
        owner = _owner;
    }

    function enableFeeAmount(uint24 fee, int24 tickSpacing) public override {
        require(msg.sender == owner, 'OO');
        require(fee < 1000000, 'FEE');
        require(tickSpacing > 0, 'TS');
        require(feeAmountTickSpacing[fee] == 0, 'FAI');

        feeAmountTickSpacing[fee] = tickSpacing;
        emit FeeAmountEnabled(fee, tickSpacing);
    }
}
