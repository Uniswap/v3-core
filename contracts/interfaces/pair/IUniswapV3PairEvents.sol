// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

/// @title Events emitted by a pair
/// @notice Contains all events emitted by the pair
interface IUniswapV3PairEvents {
    /// @notice Emitted exactly once by a pair when initialize is called on the pair for the first time
    /// @param sqrtPriceX96 The initial sqrt price of the pair, as a Q64.96
    /// @param tick The initial tick of the pair, i.e. log base 1.0001 of the starting price of the pair
    /// @dev Mint/Burn/Swap cannot be emitted by the pair before Initialize
    event Initialize(uint160 sqrtPriceX96, int24 tick);

    /// @notice Emitted when liquidity is minted for a given position
    /// @param sender The address that minted the liquidity
    /// @param owner The owner of the position and recipient of any minted liquidity
    /// @param tickLower The lower tick of the position
    /// @param tickUpper The upper tick of the position
    /// @param amount The amount of liquidity minted to the position range
    /// @param amount0 How much token0 was required for the minted liquidity
    /// @param amount1 How much token1 was required for the minted liquidity
    event Mint(
        address sender,
        address indexed owner,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );

    /// @notice Emitted when fees are collected by the owner of a position
    /// @param owner The owner of the position for which fees are collected
    /// @param tickLower The lower tick of the position
    /// @param tickUpper The upper tick of the position
    /// @param amount0 The amount of token0 fees collected
    /// @param amount1 The amount of token1 fees collected
    /// @dev Collect events may be emitted with zero amount0 and amount1
    event Collect(
        address indexed owner,
        address recipient,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        uint128 amount0,
        uint128 amount1
    );

    /// @notice Emitted when a position's liquidity is removed
    /// @param owner The owner of the position for which liquidity is removed
    /// @param recipient Address that receives the tokens withdrawn via the burned liquidity
    /// @param tickLower Lower tick of the position
    /// @param tickUpper Upper tick of the position
    /// @param amount The amount of liquidity to remove
    /// @param amount0 The amount of token0 withdrawn
    /// @param amount1 The amount of token1 withdrawn
    /// @dev Does not withdraw any fees earned by the liquidity position, which must be withdrawn via Collect
    event Burn(
        address indexed owner,
        address recipient,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );

    /// @notice Emitted by the pair for any swaps between token0 and token1
    /// @param sender Address that sent the call to swap and received the callback
    /// @param recipient Address that receives the output of the swap
    /// @param amount0 Delta of the token0 balance of the pair
    /// @param amount1 Delta of the token1 balance of the pair
    /// @param sqrtPriceX96 sqrt(price) of the pair after the swap as a Q64.96
    /// @param tick Log base 1.0001 of price of the pair after the swap
    event Swap(
        address indexed sender,
        address indexed recipient,
        int256 amount0,
        int256 amount1,
        uint160 sqrtPriceX96,
        int24 tick
    );

    /// @notice Emitted by the pair for any flashes of token0/token1
    /// @param sender Address that sent the call to flash and received the callback
    /// @param recipient Address that receives the tokens from flash
    /// @param amount0 Amount of token0 that was flashed
    /// @param amount1 Amount of token1 that was flashed
    /// @param paid0 Amount of token0 paid for the flash, which can exceed the amount0 plus the fee
    /// @param paid1 Amount of token1 paid for the flash, which can exceed the amount1 plus the fee
    event Flash(
        address indexed sender,
        address indexed recipient,
        uint256 amount0,
        uint256 amount1,
        uint256 paid0,
        uint256 paid1
    );

    /// @notice Emitted by the pair for increases to the number of observations that can be stored
    /// @param observationCardinalityNextOld The previous value of the next observation cardinality
    /// @param observationCardinalityNextNew The updated value of the next observation cardinality
    /// @dev observationCardinalityNext is not the observation cardinality until an observation is written at the index
    /// just before a mint/swap/burn
    event IncreaseObservationCardinalityNext(
        uint16 observationCardinalityNextOld,
        uint16 observationCardinalityNextNew
    );

    /// @notice Emitted when the protocol fee is changed by the pair
    /// @param feeProtocolOld The previous value of the feeProtocol state variable
    /// @param feeProtocolNew The updated value of the feeProtocol state variable
    event SetFeeProtocol(uint8 feeProtocolOld, uint8 feeProtocolNew);

    /// @notice Emitted when the collected protocol fees are withdrawn by the factory owner
    /// @param sender Address that collects the protocol fees
    /// @param recipient Address that receives the collected protocol fees
    /// @param amount0 Amount of token0 protocol fees that is withdrawn
    /// @param amount0 Amount of token1 protocol fees that is withdrawn
    event CollectProtocol(address indexed sender, address indexed recipient, uint256 amount0, uint256 amount1);
}
