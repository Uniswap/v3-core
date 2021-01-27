// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

abstract contract NoDelegateCall {
    address private immutable original;

    constructor() {
        original = address(this);
    }

    modifier noDelegateCall() {
        require(address(this) == original);
        _;
    }
}
