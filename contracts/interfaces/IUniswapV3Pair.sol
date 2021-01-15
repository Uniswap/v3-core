// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

import './IUniswapV3PairImmutables.sol';
import './IUniswapV3PairEvents.sol';
import './IUniswapV3PairActions.sol';
import './IUniswapV3PairState.sol';
import './IUniswapV3PairDerivedState.sol';

interface IUniswapV3Pair is
    IUniswapV3PairImmutables,
    IUniswapV3PairEvents,
    IUniswapV3PairActions,
    IUniswapV3PairState,
    IUniswapV3PairDerivedState
{}
