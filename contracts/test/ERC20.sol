pragma solidity >=0.6.0;

import '../UniswapV3ERC20.sol';

contract ERC20 is UniswapV3ERC20 {
    constructor(uint _totalSupply) public {
        _mint(msg.sender, _totalSupply);
    }
}
