pragma solidity =0.5.16;

import './interfaces/IUniswapV2Factory.sol';
import './UniswapV2Exchange.sol';
import './interfaces/IUniswapV2Exchange.sol';

contract UniswapV2Factory is IUniswapV2Factory {
    address public feeTo;
    address public feeToSetter;

    mapping(address => mapping(address => address)) public getExchange;
    address[] public allExchanges;

    event ExchangeCreated(address indexed token0, address indexed token1, address exchange, uint);

    constructor(address _feeToSetter) public {
        feeToSetter = _feeToSetter;
    }

    function allExchangesLength() external view returns (uint) {
        return allExchanges.length;
    }

    function createExchange(address tokenA, address tokenB) external returns (address exchange) {
        require(tokenA != tokenB, 'UniswapV2: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2: ZERO_ADDRESS');
        require(getExchange[token0][token1] == address(0), 'UniswapV2: EXCHANGE_EXISTS'); // single check is sufficient
        bytes memory exchangeBytecode = type(UniswapV2Exchange).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            exchange := create2(0, add(exchangeBytecode, 32), mload(exchangeBytecode), salt)
        }
        IUniswapV2Exchange(exchange).initialize(token0, token1);
        getExchange[token0][token1] = exchange;
        getExchange[token1][token0] = exchange; // populate mapping in the reverse direction
        allExchanges.push(exchange);
        emit ExchangeCreated(token0, token1, exchange, allExchanges.length);
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
