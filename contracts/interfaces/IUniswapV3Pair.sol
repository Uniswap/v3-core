pragma solidity >=0.6.2;

import "./IUniswapV3ERC20.sol";

interface IUniswapV3Pair is IUniswapV3ERC20 {
    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        bool tokenIn,
        uint amountIn,
        uint amountOut,
        address indexed to
    );
    event Give(address indexed from, uint liquidity);
    event Shift(uint16 tick);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
//    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
//    function skim(address to) external;
//    function sync() external;
}
