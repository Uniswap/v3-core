// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

contract NoDelegateCall {
    address private immutable original;

    constructor() {
        original = address(this);
    }

    modifier noDelegateCall() {
        assert(address(this) == original);
        _;
    }
}
