pragma solidity >=0.5.0;

import '../libraries/TokenNamer.sol';

// used for testing the logic of token naming
contract TokenNamerTest {
    function tokenName(address token) public view returns (string memory) {
        return TokenNamer.tokenName(token);
    }

    function tokenSymbol(address token) public view returns (string memory)  {
        return TokenNamer.tokenSymbol(token);
    }
}

// does not implement name or symbol
contract FakeOptionalERC20 {
}

// complies with ERC20 and returns strings
contract FakeCompliantERC20 {
    string public name;
    string public symbol;
    constructor (string memory name_, string memory symbol_) public {
        name = name_;
        symbol = symbol_;
    }
}

// implements name and symbol but returns bytes32
contract FakeNoncompliantERC20 {
    bytes32 public name;
    bytes32 public symbol;
    constructor (bytes32 name_, bytes32 symbol_) public {
        name = name_;
        symbol = symbol_;
    }
}
