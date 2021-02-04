// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

/// @title Permissioned pair actions
/// @notice Contains pair methods that may only be called by the factory owner
interface IUniswapV3PairOwnerActions {
    /// @notice Set the denominator of the protocol's share of the collected fees for this pair
    /// @dev The value passed in is the denominator of the split between the liquidity provider and the protocol for
    /// fees collected by the pair. E.g. a value of 6 means the protocol will collect 1/6th of all fees collected
    /// by the pair.
    /// @param feeProtocol new protocol fee for the pair
    function setFeeProtocol(uint8 feeProtocol) external;

    /// @notice Collect the protocol fee accrued to the pair
    /// @param recipient The address to which collected protocol fees should be sent
    /// @param amount0Requested The maximum amount of token0 to send, can be 0 to collect fees in only token1
    /// @param amount1Requested The maximum amount of token1 to send, can be 0 to collect fees in only token0
    function collectProtocol(
        address recipient,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external returns (uint128 amount0, uint128 amount1);
}
