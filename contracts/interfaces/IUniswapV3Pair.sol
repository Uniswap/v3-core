// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

interface IUniswapV3Pair {
    event Initialized(uint160 sqrtPrice, int24 tick);
    event Mint(
        address indexed owner,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        address payer,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );
    event Collect(
        address indexed owner,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        address recipient,
        uint256 amount0,
        uint256 amount1
    );
    event Burn(
        address indexed owner,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        address recipient,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );
    event Swap(
        address indexed payer,
        address indexed recipient,
        int256 amount0,
        int256 amount1,
        uint160 sqrtPrice,
        int24 tick
    );
    event FeeProtocolChanged(uint8 indexed feeProtocolOld, uint8 indexed feeProtocolNew);
    event CollectProtocol(address indexed recipient, uint256 amount0, uint256 amount1);

    // immutables
    function factory() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function fee() external view returns (uint24);

    function tickSpacing() external view returns (int24);

    function minTick() external view returns (int24);

    function maxTick() external view returns (int24);

    function maxLiquidityPerTick() external view returns (uint128);

    // variables/state
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint8 feeProtocol,
            bool unlocked
        );

    function liquidity() external view returns (uint128);

    function scry(uint32 secondsAgo) external view returns (int56 tickCumulative, uint160 liquidityCumulative);

    function observations(uint256)
        external
        view
        returns (
            uint32 blockTimestamp,
            int56 tickCumulative,
            uint160 liquidityCumulative,
            bool initialized
        );

    function tickBitmap(int16) external view returns (uint256);

    function feeGrowthGlobal0X128() external view returns (uint256);

    function feeGrowthGlobal1X128() external view returns (uint256);

    function protocolFees0() external view returns (uint256);

    function protocolFees1() external view returns (uint256);

    // initialize the pair
    function initialize(uint160 sqrtPriceX96) external;

    // mint some liquidity to an address
    function mint(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount,
        bytes calldata data
    ) external;

    // collect fees
    function collect(
        int24 tickLower,
        int24 tickUpper,
        address recipient,
        uint256 amount0Requested,
        uint256 amount1Requested
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

    function setFeeProtocol(uint8) external;

    // allows factory owner to collect protocol fees
    function collectProtocol(
        address recipient,
        uint256 amount0Requested,
        uint256 amount1Requested
    ) external returns (uint256 amount0, uint256 amount1);
}
