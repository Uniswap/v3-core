// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.12;

import './interfaces/IUniswapV3Factory.sol';

import './UniswapV3Pair.sol';

contract UniswapV3Factory is IUniswapV3Factory {
    address public override feeToSetter;

    mapping(address => mapping(address => address)) public override getPair;
    address[] public override allPairs;

    constructor(address _feeToSetter) public {
        feeToSetter = _feeToSetter;
    }

    function allPairsLength() external view override returns (uint256) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external override returns (address pair) {
        require(tokenA != tokenB, 'UniswapV3::createPair: tokenA cannot be the same as tokenB');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV3::createPair: tokens cannot be address 0');
        require(getPair[token0][token1] == address(0), 'UniswapV3::createPair: pair already exists'); // single check is sufficient
        // CREATE2 salt is 0 since token0 and token1 are included as constructor arguments
        pair = address(new UniswapV3Pair{salt: bytes32(0)}(address(this), token0, token1));
        getPair[token0][token1] = pair;
        // populate mapping in the reverse direction
        // this is a deliberate choice to avoid the cost of comparing addresses in a getPair function
        getPair[token1][token0] = pair;
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeToSetter(address _feeToSetter) external override {
        require(msg.sender == feeToSetter, 'UniswapV3::setFeeToSetter: must be called by feeToSetter');
        feeToSetter = _feeToSetter;
    }
}
