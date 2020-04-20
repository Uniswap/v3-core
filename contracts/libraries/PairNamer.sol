pragma solidity >=0.5.0;

import './strings.sol';
import './TokenNamer.sol';

library PairNamer {
    using strings for *;

    string private constant TOKEN_SYMBOL_PREFIX = '🦄';
    string private constant TOKEN_SEPARATOR = ':';

    function pairSymbol(address token0, address token1) internal view returns (string memory) {
        strings.slice memory ts_0 = TokenNamer.tokenSymbol(token0).toSlice();
        strings.slice memory ts_1 = TokenNamer.tokenSymbol(token1).toSlice();

        return TOKEN_SYMBOL_PREFIX.toSlice()
            .concat(ts_0).toSlice()
            .concat(TOKEN_SEPARATOR.toSlice()).toSlice()
            .concat(ts_1).toSlice()
            .toString();
    }
}
