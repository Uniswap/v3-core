// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

import '../interfaces/IERC20Minimal.sol';

/// @title LowGasBalanceOf
/// @dev This library enables fetching the token balance of an address without triggering an EXTCODESIZE
library LowGasBalanceOf {
    function balanceOf(address token, address owner) internal view returns (uint256) {
        (bool success, bytes memory data) =
            token.staticcall(abi.encodeWithSelector(IERC20Minimal.balanceOf.selector, owner));
        require(success && data.length == 32);
        return abi.decode(data, (uint256));
    }
}
