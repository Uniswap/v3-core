// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.12;

import './interfaces/IUniswapV3Factory.sol';

import './UniswapV3Pair.sol';

contract UniswapV3Factory is IUniswapV3Factory {
    address public override owner;

    mapping(uint16 => bool) public override isFeeOptionEnabled;
    uint16[] public override allEnabledFeeOptions;

    mapping(address => mapping(address => mapping(uint16 => address))) public override getPair;
    address[] public override allPairs;

    function allPairsLength() external view override returns (uint256) {
        return allPairs.length;
    }

    function allEnabledFeeOptionsLength() external view override returns (uint256) {
        return allEnabledFeeOptions.length;
    }

    constructor(address _owner) public {
        owner = _owner;
        emit OwnerChanged(address(0), _owner);

        _enableFeeOption(6);
        _enableFeeOption(12);
        _enableFeeOption(30);
        _enableFeeOption(60);
        _enableFeeOption(120);
        _enableFeeOption(240);
    }

    function createPair(
        address tokenA,
        address tokenB,
        uint16 fee
    ) external override returns (address pair) {
        require(tokenA != tokenB, 'UniswapV3Factory::createPair: tokenA cannot be the same as tokenB');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV3Factory::createPair: tokens cannot be address 0');
        require(isFeeOptionEnabled[fee], 'UniswapV3Factory::createPair: fee option is not enabled');
        require(getPair[token0][token1][fee] == address(0), 'UniswapV3Factory::createPair: pair already exists');
        // CREATE2 salt is 0 since token0, token1, and fee are included as constructor arguments
        pair = address(new UniswapV3Pair{salt: bytes32(0)}(address(this), token0, token1, fee));
        allPairs.push(pair);
        getPair[token0][token1][fee] = pair;
        // populate mapping in the reverse direction, deliberate choice to avoid the cost of comparing addresses
        getPair[token1][token0][fee] = pair;
        emit PairCreated(token0, token1, fee, pair, allPairs.length);
    }

    function setOwner(address _owner) external override {
        require(msg.sender == owner, 'UniswapV3Factory::setOwner: must be called by owner');
        emit OwnerChanged(owner, _owner);
        owner = _owner;
    }

    function _enableFeeOption(uint16 fee) private {
        require(fee < 10000, 'UniswapV3Factory::enableFeeOption: fee cannot be greater than or equal to 100%');
        require(isFeeOptionEnabled[fee] == false, 'UniswapV3Factory::enableFeeOption: fee option is already enabled');

        isFeeOptionEnabled[fee] = true;
        allEnabledFeeOptions.push(fee);
        emit FeeOptionEnabled(fee);
    }

    function enableFeeOption(uint16 fee) external override {
        require(msg.sender == owner, 'UniswapV3Factory::enableFeeOption: must be called by owner');

        _enableFeeOption(fee);
    }
}
