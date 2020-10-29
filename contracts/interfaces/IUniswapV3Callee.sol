// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

interface IUniswapV3Callee {
    function swap0For1Callback(
        address sender,
        uint256 amount1Out,
        bytes calldata data
    ) external;

    function swap1For0Callback(
        address sender,
        uint256 amount0Out,
        bytes calldata data
    ) external;
}
