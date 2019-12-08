pragma solidity 0.5.13;

library Math {
    function add512(uint x0, uint x1, uint y0, uint y1) internal pure returns (uint z0, uint z1) {
        assembly { // solium-disable-line security/no-inline-assembly
            z0 := add(x0, y0)
            z1 := add(add(x1, y1), lt(z0, x0))
        }
    }
    function mul512(uint x, uint y) internal pure returns (uint z0, uint z1) {
        assembly { // solium-disable-line security/no-inline-assembly
            z0 := mul(x, y)
            let mm := mulmod(x, y, not(0))
            z1 := sub(sub(mm, z0), lt(mm, z0))
        }
    }

    function min(uint x, uint y) internal pure returns (uint z) {
        return x <= y ? x : y;
    }

    function sqrt(uint y) internal pure returns (uint z) {
        if (y == 0) return 0;
        else if (y <= 3) return 1;
        uint x = (y + 1) / 2;
        z = y;
        while (x < z) {
            z = x;
            x = (y / x + x) / 2;
        }
    }
}
