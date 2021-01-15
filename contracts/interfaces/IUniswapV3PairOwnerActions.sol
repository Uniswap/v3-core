// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

interface IUniswapV3PairOwnerActions {
    function setFeeProtocol(uint8) external;

    // allows factory owner to collect protocol fees
    function collectProtocol(
        address recipient,
        uint256 amount0Requested,
        uint256 amount1Requested
    ) external returns (uint256 amount0, uint256 amount1);
}
