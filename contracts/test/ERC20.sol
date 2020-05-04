pragma solidity >=0.6.0;

import '../UniswapV3ERC20.sol';

contract ERC20 is UniswapV3ERC20 {
    constructor(uint _totalSupply) public {
        _mint(msg.sender, _totalSupply);
    }

    // for tests, allow updating the name and symbol
    function testSetNameAndSymbol(string calldata name_, string calldata symbol_) external {
        _initialize(name_, symbol_);
    }
}
