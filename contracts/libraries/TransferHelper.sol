// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.6.0;

/// @title TransferHelper
/// @notice This library contains helper methods for interacting with ERC20 tokens and sending ETH that do not consistently return true/false
library TransferHelper {
    /// @notice Transfers tokens from msg.sender to a recipient
    /// @dev Calls transfer on token contract via abi.encodeWithSelector, errors with TF if transfer fails
    /// @param token The contract address of the token which will be transferred
    /// @param to The recipient of the transfer
    /// @param value The value of the transfer
    function safeTransfer(
        address token,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TF');
    }

    /// @notice Transfers tokens from an arbitrary address to a recipient
    /// @dev Calls transferFrom on token contract via abi.encodeWithSelector, errors with TFF if transfer fails
    /// @param token The contract address of the token which will be transferred
    /// @param from The address of the account from which the transfer will be initiated
    /// @param to The recipient of the transfer
    /// @param value The value of the transfer
    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TFF');
    }
}
