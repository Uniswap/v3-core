pragma solidity ^0.5.11;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20Detailed.sol";


// Example class - a mock class using delivering from ERC20
contract Token is ERC20, ERC20Detailed {
  constructor(string memory _name, string memory _symbol, uint8 _decimals, uint256 initialBalance)
    public
    ERC20Detailed(_name, _symbol, _decimals)
  {
    super._mint(msg.sender, initialBalance);
  }
}
