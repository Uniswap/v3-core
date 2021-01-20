// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

interface IUniswapV3Factory {
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);
    event PairCreated(
        address indexed token0,
        address indexed token1,
        uint24 indexed fee,
        int24 tickSpacing,
        address pair
    );
    event FeeAmountEnabled(uint24 indexed fee, int24 indexed tickSpacing);

    function owner() external view returns (address);

    function allEnabledFeeAmounts(uint256) external view returns (uint24);

    function allEnabledFeeAmountsLength() external view returns (uint256);

    function feeAmountTickSpacing(uint24 fee) external view returns (int24);

    function getPair(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external view returns (address pair);

    function createPair(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external returns (address pair);

    function setOwner(address) external;

    function enableFeeAmount(uint24 fee, int24 tickSpacing) external;
}
