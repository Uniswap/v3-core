pragma solidity >=0.5.0;

interface IUniswapV3Callee {
    function uniswapV3Call(address sender, uint amount0, uint amount1, bytes calldata data) external;
}
