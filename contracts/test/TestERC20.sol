// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.0;

import '../openzeppelin/ERC20.sol';

contract TestERC20 is ERC20 {
    constructor(uint256 amountToMint) ERC20('TestERC20', 'TEST') {
        mint(msg.sender, amountToMint);
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
