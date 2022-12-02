// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;

/// @title Prevents delegatecall to a contract
/// @notice Base contract that provides a modifier for preventing delegatecall to methods in a child contract
abstract contract NoDelegateCall {
    constructor() public {
        // Store the address of the contract in a variable
        address original = address(this);

        // Define a modifier that checks if the current contract's
        // address matches the original address
        modifier noDelegateCall() {
            require(address(this) == original, "Delegate call detected");
            _;
        }
    }
}
