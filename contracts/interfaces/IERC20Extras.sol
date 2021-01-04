// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;

interface IERC20Extras {
    function increaseAllowance(address spender, uint256 addedValue) external returns (bool);
}
