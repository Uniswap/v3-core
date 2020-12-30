// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

interface IERC3156FlashBorrower {
    function onFlashLoan(
        address user,
        address token,
        uint256 value,
        uint256 fee,
        bytes calldata
    ) external;
}
