// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

/// @title Pair state that can change
/// @notice These methods compose the pair's state, and can change with any frequency including multiple times
/// per transaction
interface IUniswapV3PairState {
    /// @notice The 0th storage slot in the pair stores many values, and is exposed as a single method to save gas
    /// when accessed externally.
    /// @return sqrtPriceX96 The current price of the pair as a sqrt(token1/token0) Q64.96 value
    /// tick The current tick of the pair, i.e. according to the last tick transition that was run.
    /// This value may not always be equal to SqrtTickMath.getTickAtSqrtRatio(sqrtPriceX96) if the price is on a tick
    /// boundary.
    /// observationIndex The index of the last oracle observation that was written,
    /// observationCardinality The current maximum number of observations stored in the pair,
    /// observationCardinalityNext The next maximum number of observations, to be updated when the observation,
    /// index The last element of the observation array,
    /// feeProtocol The fees collected by the protocol for the pair,
    /// unlocked Whether the pair is currently locked to reentrancy
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        );

    /// @notice The fee growth as a Q128.128 fees of token0 collected per unit of liquidity for the entire life of the pair
    /// @dev This value can overflow the uint256
    function feeGrowthGlobal0X128() external view returns (uint256);

    /// @notice The fee growth as a Q128.128 fees of token1 collected per unit of liquidity for the entire life of the pair
    /// @dev This value can overflow the uint256
    function feeGrowthGlobal1X128() external view returns (uint256);

    /// @notice The amounts of token0 and token1 that are owed to the protocol
    /// @dev Protocol fees will never exceed uint128 max in either token
    function protocolFees() external view returns (uint128 token0, uint128 token1);

    /// @notice The currently in range liquidity available to the pair
    /// @dev This value has no relationship to the total liquidity across all ticks
    function liquidity() external view returns (uint128);

    /// @notice Look up information about a specific tick in the pair
    /// @param tick The tick to look up
    /// @return liquidityGross the total amount of position liquidity that uses the pair either as tick lower or
    /// tick upper,
    /// liquidityNet how much liquidity changes when the pair price crosses the tick,
    /// feeGrowthOutside0X128 the fee growth on the other side of the tick from the current tick in token0,
    /// feeGrowthOutside1X128 the fee growth on the other side of the tick from the current tick in token1,
    /// feeGrowthOutsideX128 values can only be used if the tick is initialized,
    /// i.e. if liquidityGross is greater than 0. In addition, these values are only relative and are used to
    /// compute snapshots.
    function ticks(int24 tick)
        external
        view
        returns (
            uint128 liquidityGross,
            int128 liquidityNet,
            uint256 feeGrowthOutside0X128,
            uint256 feeGrowthOutside1X128
        );

    /// @notice Returns 256 packed tick initialized boolean values
    /// @param wordPosition the index of the word in the bitmap to fetch. The initialized booleans are packed into words
    /// based on the tick and the pair's tick spacing
    function tickBitmap(int16 wordPosition) external view returns (uint256);

    /// @notice Returns 8 packed tick seconds outside values
    /// @param wordPosition The index of the word in the map to fetch. The seconds outside 32 bit values are packed into
    /// words based on the tick and the pair's tick spacing
    function secondsOutside(int24 wordPosition) external view returns (uint256);

    /// @notice Returns the information about a position by the position's key
    /// @param key The position's key is a hash of a preimage composed by the owner, tickLower and tickUpper
    /// @return _liquidity The amount of liquidity in the position,
    /// Returns feeGrowthInside0LastX128 fee growth of token0 inside the tick range as of the last mint/burn/poke,
    /// Returns feeGrowthInside1LastX128 fee growth of token1 inside the tick range as of the last mint/burn/poke,
    /// Returns feesOwed0 the computed amount of token0 owed to the position as of the last mint/burn/poke,
    /// Returns feesOwed1 the computed amount of token1 owed to the position as of the last mint/burn/poke
    function positions(bytes32 key)
        external
        view
        returns (
            uint128 _liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 feesOwed0,
            uint128 feesOwed1
        );

    /// @notice Returns data about a specific observation index
    /// @param index The element of the observations array to fetch
    /// @dev You most likely want to use #observe() instead of this method to get an observation as of some amount of time
    /// ago, rather than at a specific index in the array.
    /// @return blockTimestamp The timestamp of the observation,
    /// Returns tickCumulative the current tick multiplied by seconds elapsed for the life of the pair as of the
    /// observation,
    /// Returns liquidityCumulative the current liquidity multiplied by seconds elapsed for the life of the pair as of
    /// the observation,
    /// Returns initialized whether the observation has been initialized and the values are safe to use
    function observations(uint256 index)
        external
        view
        returns (
            uint32 blockTimestamp,
            int56 tickCumulative,
            uint160 liquidityCumulative,
            bool initialized
        );
}
