// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.12;

import './interfaces/IUniswapV3Factory.sol';

import './UniswapV3Pair.sol';

/// @notice The Uniswap V3 Factory.
/// @notice A factory for creating new V3 trading pairs.
/// @dev Creates new pairs at deterministic addresses.
contract UniswapV3Factory is IUniswapV3Factory {
    address public override owner;

    mapping(uint24 => int24) public override feeAmountTickSpacing;
    uint24[] public override allEnabledFeeAmounts;

    mapping(address => mapping(address => mapping(uint24 => address))) public override getPair;
    address[] public override allPairs;

    /// @notice Gets length of allPairs array.
    /// @return The length of allPairs address array.
    function allPairsLength() external view override returns (uint256) {
        return allPairs.length;
    }

    /// @notice Gets length of allEnabledFeeAmounts array.
    /// @return Length of allEnabledFeeAmounts array.
    function allEnabledFeeAmountsLength() external view override returns (uint256) {
        return allEnabledFeeAmounts.length;
    }

    /// @notice The Factory contract constructor.
    /// @param _owner The owner of the Factory contract.
    constructor(address _owner) public {
        owner = _owner;
        emit OwnerChanged(address(0), _owner);

        _enableFeeAmount(600, 1);
        _enableFeeAmount(3000, 1);
        _enableFeeAmount(9000, 1);
    }

    /// @notice Deploys a new trading pair.
    /// @param tokenA the first token of the desired pair.
    /// @param tokenB the second token of the desired pair.
    /// @param fee the desired fee.
    /// @return pair Returns the address of the newly deployed pair.
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

    /// @notice Sets Factory contract owner to a new address.
    /// @param _owner The new owner of the factory contract.
    /// @dev only callable by current owner of factory contract.
    function setOwner(address _owner) external override {
        require(msg.sender == owner, 'UniswapV3Factory::setOwner: must be called by owner');
        emit OwnerChanged(owner, _owner);
        owner = _owner;
    }

    /// @dev see enableFeeAmount.
    function _enableFeeAmount(uint24 fee, int24 tickSpacing) private {
        require(fee < 1000000, 'UniswapV3Factory::_enableFeeAmount: fee amount be greater than or equal to 100%');
        require(feeAmountTickSpacing[fee] == 0, 'UniswapV3Factory::_enableFeeAmount: fee amount is already enabled');
        require(tickSpacing > 0, 'UniswapV3Factory::_enableFeeAmount: tick spacing must be greater than 0');

        feeAmountTickSpacing[fee] = tickSpacing;
        allEnabledFeeAmounts.push(fee);
        emit FeeAmountEnabled(fee, tickSpacing);
    }

    /// @notice If chosen, enables the fee option when a pair is deployed.
    /// @param fee The chosen fee option - passed via createPair.
    function enableFeeAmount(uint24 fee, int24 tickSpacing) external override {
        require(msg.sender == owner, 'UniswapV3Factory::enableFeeAmount: must be called by owner');

        _enableFeeAmount(fee, tickSpacing);
    }
}
