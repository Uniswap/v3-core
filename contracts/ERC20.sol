pragma solidity ^0.5.11;
import "./SafeMath.sol";


contract ERC20 {
  using SafeMath for uint256;

  mapping (address => uint256) public balanceOf;
  mapping (address => mapping (address => uint256)) public allowance;

  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);

  uint256 public totalSupply;
  uint256 internal constant MAX_UINT256 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

  function transfer(address to, uint256 value) public returns (bool) {
    balanceOf[msg.sender] = balanceOf[msg.sender].sub(value);
    balanceOf[to] = balanceOf[to].add(value);
    emit Transfer(msg.sender, to, value);
    return true;
  }

  function transferFrom(address from, address to, uint256 value) public returns (bool) {
    if (allowance[from][msg.sender] < MAX_UINT256) {
      allowance[from][msg.sender] = allowance[from][msg.sender].sub(value);
    }
    balanceOf[from] = balanceOf[from].sub(value);
    balanceOf[to] = balanceOf[to].add(value);
    emit Transfer(from, to, value);
    return true;
  }

  function approve(address spender, uint256 value) public returns (bool) {
    allowance[msg.sender][spender] = value;
    emit Approval(msg.sender, spender, value);
    return true;
  }

  function burn(uint256 value) public {
    totalSupply = totalSupply.sub(value);
    balanceOf[msg.sender] = balanceOf[msg.sender].sub(value);
    emit Transfer(msg.sender, address(0), value);
  }
}
