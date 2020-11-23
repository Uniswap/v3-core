// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

import '@uniswap/lib/contracts/libraries/TransferHelper.sol';

library CheckedTransferHelper {
    using SafeMath for uint256;

    function checkedSafeTransferFrom(address token, address from, address to, uint256 value) internal {
        uint256 balanceBefore = IERC20(token).balanceOf(to);
        TransferHelper.safeTransferFrom(token, from, to, value);
        require(
            IERC20(token).balanceOf(to) >= balanceBefore.add(value),
            'CheckedTransferHelper::checkedSafeTransferFrom: transferFrom sent fewer tokens than expected'
        );
    }
}
