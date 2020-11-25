// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

interface IUniswapV3Factory {
    event FeeToSetterChanged(address indexed feeToSetterOld, address indexed feeToSetterNew);
    event PairCreated(address indexed token0, address indexed token1, uint8 indexed feeOption, address pair, uint256);

    function FEE_OPTIONS_COUNT() external pure returns (uint8);
    function FEE_OPTIONS(uint8 feeOption) external pure returns (uint16 fee);

    function feeToSetter() external view returns (address);

    function allPairs(uint256) external view returns (address pair);
    function allPairsLength() external view returns (uint256);

    function getPair(address tokenA, address tokenB, uint8 feeOption) external view returns (address pair);

    function createPair(address tokenA, address tokenB, uint8 feeOption) external returns (address pair);

    function setFeeToSetter(address) external;
}
