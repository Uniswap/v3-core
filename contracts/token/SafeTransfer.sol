pragma solidity 0.5.12;

import "../interfaces/IIncompatibleERC20.sol";

contract SafeTransfer {
    function safeTransfer(address token, address to, uint256 value) internal returns (bool result) {
        IIncompatibleERC20(token).transfer(to, value);

        assembly {
            switch returndatasize()
                case 0 { // if there was no return data, treat the transfer as successful
                    result := 1
                }
                case 0x20 { // if the return data was 32 bytes long, return that value
                    returndatacopy(0, 0, 0x20)
                    result := mload(0)
                }
                default { // revert in all other cases
                    revert(0, 0)
                }
        }
    }
}