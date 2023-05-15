// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

/// @title Callback for ILeChainPoolActions#flash
/// @notice Any contract that calls ILeChainPoolActions#flash must implement this interface
interface ILeChainFlashCallback {
    /// @notice Called to `msg.sender` after transferring to the recipient from ILeChainPool#flash.
    /// @dev In the implementation you must repay the pool the tokens sent by flash plus the computed fee amounts.
    /// The caller of this method must be checked to be a LeChainPool deployed by the canonical LeChainFactory.
    /// @param fee0 The fee amount in token0 due to the pool by the end of the flash
    /// @param fee1 The fee amount in token1 due to the pool by the end of the flash
    /// @param data Any data passed through by the caller via the ILeChainPoolActions#flash call
    function flashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external;
}
