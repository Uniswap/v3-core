// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;
pragma experimental ABIEncoderV2;

/// @title the Uniswap V3 Pair Interface.
interface IUniswapV3Pair {
    event Initialized(uint256 price);

    // event PositionSet(address owner, int24 tickLower, int24 tickUpper, uint8 feeVote, int112 liquidityDelta);

    // immutables
    /// @notice Gets the address of the factory contract.
    /// @dev This variable is immutable.
    function factory() external pure returns (address);

    /// @notice Gets the address of token0.
    /// @dev This variable is immutable.
    function token0() external pure returns (address);

    /// @notice Gets the address of token1.
    /// @dev This variable is immutable.
    function token1() external pure returns (address);

    /// @notice Gets the fee for the given pair.
    /// @dev This variable is immutable.
    function fee() external pure returns (uint24);

    function tickSpacing() external pure returns (int24);

    function MIN_TICK() external pure returns (int24);

    function MAX_TICK() external pure returns (int24);

    // variables/state
    /// @dev Gets the destination address of the pair fees.
    function feeTo() external view returns (address);

    /// @dev Gets the last time since the oracle price accumulator updated.
    function blockTimestampLast() external view returns (uint32);

    function liquidityCumulativeLast() external view returns (uint160);

    function tickCumulativeLast() external view returns (int56);

    /// @dev Gets current amount of liquidity of a given pair.
    function liquidityCurrent() external view returns (uint128);

    // TODO clarify
    /// @dev Gets the tick bit map 
    function tickBitmap(int16) external view returns (uint256);

    /// @dev Gets the current price of the pair.
    function priceCurrent() external view returns (uint256);

    /// @dev Gets the current fee growth global of token 0. Note this is not enough to calculated fees due. This number is part of the calculation process to find how many fees are due, per liquidity provision, in a given tick.
    function feeGrowthGlobal0() external view returns (uint256);

    /// @dev Gets the current fee growth global of token 1. Note this is not enough to calculated fees due. This number is part of the calculation process to find how many fees are due, per liquidity provision, in a given tick.
    function feeGrowthGlobal1() external view returns (uint256);

    /// @dev Gets the accumulated protocol fees of token 0.
    function feeToFees0() external view returns (uint256);

    /// @dev Gets the accumulated protocol fees of token 1.
    function feeToFees1() external view returns (uint256);

    /// @notice Check for one-time initialization.
    /// @return bool determining if there is already a price, thus already an initialized pair.
    function isInitialized() external view returns (bool);

    function tickCurrent() external view returns (int24);

    function getCumulatives()
        external
        view
        returns (
            uint32 blockTimestamp,
            uint160 liquidityCumulative,
            int56 tickCumulative
        );

    /// @notice Initializes a new pair.
    /// @param price The nearest tick to the estimated price, given the ratio of token0 / token1.
    function initialize(uint256 price) external;

    /// @notice Sets the position of a given liquidity provision.
    /// @param  tickLower The lower boundary of the position.
    /// @param tickUpper The upper boundary of the position.
    /// @param liquidityDelta The liquidity delta. (TODO what is it).
    /// @return amount0 The amount of the first token.
    /// @return amount1 The amount of the second token.
    function setPosition(
        int24 tickLower,
        int24 tickUpper,
        int128 liquidityDelta
    ) external returns (int256 amount0, int256 amount1);

    /// @notice The first main swap function.
    /// @notice Used when moving from right to left (token 1 is becoming more valuable).
    /// @param amount0In Amount of token you are sending.
    /// @param to The destination address of the tokens.
    /// @param data The call data of the swap.
    function swap0For1(
        uint256 amount0In,
        address to,
        bytes calldata data
    ) external returns (uint256 amount1Out);

    /// @notice The second main swap function.
    /// @notice Used when moving from left to right (token 0 is becoming more valuable).
    /// @param amount1In amount of token you are sending.
    /// @param to The destination address of the tokens.
    /// @param data The call data of the swap.
    function swap1For0(
        uint256 amount1In,
        address to,
        bytes calldata data
    ) external returns (uint256 amount0Out);

    function setFeeTo(address) external;

    /// @notice Allows factory contract owner to recover tokens, other than token0 and token1, accidentally sent to the pair contract.
    /// @param token The token address.
    /// @param to The destination address of the transfer.
    /// @param amount The amount of the token to be recovered.
    function recover(
        address token,
        address to,
        uint256 amount
    ) external;
}
