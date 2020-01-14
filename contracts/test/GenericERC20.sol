pragma solidity 0.5.15;

import "../UniswapV2ERC20.sol";

contract GenericERC20 is UniswapV2ERC20 {
    constructor(uint _totalSupply) public {
        if (_totalSupply > 0) _mint(msg.sender, _totalSupply);
    }
}
