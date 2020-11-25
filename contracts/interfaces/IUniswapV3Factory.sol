// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

interface IUniswapV3Factory {
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);
    event PairCreated(address indexed token0, address indexed token1, uint24 indexed fee, address pair, uint256);
    event FeeOptionEnabled(uint24 indexed fee);

    function owner() external view returns (address);

    function allPairs(uint256) external view returns (address pair);

    function allPairsLength() external view returns (uint256);

    function allEnabledFeeOptions(uint256) external view returns (uint24);

    function allEnabledFeeOptionsLength() external view returns (uint256);

    function getPair(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external view returns (address pair);

    function isFeeOptionEnabled(uint24 fee) external view returns (bool);

    function createPair(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external returns (address pair);

    function setOwner(address) external;

    function enableFeeOption(uint24 fee) external;
}
