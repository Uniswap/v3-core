// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

/// @title The Uniswap V3 Factory Interface.
interface IUniswapV3Factory {
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);
    event PairCreated(
        address indexed token0,
        address indexed token1,
        uint24 indexed fee,
        int24 tickSpacing,
        address pair,
        uint256 index
    );
    event FeeAmountEnabled(uint24 indexed fee, int24 indexed tickSpacing);

    /// @notice Gets the owner address of the factory contract.
    /// @return Returns the owner address.
    function owner() external view returns (address);

    /// @notice Gets the address of a given pair contract.
    /// @dev Pass the uint representing the pair address in the allPairs array.
    /// @return pair Returns the pair address.
    function allPairs(uint256) external view returns (address pair);

    /// @notice Gets length of the allPairs array.
    /// @return length of allPairs address array.
    function allPairsLength() external view returns (uint256);

    function allEnabledFeeAmounts(uint256) external view returns (uint24);

    /// @notice Gets length of allEnabledFeeOptions array.
    /// @return Length of allEnabledFeeOptions array.
    function allEnabledFeeAmountsLength() external view returns (uint256);

    function feeAmountTickSpacing(uint24 fee) external view returns (int24);

    /// @notice Gets the address of a trading pair.
    /// @param tokenA The first token of the pair.
    /// @param tokenB The second token of the pair.
    /// @param fee The fee of the pair.
    /// @return pair Returns address of the pair given the previous arguments.
    function getPair(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external view returns (address pair);

    /// @notice Deploys a new trading pair.
    /// @param tokenA the first token of the desired pair.
    /// @param tokenB the second token of the desired pair.
    /// @param fee the desired fee.
    /// @return pair Returns the address of the newly deployed pair.
    function createPair(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external returns (address pair);

    /// @notice Sets Factory contract owner to a new address.
    function setOwner(address) external;

    /// @notice enables the fee amount when a pair is deployed.
    /// @param fee The chosen fee option - passed via createPair.
    /// @param tickSpacing the distance between ticks.
    function enableFeeAmount(uint24 fee, int24 tickSpacing) external;
}
