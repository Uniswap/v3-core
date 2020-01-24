pragma solidity =0.5.16;

import './interfaces/IUniswapV2Factory.sol';
import './UniswapV2Exchange.sol';
import './interfaces/IUniswapV2Exchange.sol';

contract UniswapV2Factory is IUniswapV2Factory {
    address public feeTo;
    address public feeToSetter;

    mapping(address => mapping(address => address)) private _getExchange;
    address[] public exchanges;

    event ExchangeCreated(address indexed token0, address indexed token1, address exchange, uint);

    constructor(address _feeToSetter) public {
        feeToSetter = _feeToSetter;
    }

    function sortTokens(address tokenA, address tokenB) public pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'UniswapV2: SAME_ADDRESS');
        require(tokenA != address(0) && tokenB != address(0), 'UniswapV2: ZERO_ADDRESS');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    function getExchange(address tokenA, address tokenB) external view returns (address exchange) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        exchange = _getExchange[token0][token1];
    }

    function exchangesCount() external view returns (uint) {
        return exchanges.length;
    }

    function createExchange(address tokenA, address tokenB) external returns (address exchange) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        require(_getExchange[token0][token1] == address(0), 'UniswapV2: EXCHANGE_EXISTS');
        bytes memory exchangeBytecode = type(UniswapV2Exchange).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            exchange := create2(0, add(exchangeBytecode, 32), mload(exchangeBytecode), salt)
        }
        IUniswapV2Exchange(exchange).initialize(token0, token1);
        _getExchange[token0][token1] = exchange;
        exchanges.push(exchange);
        emit ExchangeCreated(token0, token1, exchange, exchanges.length);
    }

    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }
}
