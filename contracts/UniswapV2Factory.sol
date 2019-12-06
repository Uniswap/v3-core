pragma solidity 0.5.12;

import "./interfaces/IUniswapV2Factory.sol";

import "./UniswapV2.sol";

contract UniswapV2Factory is IUniswapV2Factory {
    bytes public exchangeBytecode;

    mapping (address => address[2]) private exchangeToTokens;
    mapping (address => mapping(address => address)) private token0ToToken1ToExchange;
    mapping (address => address[]) private tokensToOtherTokens;
    address[] public exchanges;

    event ExchangeCreated(address indexed token0, address indexed token1, address exchange, uint exchangeNumber);

    constructor(bytes memory _exchangeBytecode) public {
        require(_exchangeBytecode.length >= 0x20, "UniswapV2Factory: SHORT_BYTECODE");
        exchangeBytecode = _exchangeBytecode;
    }

    function getTokens(address exchange) external view returns (address token0, address token1) {
        return (exchangeToTokens[exchange][0], exchangeToTokens[exchange][1]);
    }

    function getExchange(address tokenA, address tokenB) external view returns (address exchange) {
        (address token0, address token1) = getTokenOrder(tokenA, tokenB);
        return token0ToToken1ToExchange[token0][token1];
    }

    function getOtherTokens(address token) external view returns (address[] memory) {
        return tokensToOtherTokens[token];
    }

    function getOtherTokensLength(address token) external view returns (uint) {
        return tokensToOtherTokens[token].length;
    }

    function getExchangesLength() external view returns(uint) {
        return exchanges.length;
    }

    function getTokenOrder(address tokenA, address tokenB) private pure returns (address token0, address token1) {
        return tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    function createExchange(address tokenA, address tokenB) external returns (address exchange) {
        require(tokenA != tokenB, "UniswapV2Factory: SAME_ADDRESS");
        require(tokenA != address(0) && tokenB != address(0), "UniswapV2Factory: ZERO_ADDRESS");

        (address token0, address token1) = getTokenOrder(tokenA, tokenB);
        require(token0ToToken1ToExchange[token0][token0] == address(0), "UniswapV2Factory: EXCHANGE_EXISTS");

        bytes memory exchangeBytecodeMemory = exchangeBytecode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            exchange := create2(
                0,
                add(exchangeBytecodeMemory, 0x20),
                mload(exchangeBytecodeMemory),
                salt
            )
        }
        UniswapV2(exchange).initialize(token0, token1);

        exchangeToTokens[exchange] = [token0, token1];
        token0ToToken1ToExchange[token0][token1] = exchange;
        tokensToOtherTokens[token0].push(token1);
        tokensToOtherTokens[token1].push(token0);

        emit ExchangeCreated(token0, token1, exchange, exchanges.push(exchange));
    }
}
