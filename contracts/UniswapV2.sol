pragma solidity 0.5.12;

import "./interfaces/IUniswapV2.sol";

import "./libraries/Math.sol";
import "./libraries/SafeMath128.sol";
import "./libraries/UQ104x104.sol";

import "./token/ERC20.sol";
import "./token/SafeTransfer.sol";

contract UniswapV2 is IUniswapV2, ERC20("Uniswap V2", "UNI-V2", 18, 0), SafeTransfer {
    using SafeMath128 for uint128;
    using SafeMath for uint;
    using UQ104x104 for uint240;

    struct TokenData {
        uint128 token0;
        uint128 token1;
    }

    struct OracleData {
        uint240 priceAccumulated;
        uint16 blockNumberHalf;
    }

    address public factory;
    address public token0;
    address public token1;

    TokenData private reserves;
    OracleData private oracleDataToken0;
    OracleData private oracleDataToken1;

    bool private notEntered = true;
    modifier lock() {
        require(notEntered, "UniswapV2: LOCKED");
        notEntered = false;
        _;
        notEntered = true;
    }

    event LiquidityMinted(
        address indexed sender,
        address indexed recipient,
        uint amountToken0,
        uint amountToken1,
        uint128 reserveToken0,
        uint128 reserveToken1,
        uint liquidity
    );
    event LiquidityBurned(
        address indexed sender,
        address indexed recipient,
        uint amountToken0,
        uint amountToken1,
        uint128 reserveToken0,
        uint128 reserveToken1,
        uint liquidity
    );
    event Swap(
        address indexed sender,
        address indexed recipient,
        uint amountToken0,
        uint amountToken1,
        uint128 reserveToken0,
        uint128 reserveToken1,
        address input
    );


    constructor() public {
        factory = msg.sender;
    }

    function initialize(address _token0, address _token1) external {
        require(token0 == address(0) && token1 == address(0), 'UniswapV2: ALREADY_INITIALIZED');
        token0 = _token0;
        token1 = _token1;
    }

    function getReserves() external view returns (uint128, uint128) {
        return (reserves.token0, reserves.token1);
    }

    function readOraclePricesAccumulated() external view returns (uint240, uint240) {
        return (oracleDataToken0.priceAccumulated, oracleDataToken1.priceAccumulated);
    }

    function readOracleBlockNumber() public view returns (uint32) {
        return (uint32(oracleDataToken0.blockNumberHalf) << 16) + oracleDataToken1.blockNumberHalf;
    }

    function consultOracle() external view returns (uint240, uint240) {
        uint32 blockNumberLast = readOracleBlockNumber();

        require(reserves.token0 != 0 && reserves.token1 != 0, "UniswapV2: NO_LIQUIDITY");

        // replicate the logic in update
        if (block.number > blockNumberLast) {
            uint240 priceToken0 = UQ104x104.encode(reserves.token0).qdiv(reserves.token1);
            uint240 priceToken1 = UQ104x104.encode(reserves.token1).qdiv(reserves.token0);

            uint32 blocksElapsed = block.number.downcast32() - blockNumberLast;
            return (
                oracleDataToken0.priceAccumulated + priceToken0 * blocksElapsed,
                oracleDataToken1.priceAccumulated + priceToken1 * blocksElapsed
            );
        } else {
            return (
                oracleDataToken0.priceAccumulated,
                oracleDataToken1.priceAccumulated
            );
        }
    }

    // uniswap-v1 naming
    function getInputPrice(uint inputAmount, uint inputReserve, uint outputReserve) public pure returns (uint) {
        require(inputReserve > 0 && outputReserve > 0, "UniswapV2: INVALID_VALUE");
        uint amountInputWithFee = inputAmount.mul(997);
        uint numerator = amountInputWithFee.mul(outputReserve);
        uint denominator = inputReserve.mul(1000).add(amountInputWithFee);
        return numerator / denominator;
    }

    function update(uint balanceToken0, uint balanceToken1) private {
        uint32 blockNumberLast = readOracleBlockNumber();

        // if any blocks have gone by since the last time this function was called, we have to update
        if (block.number > blockNumberLast) {
            // we have to ensure that neither reserves are 0, else our price division fails
            if (reserves.token0 != 0 && reserves.token1 != 0) {
                // get the prices according to the reserves as of the last official interaction with the contract
                uint240 priceToken0 = UQ104x104.encode(reserves.token0).qdiv(reserves.token1);
                uint240 priceToken1 = UQ104x104.encode(reserves.token1).qdiv(reserves.token0);

                // multiply these prices by the number of elapsed blocks and add to the accumulators
                uint32 blocksElapsed = block.number.downcast32() - blockNumberLast;
                oracleDataToken0.priceAccumulated += priceToken0 * blocksElapsed;
                oracleDataToken1.priceAccumulated += priceToken1 * blocksElapsed;
            }

            // update the last block number
            oracleDataToken0.blockNumberHalf = uint16(block.number >> 16);
            oracleDataToken1.blockNumberHalf = uint16(block.number);
        }

        // update reserves
        reserves = TokenData({
            token0: balanceToken0.clamp128(),
            token1: balanceToken1.clamp128()
        });
    }

    function mintLiquidity(address recipient) external lock returns (uint liquidity) {
        uint balanceToken0 = IERC20(token0).balanceOf(address(this));
        uint balanceToken1 = IERC20(token1).balanceOf(address(this));
        uint amountToken0 = balanceToken0.sub(reserves.token0);
        uint amountToken1 = balanceToken1.sub(reserves.token1);

        liquidity = totalSupply == 0 ?
            Math.sqrt(amountToken0.mul(amountToken1)) :
            Math.min(amountToken0.mul(totalSupply) / reserves.token0, amountToken1.mul(totalSupply) / reserves.token1);
        require(liquidity > 0, "UniswapV2: INSUFFICIENT_VALUE");
        mint(recipient, liquidity);

        update(balanceToken0, balanceToken1);
        emit LiquidityMinted(
            msg.sender, recipient, amountToken0, amountToken1, reserves.token0, reserves.token1, liquidity
        );
    }

    function burnLiquidity(address recipient) external lock returns (uint amountToken0, uint amountToken1) {
        uint liquidity = balanceOf[address(this)];
        require(liquidity > 0, "UniswapV2: INSUFFICIENT_VALUE");

        amountToken0 = liquidity.mul(reserves.token0) / totalSupply;
        amountToken1 = liquidity.mul(reserves.token1) / totalSupply;
        require(amountToken0 > 0 && amountToken1 > 0, "UniswapV2: INSUFFICIENT_VALUE");
        safeTransfer(token0, recipient, amountToken0);
        safeTransfer(token1, recipient, amountToken1);

        update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)));
        emit LiquidityBurned(
            msg.sender, recipient, amountToken0, amountToken1, reserves.token0, reserves.token1, liquidity
        );
    }

    function rageQuitToken0(address recipient) external lock returns (uint amountToken1) {
        uint liquidity = balanceOf[address(this)];
        require(liquidity > 0, "UniswapV2: INSUFFICIENT_VALUE");

        amountToken1 = liquidity.mul(reserves.token1) / totalSupply;
        require(amountToken1 > 0, "UniswapV2: INSUFFICIENT_VALUE");
        safeTransfer(token1, recipient, amountToken1);

        update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)));
        emit LiquidityBurned(msg.sender, recipient, 0, amountToken1, reserves.token0, reserves.token1, liquidity);
    }

    function rageQuitToken1(address recipient) external lock returns (uint amountToken0) {
        uint liquidity = balanceOf[address(this)];
        require(liquidity > 0, "UniswapV2: INSUFFICIENT_VALUE");

        amountToken0 = liquidity.mul(reserves.token0) / totalSupply;
        require(amountToken0 > 0, "UniswapV2: INSUFFICIENT_VALUE");
        safeTransfer(token0, recipient, amountToken0);

        update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)));
        emit LiquidityBurned(msg.sender, recipient, amountToken0, 0, reserves.token0, reserves.token1, liquidity);
    }

    function swapToken0(address recipient) external lock returns (uint amountToken1) {
        uint balanceToken0 = IERC20(token0).balanceOf(address(this));
        uint amountToken0 = balanceToken0.sub(reserves.token0); // this can fail
        require(amountToken0 > 0, "UniswapV2: INSUFFICIENT_VALUE_INPUT");

        amountToken1 = getInputPrice(amountToken0, reserves.token0, reserves.token1);
        require(amountToken1 > 0, "UniswapV2: INSUFFICIENT_VALUE_OUTPUT");
        safeTransfer(token1, recipient, amountToken1);

        update(balanceToken0, IERC20(token1).balanceOf(address(this)));
        emit Swap(msg.sender, recipient, amountToken0, amountToken1, reserves.token0, reserves.token1, token0);
    }

    function swapToken1(address recipient) external lock returns (uint amountToken0) {
        uint balanceToken1 = IERC20(token1).balanceOf(address(this));
        uint amountToken1 = balanceToken1.sub(reserves.token1); // this can fail
        require(amountToken1 > 0, "UniswapV2: INSUFFICIENT_VALUE_INPUT");

        amountToken0 = getInputPrice(amountToken1, reserves.token1, reserves.token0);
        require(amountToken0 > 0, "UniswapV2: INSUFFICIENT_VALUE_OUTPUT");
        safeTransfer(token0, recipient, amountToken0);

        update(IERC20(token0).balanceOf(address(this)), balanceToken1);
        emit Swap(msg.sender, recipient, amountToken0, amountToken1, reserves.token0, reserves.token1, token1);
    }

    function sync() external {
        update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)));
    }
}
