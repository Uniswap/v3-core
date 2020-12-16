// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.7.6;

import './interfaces/IUniswapV3Factory.sol';

import './UniswapV3Pair.sol';

contract UniswapV3Factory is IUniswapV3Factory {
    address public override owner;

    mapping(uint24 => int24) public override feeAmountTickSpacing;
    uint24[] public override allEnabledFeeAmounts;

    mapping(address => mapping(address => mapping(uint24 => address))) public override getPair;
    address[] public override allPairs;

    function allPairsLength() external view override returns (uint256) {
        return allPairs.length;
    }

    function allEnabledFeeAmountsLength() external view override returns (uint256) {
        return allEnabledFeeAmounts.length;
    }

    constructor(address _owner) {
        owner = _owner;
        emit OwnerChanged(address(0), _owner);

        _enableFeeAmount(600, 12);
        _enableFeeAmount(3000, 60);
        _enableFeeAmount(9000, 180);
    }

    function createPair(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external override returns (address pair) {
        require(tokenA != tokenB, 'UniswapV3Factory::createPair: tokenA cannot be the same as tokenB');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV3Factory::createPair: tokens cannot be address 0');
        int24 tickSpacing = feeAmountTickSpacing[fee];
        require(tickSpacing != 0, 'UniswapV3Factory::createPair: fee amount is not allowed');
        require(getPair[token0][token1][fee] == address(0), 'UniswapV3Factory::createPair: pair already exists');
        // CREATE2 salt is 0 since token0, token1, and fee are included as constructor arguments
        pair = address(new UniswapV3Pair{salt: bytes32(0)}(address(this), token0, token1, fee, tickSpacing));
        allPairs.push(pair);
        getPair[token0][token1][fee] = pair;
        // populate mapping in the reverse direction, deliberate choice to avoid the cost of comparing addresses
        getPair[token1][token0][fee] = pair;
        emit PairCreated(token0, token1, fee, tickSpacing, pair, allPairs.length);
    }

    function setOwner(address _owner) external override {
        require(msg.sender == owner, 'UniswapV3Factory::setOwner: must be called by owner');
        emit OwnerChanged(owner, _owner);
        owner = _owner;
    }

    function _enableFeeAmount(uint24 fee, int24 tickSpacing) private {
        require(fee < 1000000, 'UniswapV3Factory::_enableFeeAmount: fee amount be greater than or equal to 100%');
        require(tickSpacing > 0, 'UniswapV3Factory::_enableFeeAmount: tick spacing must be greater than 0');
        require(feeAmountTickSpacing[fee] == 0, 'UniswapV3Factory::_enableFeeAmount: fee amount is already enabled');

        feeAmountTickSpacing[fee] = tickSpacing;
        allEnabledFeeAmounts.push(fee);
        emit FeeAmountEnabled(fee, tickSpacing);
    }

    function enableFeeAmount(uint24 fee, int24 tickSpacing) external override {
        require(msg.sender == owner, 'UniswapV3Factory::enableFeeAmount: must be called by owner');

        _enableFeeAmount(fee, tickSpacing);
    }
}
