pragma solidity 0.5.12;

import "./interfaces/IUniswapV2Factory.sol";

import "./UniswapV2.sol";

contract UniswapV2Factory is IUniswapV2Factory {
    struct Pair {
        address token0;
        address token1;
    }

    bytes public exchangeBytecode;
    uint256 public exchangeCount;

    mapping (address => Pair) private exchangeToPair;
    mapping (address => mapping(address => address)) private token0ToToken1ToExchange;
    mapping (address => address[]) private tokensToOtherTokens;

    event ExchangeCreated(address indexed token0, address indexed token1, address exchange, uint256 exchangeCount);

    constructor(bytes memory _exchangeBytecode) public {
        require(_exchangeBytecode.length >= 0x20, "UniswapV2Factory: SHORT_BYTECODE");
        exchangeBytecode = _exchangeBytecode;
    }

    function getTokens(address exchange) external view returns (address, address) {
        Pair storage pair = exchangeToPair[exchange];
        return (pair.token0, pair.token1);
    }

    function getExchange(address tokenA, address tokenB) external view returns (address) {
        Pair memory pair = getPair(tokenA, tokenB);
        return token0ToToken1ToExchange[pair.token0][pair.token1];
    }

    function getOtherTokens(address token) external view returns (address[] memory) {
        return tokensToOtherTokens[token];
    }

    function getOtherTokensLength(address token) external view returns (uint256) {
        return tokensToOtherTokens[token].length;
    }

    function getPair(address tokenA, address tokenB) private pure returns (Pair memory) {
        return tokenA < tokenB ? Pair({ token0: tokenA, token1: tokenB }) : Pair({ token0: tokenB, token1: tokenA });
    }

    function createExchange(address tokenA, address tokenB) external returns (address exchange) {
        require(tokenA != tokenB, "UniswapV2Factory: SAME_ADDRESS");
        require(tokenA != address(0) && tokenB != address(0), "UniswapV2Factory: ZERO_ADDRESS");

        Pair memory pair = getPair(tokenA, tokenB);

        require(token0ToToken1ToExchange[pair.token0][pair.token1] == address(0), "UniswapV2Factory: EXCHANGE_EXISTS");

        bytes memory exchangeBytecodeMemory = exchangeBytecode;
        bytes32 salt = keccak256(abi.encodePacked(pair.token0, pair.token1));
        assembly {
            exchange := create2(
                0,
                add(exchangeBytecodeMemory, 0x20),
                mload(exchangeBytecodeMemory),
                salt
            )
        }
        UniswapV2(exchange).initialize(pair.token0, pair.token1);
        exchangeToPair[exchange] = pair;
        token0ToToken1ToExchange[pair.token0][pair.token1] = exchange;
        tokensToOtherTokens[pair.token0].push(pair.token1);
        tokensToOtherTokens[pair.token1].push(pair.token0);

        emit ExchangeCreated(pair.token0, pair.token1, exchange, exchangeCount++);
    }
}
