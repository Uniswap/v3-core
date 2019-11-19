pragma solidity 0.5.12;

import "../token/ERC20.sol";

contract GenericERC20 is ERC20 {
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _totalSupply
    ) ERC20(_name, _symbol, _decimals, _totalSupply) public {}
}
