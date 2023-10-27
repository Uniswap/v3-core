pragma solidity =0.8.12;

import './interfaces/IERC20Minimal.sol';
import './interfaces/IUniswapV3Pool.sol';

/**
 * @title UniswapV3SampleCallbacks
 * @dev This contract provides sample callback implementations for Uniswap V3.
 *      These are illustrative and may not be suitable for production use.
 */
abstract contract UniswapV3SampleCallbacks {    

    // Cant take data as the createLimitOrder function doesn't take data as argument, so we have to gather the token and the receiver addresses from the context.
    function uniswapV3MintCallback(uint256 amount0Owed, uint256 amount1Owed, bytes calldata data) external {  
        if (amount0Owed > 0)
            IERC20Minimal(IUniswapV3Pool(msg.sender).token0()).transferFrom(address(this), msg.sender, amount0Owed);
        if (amount1Owed > 0)
            IERC20Minimal(IUniswapV3Pool(msg.sender).token1()).transferFrom(address(this), msg.sender, amount1Owed);
    }

    function uniswapV3SwapCallback(int256 amount0, int256 amount1, bytes calldata data) public {
        // Decode the data directly into individual variables
        (address token0, address token1, address payer) = abi.decode(data, (address, address, address));

        if (amount0 > 0) {
            IERC20Minimal(token0).transferFrom(payer, msg.sender, uint256(amount0));
        }

        if (amount1 > 0) {
            IERC20Minimal(token1).transferFrom(payer, msg.sender, uint256(amount1));
        }
    }
}
