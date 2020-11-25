// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.12;

import './interfaces/IUniswapV3Factory.sol';

import './UniswapV3Pair.sol';

contract UniswapV3Factory is IUniswapV3Factory {
    uint8 public constant override FEE_OPTIONS_COUNT = 6;

    // list of fee options expressed as bips
    // uint16 because the maximum value is 1e4
    // ideally this would be a constant array, but constant arrays are not supported in solidity
    function FEE_OPTIONS(uint8 feeOption) public pure override returns (uint16 fee) {
        if (feeOption < 3) {
            if (feeOption == 0) return 6;
            if (feeOption == 1) return 12;
            return 30;
        }
        if (feeOption == 3) return 60;
        if (feeOption == 4) return 120;
        assert(feeOption == 5);
        return 240;
    }

    address public override feeToSetter;

    address[] public override allPairs;

    function allPairsLength() external view override returns (uint256) {
        return allPairs.length;
    }

    mapping(address => mapping(address => mapping(uint8 => address))) public override getPair;

    constructor(address _feeToSetter) public {
        feeToSetter = _feeToSetter;
        emit FeeToSetterChanged(address(0), _feeToSetter);
    }

    function createPair(
        address tokenA,
        address tokenB,
        uint8 feeOption
    ) external override returns (address pair) {
        require(tokenA != tokenB, 'UniswapV3::createPair: tokenA cannot be the same as tokenB');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV3::createPair: tokens cannot be address 0');
        require(feeOption < FEE_OPTIONS_COUNT, 'UniswapV3::createPair: invalid fee option');
        require(getPair[token0][token1][feeOption] == address(0), 'UniswapV3::createPair: pair already exists');
        // CREATE2 salt is 0 since token0, token1, and fee are included as constructor arguments
        pair = address(new UniswapV3Pair{salt: bytes32(0)}(address(this), token0, token1, FEE_OPTIONS(feeOption)));
        allPairs.push(pair);
        getPair[token0][token1][feeOption] = pair;
        // populate mapping in the reverse direction, deliberate choice to avoid the cost of comparing addresses
        getPair[token1][token0][feeOption] = pair;
        emit PairCreated(token0, token1, feeOption, pair, allPairs.length);
    }

    function setFeeToSetter(address _feeToSetter) external override {
        require(msg.sender == feeToSetter, 'UniswapV3::setFeeToSetter: must be called by feeToSetter');
        emit FeeToSetterChanged(feeToSetter, _feeToSetter);
        feeToSetter = _feeToSetter;
    }
}
