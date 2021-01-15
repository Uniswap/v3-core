// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

import './pair/IUniswapV3PairImmutables.sol';
import './pair/IUniswapV3PairEvents.sol';
import './pair/IUniswapV3PairActions.sol';
import './pair/IUniswapV3PairOwnerActions.sol';
import './pair/IUniswapV3PairState.sol';
import './pair/IUniswapV3PairDerivedState.sol';

interface IUniswapV3Pair is
    IUniswapV3PairImmutables,
    IUniswapV3PairEvents,
    IUniswapV3PairActions,
    IUniswapV3PairOwnerActions,
    IUniswapV3PairState,
    IUniswapV3PairDerivedState
{}
