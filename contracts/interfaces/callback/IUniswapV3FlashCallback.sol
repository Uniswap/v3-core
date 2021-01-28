// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

/// @title Callback for IUniswapV3PairActions#flash
/// @notice A contract that calls IUniswapV3PairActions#flash must implement this interface
interface IUniswapV3FlashCallback {
    /// @notice Called after transferring tokens to the `msg.sender` to allow the sender to perform any actions and then
    ///     repay the flash
    /// @param fee0 the fee amount in token0 due to the pair by the end of the flash
    /// @param fee1 the fee amount in token1 due to the pair by the end of the flash
    /// @param data any data passed through by the caller via the IUniswapV3PairActions#flash call
    /// @dev The caller of this method must be checked to be a UniswapV3Pair deployed by the canonical factory
    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external;
}
