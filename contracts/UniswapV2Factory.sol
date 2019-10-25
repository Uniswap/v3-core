// TODO create2 exchanges
pragma solidity 0.5.12;

import "./interfaces/IUniswapV2Factory.sol";

import "./UniswapV2.sol";

contract UniswapV2Factory is IUniswapV2Factory {
    event ExchangeCreated(address indexed token0, address indexed token1, address exchange, uint256 exchangeCount);

    struct Pair {
        address token0;
        address token1;
    }

    bytes public exchangeBytecode;
    uint256 public exchangeCount;
    mapping (address => Pair) private exchangeToPair;
    mapping (address => mapping(address => address)) private token0ToToken1ToExchange;

    constructor(bytes memory _exchangeBytecode) public {
        require(_exchangeBytecode.length >= 0x20, "UniswapV2Factory: SHORT_BYTECODE");
        exchangeBytecode = _exchangeBytecode;
    }

    function orderTokens(address tokenA, address tokenB) private pure returns (Pair memory pair) {
        pair = tokenA < tokenB ? Pair({ token0: tokenA, token1: tokenB }) : Pair({ token0: tokenB, token1: tokenA });
    }

    function getTokens(address exchange) public view returns (address token0, address token1) {
        Pair storage pair = exchangeToPair[exchange];
        (token0, token1) = (pair.token0, pair.token1);
    }

    function getExchange(address tokenA, address tokenB) public view returns (address exchange) {
        Pair memory pair = orderTokens(tokenA, tokenB);
        exchange = token0ToToken1ToExchange[pair.token0][pair.token1];
    }

    function createExchange(address tokenA, address tokenB) public returns (address exchange) {
        require(tokenA != tokenB, "UniswapV2Factory: SAME_TOKEN");
        require(tokenA != address(0) && tokenB != address(0), "UniswapV2Factory: ZERO_ADDRESS_TOKEN");

        Pair memory pair = orderTokens(tokenA, tokenB);

        require(token0ToToken1ToExchange[pair.token0][pair.token1] == address(0), "UniswapV2Factory: EXCHANGE_EXISTS");

        bytes memory exchangeBytecodeMemory = exchangeBytecode;
        uint256 exchangeBytecodeLength = exchangeBytecode.length;
        bytes32 salt = keccak256(abi.encodePacked(pair.token0, pair.token1));
        assembly {
            exchange := create2(
                0,
                add(exchangeBytecodeMemory, 0x20),
                exchangeBytecodeLength,
                salt
            )
        }
        UniswapV2(exchange).initialize(pair.token0, pair.token1);
        exchangeToPair[exchange] = pair;
        token0ToToken1ToExchange[pair.token0][pair.token1] = exchange;

        emit ExchangeCreated(pair.token0, pair.token1, exchange, exchangeCount++);
    }
}
