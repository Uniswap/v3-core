// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

abstract contract NoDelegateCall {
    address private immutable original;

    constructor() {
        original = address(this);
    }

    function checkNotDelegateCall() private view {
        require(address(this) == original);
    }

    modifier noDelegateCall() {
        checkNotDelegateCall();
        _;
    }
}
