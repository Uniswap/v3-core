// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.7.6;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract TestERC20 is ERC20 {
    constructor(uint256 amountToMint) ERC20('TestERC20', 'TEST') {
        mint(msg.sender, amountToMint);
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
