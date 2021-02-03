// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

/// @title The interface for the Uniswap V3 Factory
/// @notice The Uniswap V3 Factory facilitates creation of Uniswap V3 pairs and control over the protocol fees
interface IUniswapV3Factory {
    /// @notice Emitted when the owner of the factory is changed
    /// @param oldOwner the owner before the owner was changed
    /// @param newOwner the owner after the owner was changed
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);

    /// @notice Emitted when a pair is created
    /// @param token0 the first token of the pair by address sort order
    /// @param token1 the second token of the pair by address sort order
    /// @param fee the fee in pips that is collected in every swap with the pair
    /// @param tickSpacing the minimum number of ticks between initialized ticks
    /// @param pair the address of the created pair
    event PairCreated(
        address indexed token0,
        address indexed token1,
        uint24 indexed fee,
        int24 tickSpacing,
        address pair
    );

    /// @notice Emitted when a new fee amount is enabled for pair creation via the factory
    /// @param fee the fee in pips that was enabled
    /// @param tickSpacing the minimum number of ticks between initialized ticks for pairs created with the given fee
    event FeeAmountEnabled(uint24 indexed fee, int24 indexed tickSpacing);

    /// @notice Returns the current owner of the factory
    /// @dev Can be changed by the current owner via setOwner
    function owner() external view returns (address);

    /// @notice Returns the tick spacing for a given fee amount, if enabled, or 0 if not enabled
    /// @dev A fee amount can never bee removed, so this value should be hard coded or cached in the calling context
    function feeAmountTickSpacing(uint24 fee) external view returns (int24);

    /// @notice Returns the pair address for a given pair of tokens and a fee, or address 0 if it does not exist
    /// @dev tokenA and tokenB may be passed in either token0/token1 or token1/token0 order
    function getPair(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external view returns (address pair);

    /// @notice Creates a pair for the given two tokens and with the fee
    /// @param tokenA one of the two tokens in the desired pair
    /// @param tokenB the other of the two tokens in the desired pair
    /// @param fee the desired fee for the pair
    /// @dev tokenA and tokenB may be passed in either token0/token1 or token1/token0 order, tickSpacing is looked up
    /// from the fee, and the call will revert if the pair already exists or the fee is invalid or the token arguments
    /// are invalid.
    function createPair(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external returns (address pair);

    /// @notice Updates the owner of the factory. Must be called by the current owner
    /// @param _owner the new owner of the factory
    function setOwner(address _owner) external;

    /// @notice Enables a fee amount with the given tickSpacing
    /// @dev Fee amounts may never be removed once enabled
    /// @param fee the fee amount to enable, in pips (i.e. 1e-6)
    /// @param tickSpacing the spacing between ticks to be enforced for all pairs created with the given fee amount
    function enableFeeAmount(uint24 fee, int24 tickSpacing) external;
}
