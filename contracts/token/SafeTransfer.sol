pragma solidity 0.5.13;

contract SafeTransfer {
    function safeTransfer(address token, address to, uint value) internal {
        // solium-disable-next-line security/no-low-level-calls
        (bool success, bytes memory data) = token.call(abi.encodeWithSignature("transfer(address,uint256)", to, value));
        require(success, "SafeTransfer: SWAP_FAILED");
        if (data.length > 0) {
            require(abi.decode(data, (bool)), "SafeTransfer: SWAP_UNSUCCESSFUL");
        }
    }
}