// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

contract NoDelegateCall {
    address private immutable me;

    constructor() {
        me = address(this);
    }

    modifier noDelegateCall() {
        require(address(this) == me);
        _;
    }
}
