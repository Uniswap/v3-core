pragma solidity 0.5.15;

import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2.sol";
import "./UniswapV2.sol";

contract UniswapV2Factory is IUniswapV2Factory {
    address public feeToSetter;
    address public feeTo;

    mapping (address => mapping(address => address)) private getExchange_;
    address[] public exchanges;

    event ExchangeCreated(address indexed token0, address indexed token1, address exchange, uint);

    constructor(address _feeToSetter) public {
        feeToSetter = _feeToSetter;
    }

    function sortTokens(address tokenA, address tokenB) public pure returns (address token0, address token1) {
        return tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    function getExchange(address tokenA, address tokenB) external view returns (address exchange) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        return getExchange_[token0][token1];
    }

    function exchangesCount() external view returns (uint) {
        return exchanges.length;
    }

    function createExchange(address tokenA, address tokenB) external returns (address exchange) {
        require(tokenA != tokenB, "UniswapV2Factory: SAME_ADDRESS");
        require(tokenA != address(0) && tokenB != address(0), "UniswapV2Factory: ZERO_ADDRESS");
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        require(getExchange_[token0][token1] == address(0), "UniswapV2Factory: EXCHANGE_EXISTS");
        bytes memory exchangeBytecode = type(UniswapV2).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {  // solium-disable-line security/no-inline-assembly
            exchange := create2(0, add(exchangeBytecode, 32), mload(exchangeBytecode), salt)
        }
        IUniswapV2(exchange).initialize(token0, token1);
        getExchange_[token0][token1] = exchange;
        exchanges.push(exchange);
        emit ExchangeCreated(token0, token1, exchange, exchanges.length);
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, "UniswapV2Factory: FORBIDDEN");
        feeToSetter = _feeToSetter;
    }

    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, "UniswapV2Factory: FORBIDDEN");
        feeTo = _feeTo;
    }
}
