// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0;

import './pair/IUniswapV3PairImmutables.sol';
import './pair/IUniswapV3PairEvents.sol';
import './pair/IUniswapV3PairActions.sol';
import './pair/IUniswapV3PairOwnerActions.sol';
import './pair/IUniswapV3PairState.sol';
import './pair/IUniswapV3PairDerivedState.sol';

/// @title The interface for a Uniswap V3 Pair
/// @notice A Uniswap pair facilitates swapping and automated market making between any two assets that strictly conform
/// to the ERC20 specification
/// @dev The pair interface is broken up into many smaller pieces
interface IUniswapV3Pair is
    IUniswapV3PairImmutables,
    IUniswapV3PairEvents,
    IUniswapV3PairActions,
    IUniswapV3PairOwnerActions,
    IUniswapV3PairState,
    IUniswapV3PairDerivedState
{

}
