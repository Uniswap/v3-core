// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;
pragma abicoder v2;

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

    function blockTimestampLast() external view returns (uint32);

    function tickCumulativeLast() external view returns (int56);

    function tickBitmap(int16) external view returns (uint256);

    function liquidityCurrent() external view returns (uint128);

    function sqrtPriceCurrent() external view returns (uint160);

    function feeGrowthGlobal0() external view returns (uint256);

    function feeGrowthGlobal1() external view returns (uint256);

    function feeToFees0() external view returns (uint256);

    function feeToFees1() external view returns (uint256);

    // derived state
    function isInitialized() external view returns (bool);

    function tickCurrent() external view returns (int24);

    function getCumulatives() external view returns (uint32 blockTimestamp, int56 tickCumulative);

    // initialize the pair
    function initialize(uint160 sqrtPrice) external;

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
        uint128 amount
    ) external returns (uint256 amount0, uint256 amount1);

    // burn the sender's liquidity
    function burn(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount
    ) external returns (uint256 amount0, uint256 amount1);

    // swapping
    function swapExact0For1(uint256 amount0In, address recipient) external returns (uint256 amount1Out);

    function swap0ForExact1(uint256 amount1Out, address recipient) external returns (uint256 amount0In);

    function swapExact1For0(uint256 amount1In, address recipient) external returns (uint256 amount0Out);

    function swap1ForExact0(uint256 amount0Out, address recipient) external returns (uint256 amount1In);

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
