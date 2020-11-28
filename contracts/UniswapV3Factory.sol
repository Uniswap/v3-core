// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.12;

import './interfaces/IUniswapV3Factory.sol';

import './UniswapV3Pair.sol';

/// @title The Uniswap V3 Factory contract.
/// @dev Creates new trading pairs at deterministic addresses.
contract UniswapV3Factory is IUniswapV3Factory {
    address public override owner;

    mapping(uint24 => bool) public override isFeeOptionEnabled;
    uint24[] public override allEnabledFeeOptions;

    mapping(address => mapping(address => mapping(uint24 => address))) public override getPair;
    address[] public override allPairs;

    /// @notice Gets length of allPairs array.
    /// @return length of allPairs address array.
    function allPairsLength() external view override returns (uint256) {
        return allPairs.length;
    }

    /// @notice Gets length of allEnabledFeeOptions array.
    /// @return Length of allEnabledFeeOptions array.
    function allEnabledFeeOptionsLength() external view override returns (uint256) {
        return allEnabledFeeOptions.length;
    }

    /// @notice The Factory contract constructor.
    /// @param _owner The owner of the Factory contract.
    constructor(address _owner) public {
        owner = _owner;
        emit OwnerChanged(address(0), _owner);

        _enableFeeOption(600);
        _enableFeeOption(1200);
        _enableFeeOption(3000);
        _enableFeeOption(6000);
        _enableFeeOption(12000);
        _enableFeeOption(24000);
    }

    /// @notice Deploys a new trading pair.
    /// @param tokenA the first token of the desired pair.
    /// @param tokenB the second token of the desired pair.
    /// @param fee the desired fee.
    /// @return The address of the newly deployed pair.
    function createPair(
        address tokenA,
        address tokenB,
        uint24 fee
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

    /// @notice Sets Factory contract owner to a new address.
    function setOwner(address _owner) external override {
        require(msg.sender == owner, 'UniswapV3Factory::setOwner: must be called by owner');
        emit OwnerChanged(owner, _owner);
        owner = _owner;
    }

    /// @notice see enableFeeOption.
    function _enableFeeOption(uint24 fee) private {
        require(fee < 1000000, 'UniswapV3Factory::enableFeeOption: fee cannot be greater than or equal to 100%');
        require(isFeeOptionEnabled[fee] == false, 'UniswapV3Factory::enableFeeOption: fee option is already enabled');

        isFeeOptionEnabled[fee] = true;
        allEnabledFeeOptions.push(fee);
        emit FeeOptionEnabled(fee);
    }

    /// @notice If chosen, enables the fee option when a pair is deployed.
    /// @param fee The chosen fee option - passed via createPair.
    function enableFeeOption(uint24 fee) external override {
        require(msg.sender == owner, 'UniswapV3Factory::enableFeeOption: must be called by owner');

        _enableFeeOption(fee);
    }
}
