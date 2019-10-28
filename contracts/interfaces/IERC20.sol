pragma solidity 0.5.12;

interface IERC20 {
	event Transfer(address indexed from, address indexed to, uint256 value);
	event Approval(address indexed owner, address indexed spender, uint256 value);

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);

    function chainId() external returns (uint256);
    function nonceFor(address owner) external view returns (uint256);

    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function burn(uint256 value) external;
    function burnFrom(address from, uint256 value) external;
    function approve(address spender, uint256 value) external returns (bool);
    function approveMeta(
        address owner,
        address spender,
        uint256 value,
        uint256 nonce,
        uint256 expiration,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}
