pragma solidity >=0.5.0;

import './SafeERC20Namer.sol';

// produces names for pairs of tokens using Uniswap's naming scheme
library PairNamer {
    string private constant TOKEN_SYMBOL_PREFIX = '🦄';
    string private constant TOKEN_SEPARATOR = ':';

    // produces a pair symbol in the format of `🦄${symbol0}:${symbol1}${suffix}`
    function pairSymbol(address token0, address token1, string memory suffix) internal view returns (string memory) {
        return string(
            abi.encodePacked(
                TOKEN_SYMBOL_PREFIX,
                SafeERC20Namer.tokenSymbol(token0),
                TOKEN_SEPARATOR,
                SafeERC20Namer.tokenSymbol(token1),
                suffix
            )
        );
    }
}
