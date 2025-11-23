// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0; // Optimized: Using Solidity 0.8.x for built-in overflow/underflow checks.

/**
 * @title Prevents delegatecall to a contract
 * @notice Base contract that provides a modifier for preventing unauthorized delegatecall 
 * execution on its methods, typically when used as an implementation or library contract.
 */
abstract contract NoDelegateCall {
    /// @dev The original deployment address of this contract. Stored as immutable for gas efficiency.
    address private immutable original;

    /**
     * @notice Constructor sets the immutable deployment address.
     * @dev address(this) returns the address where the code is executing. 
     * Since 'original' is immutable, its value is computed once during deployment
     * and embedded directly into the deployed bytecode.
     */
    constructor() {
        original = address(this);
    }

    /**
     * @dev Checks if the current execution context (address(this)) matches the 
     * contract's permanent deployment address (original).
     * Using a private function saves gas by preventing the address check logic 
     * and the 'original' address bytes from being copied into every function 
     * that uses the modifier.
     */
    function _checkNotDelegateCall() private view {
        // In a DELEGATECALL, address(this) is the proxy address, not the implementation address (original).
        // This check fails if address(this) != original.
        require(
            address(this) == original,
            "NoDelegateCall: Function can only be called directly"
        );
    }

    /**
     * @notice Prevents delegatecall into the modified method.
     */
    modifier noDelegateCall() {
        _checkNotDelegateCall();
        _;
    }
}
