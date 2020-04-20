pragma solidity >=0.6.0;

import '../UniswapV2ERC20.sol';

contract ERC20 is UniswapV2ERC20 {
    constructor(uint _totalSupply) public {
        _mint(msg.sender, _totalSupply);
    }

    // for tests, allow updating the symbol
    function updateSymbol(string calldata symbol_) external {
        symbol = symbol_;
    }
}
