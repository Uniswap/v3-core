pragma solidity >=0.5.0;

import './AddressUtil.sol';

// produces token symbols from inconsistent or absent ERC20 symbol implementations that can return string or bytes32
// this library will always produce a string symbol to represent the token
library TokenNamer {
    function bytes32ToString(bytes memory x) pure internal returns (string memory) {
        bytes memory bytesString = new bytes(32);
        uint charCount = 0;
        for (uint j = 0; j < 32; j++) {
            byte char = x[j];
            if (char != 0) {
                bytesString[charCount] = char;
                charCount++;
            }
        }
        bytes memory bytesStringTrimmed = new bytes(charCount);
        for (uint j = 0; j < charCount; j++) {
            bytesStringTrimmed[j] = bytesString[j];
        }
        return string(bytesStringTrimmed);
    }

    // assumes the data is in position 2
    function parseStringData(bytes memory b) pure internal returns (string memory) {
        uint charCount = 0;
        // first parse the charCount out of the data
        for (uint i = 32; i < 64; i++) {
            charCount <<= 8;
            charCount += uint8(b[i]);
        }

        bytes memory bytesStringTrimmed = new bytes(charCount);
        for (uint i = 0; i < charCount; i++) {
            bytesStringTrimmed[i] = b[i + 64];
        }

        return string(bytesStringTrimmed);
    }

    // uses a heuristic to produce a token symbol from the address
    // the heuristic returns the first 6 hex of the address string in lower case
    function addressToSymbol(address token) pure internal returns (string memory) {
        return AddressUtil.toAsciiString(token, 6);
    }

    // attempts to extract the token symbol. if it does not implement symbol, returns a symbol derived from the address
    function tokenSymbol(address token) internal view returns (string memory) {
        // 0x95d89b41 = bytes4(keccak256("symbol()"))
        (bool success, bytes memory data) = token.staticcall(
            abi.encodeWithSelector(0x95d89b41)
        );
        // if not implemented, or returns empty data, fallback to address
        if (!success || data.length == 0) {
            return addressToSymbol(token);
        }
        // bytes32 data always has length 32
        if (data.length == 32) {
            // if the data does not represent an empty string, use it
            string memory result = bytes32ToString(data);
            if (bytes(result).length > 0) {
                return result;
            }
        } else if (data.length > 64) {
            // if string is not empty, use it
            string memory result = parseStringData(data);
            if (bytes(result).length > 0) {
                return result;
            }
        }
        // fallback to 6 uppercase hex of address
        return addressToSymbol(token);
    }
}
