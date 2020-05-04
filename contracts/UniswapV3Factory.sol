pragma solidity =0.6.6;

import '@uniswap/lib/contracts/libraries/PairNamer.sol';

import './interfaces/IUniswapV3Factory.sol';
import './UniswapV3Pair.sol';

contract UniswapV3Factory is IUniswapV3Factory {
    string public constant PAIR_SYMBOL_SUFFIX = ' (V2)';
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
        // salt is empty bytes32 since token0 and token1 are already included in the init code hash
        pair = address(new UniswapV3Pair{salt: bytes32(0)}(token0, token1));
        UniswapV3Pair(pair).initialize(
            PairNamer.pairName(token0, token1, 'UniswapV3-LP:', ''),
            PairNamer.pairSymbol(token0, token1, PAIR_SYMBOL_SUFFIX)
        );
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
