pragma solidity >=0.6.2;

interface IUniswapV3Pair {
    event Swap(
        address indexed sender,
        bool tokenIn,
        uint amountIn,
        uint amountOut,
        address indexed to
    );
    event Shift(uint16 tick);
    event Add(address indexed sender, uint112 liquidity, uint16 lowerTick, uint16 upperTick);
    event Remove(address indexed sender, uint112 liquidity, uint16 lowerTick, uint16 upperTick);

    function MINIMUM_LIQUIDITY() external pure returns (uint112);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function initialAdd(uint112 amount0, uint112 amount1, uint16 startingTick) external returns (uint112 liquidity);
    function add(uint112 liquidity, uint16 lowerTick, uint16 upperTick) external;
    function remove(uint112 liquidity, uint16 lowerTick, uint16 upperTick) external;
    function sync(uint16 lowerTick, uint16 upperTick) external;
}
