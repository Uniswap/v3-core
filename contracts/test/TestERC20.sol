// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.5.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract TestERC20 is ERC20 {
    constructor (uint amountToMint) ERC20('TestERC20', 'TEST') public {
        mint(msg.sender, amountToMint);
    }

    function mint(address to, uint amount) public {
        _mint(to, amount);
    }
}
