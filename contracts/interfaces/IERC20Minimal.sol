// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

/// @title Minimal ERC20 interface for Uniswap
/// @notice Contains a subset of the full ERC20 interface that is used in Uniswap V3
interface IERC20Minimal {
    /// @notice Returns the balance of a token
    function balanceOf(address account) external view returns (uint256);

    /// @notice Transfers the amount of token from the `msg.sender` to the recipient
    function transfer(address recipient, uint256 amount) external returns (bool);

    /// @notice Returns the current allowance given to a spender by an owner.
    function allowance(address owner, address spender) external view returns (uint256);

    /// @notice Sets the allowance of a spender from the `msg.sender` of the amount `amount`
    function approve(address spender, uint256 amount) external returns (bool);

    /// @notice Transfers from the sender, and deducts from the allowance of the sender.
    /// The allowance of `msg.sender` must be greater than or equal to the amount.
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    /// @notice Event emitted when tokens are transferred from one address to another, either via `#transfer` or `#transferFrom`.
    event Transfer(address indexed from, address indexed to, uint256 value);

    /// @notice Event emitted when the approval amount for the spender of a given owner's tokens changes.
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
