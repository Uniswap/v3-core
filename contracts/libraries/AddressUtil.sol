pragma solidity >=0.5.0;

library AddressUtil {
    function toAsciiString(address x, uint len) pure internal returns (string memory) {
        bytes memory s = new bytes(len);
        for (uint i = 0; i < len / 2; i++) {
            byte b = byte(uint8(uint(x) / (2 ** (8 * (19 - i)))));
            byte hi = byte(uint8(b) / 16);
            byte lo = byte(uint8(b) - 16 * uint8(hi));
            s[2 * i] = char(hi);
            s[2 * i + 1] = char(lo);
        }
        return string(s);
    }

    function char(byte b) pure private returns (byte c) {
        if (uint8(b) < 10) {
            return byte(uint8(b) + 0x30);
        } else {
            return byte(uint8(b) + 0x57);
        }
    }
}
