pragma solidity 0.5.15;

import "../UniswapV2Exchange.sol";

contract GenericERC20 is UniswapV2Exchange {
    constructor(uint _totalSupply) public {
        if (_totalSupply > 0) _mint(msg.sender, _totalSupply);
    }
}
