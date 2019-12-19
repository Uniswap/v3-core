pragma solidity 0.5.14;

import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2.sol";

contract UniswapV2Factory is IUniswapV2Factory {
    bytes public exchangeBytecode;
    address public factoryOwner;
    address public feeRecipient;

    mapping (address => mapping(address => address)) private _getExchange;
    mapping (address => address[2]) private _getTokens;
    address[] public exchanges;

    event ExchangeCreated(address indexed token0, address indexed token1, address exchange, uint exchangeNumber);

    constructor(bytes memory _exchangeBytecode, address _factoryOwner) public {
        require(_exchangeBytecode.length >= 32, "UniswapV2Factory: SHORT_BYTECODE");
        exchangeBytecode = _exchangeBytecode;
        factoryOwner = _factoryOwner;
    }

    function sortTokens(address tokenA, address tokenB) public pure returns (address token0, address token1) {
        return tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    function getExchange(address tokenA, address tokenB) external view returns (address exchange) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        return _getExchange[token0][token1];
    }

    function getTokens(address exchange) external view returns (address token0, address token1) {
        return (_getTokens[exchange][0], _getTokens[exchange][1]);
    }

    function exchangesCount() external view returns (uint) {
        return exchanges.length;
    }

    function createExchange(address tokenA, address tokenB) external returns (address exchange) {
        require(tokenA != tokenB, "UniswapV2Factory: SAME_ADDRESS");
        require(tokenA != address(0) && tokenB != address(0), "UniswapV2Factory: ZERO_ADDRESS");
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        require(_getExchange[token0][token1] == address(0), "UniswapV2Factory: EXCHANGE_EXISTS");

        bytes memory exchangeBytecodeMemory = exchangeBytecode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly { // solium-disable-line security/no-inline-assembly
            exchange := create2(0, add(exchangeBytecodeMemory, 32), mload(exchangeBytecodeMemory), salt)
        }
        IUniswapV2(exchange).initialize(token0, token1);

        _getExchange[token0][token1] = exchange;
        _getTokens[exchange] = [token0, token1];
        emit ExchangeCreated(token0, token1, exchange, exchanges.push(exchange));
    }

    function setFactoryOwner(address _factoryOwner) external {
        require(msg.sender == factoryOwner, "UniswapV2Factory: FORBIDDEN");
        factoryOwner = _factoryOwner;
    }

    function setFeeRecipient(address _feeRecipient) external {
        require(msg.sender == factoryOwner, "UniswapV2Factory: FORBIDDEN");
        feeRecipient = _feeRecipient;
    }
}
