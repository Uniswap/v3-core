// TODO meta-approve, review
// based on https://github.com/makerdao/dss/blob/b1fdcfc9b2ab7961bf2ce7ab4008bfcec1c73a88/src/dai.sol and https://github.com/OpenZeppelin/openzeppelin-contracts/blob/2f9ae975c8bdc5c7f7fa26204896f6c717f07164/contracts/token/ERC20
pragma solidity 0.5.12;

import "../interfaces/IERC20.sol";
import "../libraries/SafeMath.sol";

contract ERC20 is IERC20 {
	using SafeMath for uint256;

	string public name;
	string public symbol;
	uint8 public decimals;
	uint256 public totalSupply;
	mapping (address => uint256) public balanceOf;
	mapping (address => mapping (address => uint256)) public allowance;

	event Transfer(address indexed from, address indexed to, uint256 value);
	event Approval(address indexed owner, address indexed spender, uint256 value);

	constructor(string memory _name, string memory _symbol, uint8 _decimals, uint256 _totalSupply) public {
		name = _name;
		symbol = _symbol;
		decimals = _decimals;
		totalSupply = _totalSupply;
		balanceOf[msg.sender] = totalSupply;
	}

	function mint(address to, uint256 value) internal {
		totalSupply = totalSupply.add(value);
		balanceOf[to] = balanceOf[to].add(value);
		emit Transfer(address(0), to, value);
	}

	function _transfer(address from, address to, uint256 value) private {
		balanceOf[from] = balanceOf[from].sub(value);
		balanceOf[to] = balanceOf[to].add(value);
		emit Transfer(from, to, value);
	}

	function _burn(address from, uint256 value) private {
		balanceOf[from] = balanceOf[from].sub(value);
		totalSupply = totalSupply.sub(value);
		emit Transfer(from, address(0), value);
	}

	function transfer(address to, uint256 value) external returns (bool) {
		_transfer(msg.sender, to, value);
		return true;
	}

	function transferFrom(address from, address to, uint256 value) external returns (bool) {
		if (allowance[from][msg.sender] != uint256(-1)) {
			allowance[from][msg.sender] = allowance[from][msg.sender].sub(value);
		}
		_transfer(from, to, value);
		return true;
	}

	function burn(uint256 value) external {
		_burn(msg.sender, value);
	}

	function burnFrom(address from, uint256 value) public {
		if (allowance[from][msg.sender] != uint256(-1)) {
			allowance[from][msg.sender] = allowance[from][msg.sender].sub(value);
		}
		_burn(from, value);
	}

	function approve(address spender, uint256 value) external returns (bool) {
		allowance[msg.sender][spender] = value;
		emit Approval(msg.sender, spender, value);
		return true;
	}
}
