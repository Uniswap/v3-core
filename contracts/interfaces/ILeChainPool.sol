// SPDX-License-Identifier:GPL-3.0-or-later
pragma solidity >=0.5.0;

import './pool/ILeChainPoolImmutables.sol';
import './pool/ILeChainPoolState.sol';
import './pool/ILeChainPoolDerivedState.sol';
import './pool/ILeChainPoolActions.sol';
import './pool/ILeChainPoolOwnerActions.sol';
import './pool/ILeChainPoolEvents.sol';

/// @title The interface for a LeChain Pool
/// @notice A LeChain pool facilitates swapping and automated market making between any two assets that strictly conform
/// to the LCP20 specification
/// @dev The pool interface is broken up into many smaller pieces
interface ILeChainPool is
    ILeChainPoolImmutables,
    ILeChainPoolState,
    ILeChainPoolDerivedState,
    ILeChainPoolActions,
    ILeChainPoolOwnerActions,
    ILeChainPoolEvents
{

}
