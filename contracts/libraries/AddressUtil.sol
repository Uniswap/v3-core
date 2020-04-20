pragma solidity >=0.5.0;

library AddressUtil {
    // converts an address to the hex string, extracting only
    function toAsciiString(address addr, uint len) pure internal returns (string memory) {
        require(len % 2 == 0, "AddressUtil: MULTIPLE_OF_TWO");
        bytes memory s = new bytes(len);
        uint addrNum = uint(addr);
        for (uint i = 0; i < len / 2; i++) {
            // shift right and truncate all but the least significant byte to extract the byte at position 19-i
            uint8 b = uint8(addrNum >> (8 * (19 - i)));
            // first hex character is the most significant 4 bits
            uint8 hi = b >> 4;
            // second hex character is the least significant 4 bits
            uint8 lo = b - (hi << 4);
            s[2 * i] = char(hi);
            s[2 * i + 1] = char(lo);
        }
        return string(s);
    }

    // hi and lo are only 4 bits and between 0 and 16
    // this method converts those values to the unicode/ascii code point for the hex representation
    function char(uint8 b) pure private returns (byte c) {
        if (b < 10) {
            return byte(b + 0x30);
        } else {
            return byte(b + 0x57);
        }
    }
}
