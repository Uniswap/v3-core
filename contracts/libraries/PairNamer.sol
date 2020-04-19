pragma solidity >=0.5.0;

import './strings.sol';
import './TokenNamer.sol';

library PairNamer {
    using strings for *;

    string private constant TOKEN_NAME_PREFIX = 'UniswapV2: ';
    string private constant TOKEN_SYMBOL_PREFIX = 'u-';
    string private constant TOKEN_SYMBOL_SUFFIX = '-v2';
    string private constant TOKEN_SEPARATOR = hex'f09fa684';

    function pairName(address token0, address token1) internal returns (string memory) {
        return TOKEN_NAME_PREFIX.toSlice()
            .concat(TokenNamer.tokenName(token0).toSlice()).toSlice()
            .concat(TOKEN_SEPARATOR.toSlice()).toSlice()
            .concat(TokenNamer.tokenName(token1).toSlice()).toSlice()
            .toString();
    }

    function pairSymbol(address token0, address token1) internal returns (string memory) {
        strings.slice memory ts_0 = TokenNamer.tokenSymbol(token0).toSlice();
        strings.slice memory ts_1 = TokenNamer.tokenSymbol(token1).toSlice();

        return TOKEN_SYMBOL_PREFIX.toSlice()
            .concat(ts_0).toSlice()
            .concat(TOKEN_SEPARATOR.toSlice()).toSlice()
            .concat(ts_1).toSlice()
            .concat(TOKEN_SYMBOL_SUFFIX.toSlice()).toSlice()
            .toString();
    }
}
