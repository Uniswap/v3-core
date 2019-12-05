pragma solidity 0.5.12;

contract SafeTransfer {
    function safeTransfer(address token, address to, uint value) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSignature("transfer(address,uint256)", to, value));

        require(success, "SafeTransfer: SWAP_REVERTED");

        if (data.length == 32) {
            require(abi.decode(data, (bool)), "SafeTransfer: SWAP_UNSUCCESSFUL");
        } else if (data.length > 32) {
            revert("SafeTransfer: SWAP_INVALID_RETURN");
        }
    }
}