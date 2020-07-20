// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.11;

import './interfaces/IUniswapV3Factory.sol';
import './UniswapV3Pair.sol';

contract UniswapV3Factory is IUniswapV3Factory {
    address public override feeTo;
    address public override feeToSetter;

    mapping(address => mapping(address => address)) public override getPair;
    address[] public override allPairs;

    constructor(address _feeToSetter) public {
        feeToSetter = _feeToSetter;
    }

    function allPairsLength() external override view returns (uint) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external override returns (address pair) {
        require(tokenA != tokenB, 'UniswapV3: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV3: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'UniswapV3: PAIR_EXISTS'); // single check is sufficient
        // CREATE2 salt is 0 since token0 and token1 are included as constructor arguments
        pair = address(new UniswapV3Pair{ salt: bytes32(0) }(token0, token1));
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external override {
        require(msg.sender == feeToSetter, 'UniswapV3: FORBIDDEN');
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external override {
        require(msg.sender == feeToSetter, 'UniswapV3: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }
}
