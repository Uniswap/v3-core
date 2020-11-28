// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

/// @title The Uniswap V3 Factory Interface.
interface IUniswapV3Factory {
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);
    event PairCreated(address indexed token0, address indexed token1, uint24 indexed fee, address pair, uint256);
    event FeeOptionEnabled(uint24 indexed fee);

    /// @return The owner address.
    function owner() external view returns (address);

    function allPairs(uint256) external view returns (address pair);

    /// @notice Gets length of allPairs array.
    /// @return length of allPairs address array.
    function allPairsLength() external view returns (uint256);

    function allEnabledFeeOptions(uint256) external view returns (uint24);

    /// @notice Gets length of allEnabledFeeOptions array.
    /// @return Length of allEnabledFeeOptions array.
    function allEnabledFeeOptionsLength() external view returns (uint256);

    /// @notice Gets the address of a trading pair.
    /// @param tokenA The first token of the pair.
    /// @param tokenB The second token of the pair.
    /// @param fee The fee of the pair.
    /// @return address of the pair given the previous arguments.
    function getPair(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external view returns (address pair);

    function isFeeOptionEnabled(uint24 fee) external view returns (bool);

    /// @notice Deploys a new trading pair.
    /// @param tokenA the first token of the desired pair.
    /// @param tokenB the second token of the desired pair.
    /// @param fee the desired fee.
    /// @return The address of the newly deployed pair.
    function createPair(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external returns (address pair);

    /// @notice Sets Factory contract owner to a new address.
    function setOwner(address) external;

    /// @notice If chosen, enables the fee option when a pair is deployed.
    /// @param fee The chosen fee option - passed via createPair.
    function enableFeeOption(uint24 fee) external;
}
