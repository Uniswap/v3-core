// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.5;

interface IUniswapV3Pair {
    event Initialized(uint160 sqrtPrice);

    // event PositionSet(address owner, int24 tickLower, int24 tickUpper, uint8 feeVote, int112 liquidityDelta);

    // immutables
    function factory() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function fee() external view returns (uint24);

    function tickSpacing() external view returns (int24);

    function MIN_TICK() external view returns (int24);

    function MAX_TICK() external view returns (int24);

    // variables/state
    function feeTo() external view returns (address);

    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceCurrent,
            uint32 blockTimestampLast,
            int56 tickCumulativeLast,
            uint8 unlockedAndPriceBit
        );

    function liquidityCurrent() external view returns (uint128);

    function tickBitmap(int16) external view returns (uint256);

    function feeGrowthGlobal0() external view returns (uint256);

    function feeGrowthGlobal1() external view returns (uint256);

    function feeToFees0() external view returns (uint256);

    function feeToFees1() external view returns (uint256);

    function tickCurrent() external view returns (int24);

    // initialize the pair
    function initialize(uint160 sqrtPrice, bytes calldata data) external;

    // collect fees
    function collectFees(
        int24 tickLower,
        int24 tickUpper,
        address recipient,
        uint256 amount0Requested,
        uint256 amount1Requested
    ) external returns (uint256 amount0, uint256 amount1);

    // mint some liquidity to an address
    function mint(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount,
        bytes calldata data
    ) external returns (uint256 amount0, uint256 amount1);

    // burn the sender's liquidity
    function burn(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount
    ) external returns (uint256 amount0, uint256 amount1);

    function swap(
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimit,
        address recipient,
        bytes calldata data
    ) external;

    function setFeeTo(address) external;

    // allows the factory owner address to recover any tokens other than token0 and token1 held by the contract
    function recover(
        address token,
        address recipient,
        uint256 amount
    ) external;

    // allows anyone to collect protocol fees to feeTo
    function collect(uint256 amount0Requested, uint256 amount1Requested)
        external
        returns (uint256 amount0, uint256 amount1);
}
