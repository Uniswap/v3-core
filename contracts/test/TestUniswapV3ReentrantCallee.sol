// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.12;

import {TickMath} from '../libraries/TickMath.sol';

import {IUniswapV3SwapCallback} from '../interfaces/callback/IUniswapV3SwapCallback.sol';

import {IUniswapV3Pool} from '../interfaces/IUniswapV3Pool.sol';

contract TestUniswapV3ReentrantCallee is IUniswapV3SwapCallback {
    string private constant expectedError = 'LOK()';

    function swapToReenter(address pool) external {
        IUniswapV3Pool(pool).swap(address(0), false, 1, TickMath.MAX_SQRT_RATIO - 1, new bytes(0));
    }

    function uniswapV3SwapCallback(
        int256,
        int256,
        bytes calldata
    ) external override {
        // try to reenter swap
        try IUniswapV3Pool(msg.sender).swap(address(0), false, 1, 0, new bytes(0)) {} catch (bytes memory error) {
            require(keccak256(error) == keccak256(abi.encodeWithSignature(expectedError)));
        }

        // try to reenter mint
        try IUniswapV3Pool(msg.sender).mint(address(0), 0, 0, 0, new bytes(0)) {} catch (bytes memory error) {
            require(keccak256(error) == keccak256(abi.encodeWithSignature(expectedError)));
        }

        // try to reenter collect
        try IUniswapV3Pool(msg.sender).collect(address(0), 0, 0, 0, 0) {} catch (bytes memory error) {
            require(keccak256(error) == keccak256(abi.encodeWithSignature(expectedError)));
        }

        // try to reenter burn
        try IUniswapV3Pool(msg.sender).burn(0, 0, 0) {} catch (bytes memory error) {
            require(keccak256(error) == keccak256(abi.encodeWithSignature(expectedError)));
        }

        // try to reenter flash
        try IUniswapV3Pool(msg.sender).flash(address(0), 0, 0, new bytes(0)) {} catch (bytes memory error) {
            require(keccak256(error) == keccak256(abi.encodeWithSignature(expectedError)));
        }

        // try to reenter collectProtocol
        try IUniswapV3Pool(msg.sender).collectProtocol(address(0), 0, 0) {} catch (bytes memory error) {
            require(keccak256(error) == keccak256(abi.encodeWithSignature(expectedError)));
        }

        require(false, 'Unable to reenter');
    }
}
