// https://github.com/makerdao/dss/blob/b1fdcfc9b2ab7961bf2ce7ab4008bfcec1c73a88/src/dai.sol
// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/2f9ae975c8bdc5c7f7fa26204896f6c717f07164/contracts/token/ERC20
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

	// EIP-712
    mapping (address => uint) public nonceFor;
	bytes32 public DOMAIN_SEPARATOR;
    bytes32 public APPROVE_TYPEHASH = keccak256(
		"Approve(address owner,address spender,uint256 value,uint256 nonce,uint256 expiration)"
	);

	event Transfer(address indexed from, address indexed to, uint256 value);
	event Approval(address indexed owner, address indexed spender, uint256 value);

	constructor(string memory _name, string memory _symbol, uint8 _decimals, uint256 _totalSupply) public {
		name = _name;
		symbol = _symbol;
		decimals = _decimals;
		mint(msg.sender, _totalSupply);
	}

    function initialize(uint256 chainId) internal {
		require(DOMAIN_SEPARATOR == bytes32(0), "ERC20: ALREADY_INITIALIZED");
		DOMAIN_SEPARATOR = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256(bytes(name)),
            keccak256(bytes("1")),
            chainId,
            address(this)
        ));
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

	function _approve(address owner, address spender, uint256 value) private {
		allowance[owner][spender] = value;
		emit Approval(owner, spender, value);
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

	function burn(uint256 value) public {
		_burn(msg.sender, value);
	}

	function burnFrom(address from, uint256 value) external {
		if (allowance[from][msg.sender] != uint256(-1)) {
			allowance[from][msg.sender] = allowance[from][msg.sender].sub(value);
		}
		_burn(from, value);
	}

	function approve(address spender, uint256 value) external returns (bool) {
		_approve(msg.sender, spender, value);
		return true;
	}

	function approveMeta(
		address owner,
		address spender,
		uint256 value,
		uint256 nonce,
		uint256 expiration,
		uint8 v,
		bytes32 r,
		bytes32 s
	) external {
		require(DOMAIN_SEPARATOR != bytes32(0), "ERC20: UNINITIALIZED");
        require(nonce == nonceFor[owner]++, "ERC20: INVALID_NONCE");
		require(expiration > block.timestamp, "ERC20: EXPIRED_SIGNATURE");

        bytes32 digest = keccak256(abi.encodePacked(
			byte(0x19),
			byte(0x01),
			DOMAIN_SEPARATOR,
			keccak256(abi.encode(
				APPROVE_TYPEHASH, owner, spender, value, nonce, expiration
			))
        ));
        require(owner == ecrecover(digest, v, r, s), "ERC20: INVALID_SIGNATURE"); // TODO add ECDSA checks? https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/cryptography/ECDSA.sol

		_approve(msg.sender, spender, value);
	}
}
