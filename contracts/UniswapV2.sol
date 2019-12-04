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

    address public factory;
    address public token0;
    address public token1;
    uint128 public reserve0;
    uint128 public reserve1;
    uint240 public priceCumulative0;
    uint16 public blockNumberHalf0;
    uint240 public priceCumulative1;
    uint16 public blockNumberHalf1;

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
        uint amount0,
        uint amount1,
        uint128 reserve0,
        uint128 reserve,
        uint liquidity
    );
    event LiquidityBurned(
        address indexed sender,
        address indexed recipient,
        uint amount0,
        uint amount1,
        uint128 reserve0,
        uint128 reserve1,
        uint liquidity
    );
    event Swap(
        address indexed sender,
        address indexed recipient,
        uint amount0,
        uint amount1,
        uint128 reserve0,
        uint128 reserve1,
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
        return (reserve0, reserve1);
    }

    function readOracleBlockNumber() public view returns (uint32) {
        return (uint32(blockNumberHalf0) << 16) + blockNumberHalf1;
    }

    // uniswap-v1 naming
    function getInputPrice(uint inputAmount, uint inputReserve, uint outputReserve) public pure returns (uint) {
        require(inputReserve > 0 && outputReserve > 0, "UniswapV2: INVALID_VALUE");
        uint amountInputWithFee = inputAmount.mul(997);
        uint numerator = amountInputWithFee.mul(outputReserve);
        uint denominator = inputReserve.mul(1000).add(amountInputWithFee);
        return numerator / denominator;
    }

    function update(uint balance0, uint balance1) private {
        uint32 blockNumberLast = readOracleBlockNumber();

        // if any blocks have gone by since the last time this function was called, we have to update
        if (block.number > blockNumberLast) {
            // we have to ensure that neither reserves are 0, else our price division fails
            if (reserve0 != 0 && reserve1 != 0) {
                // get the prices according to the reserves as of the last official interaction with the contract
                uint240 price0 = UQ104x104.encode(reserve0).qdiv(reserve1);
                uint240 price1 = UQ104x104.encode(reserve1).qdiv(reserve0);

                // multiply these prices by the number of elapsed blocks and add to the accumulators
                uint32 blocksElapsed = block.number.downcast32() - blockNumberLast;
                priceCumulative0 += price0 * blocksElapsed;
                priceCumulative1 += price1 * blocksElapsed;
            }

            // update the last block number
            blockNumberHalf0 = uint16(block.number >> 16);
            blockNumberHalf1 = uint16(block.number);
        }

        // update reserves
        reserve0 = balance0.clamp128();
        reserve1 = balance1.clamp128();
    }

    function mintLiquidity(address recipient) external lock returns (uint liquidity) {
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));
        uint amount0 = balance0.sub(reserve0);
        uint amount1 = balance1.sub(reserve1);

        liquidity = totalSupply == 0 ?
            Math.sqrt(amount0.mul(amount1)) :
            Math.min(amount0.mul(totalSupply) / reserve0, amount1.mul(totalSupply) / reserve1);
        require(liquidity > 0, "UniswapV2: INSUFFICIENT_VALUE");
        mint(recipient, liquidity);
        update(balance0, balance1);
        emit LiquidityMinted(msg.sender, recipient, amount0, amount1, reserve0, reserve1, liquidity);
    }

    function burnLiquidity(address recipient) external lock returns (uint amount0, uint amount1) {
        uint liquidity = balanceOf[address(this)];
        require(liquidity > 0, "UniswapV2: INSUFFICIENT_VALUE");
        amount0 = liquidity.mul(reserve0) / totalSupply;
        amount1 = liquidity.mul(reserve1) / totalSupply;
        require(amount0 > 0 && amount1 > 0, "UniswapV2: INSUFFICIENT_VALUE");
        safeTransfer(token0, recipient, amount0);
        safeTransfer(token1, recipient, amount1);
        update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)));
        emit LiquidityBurned(msg.sender, recipient, amount0, amount1, reserve0, reserve1, liquidity);
    }

    function swap0(address recipient) external lock returns (uint amount1) {
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint amount0 = balance0.sub(reserve0); // this can fail
        require(amount0 > 0, "UniswapV2: INSUFFICIENT_VALUE_INPUT");
        amount1 = getInputPrice(amount0, reserve0, reserve1);
        require(amount1 > 0, "UniswapV2: INSUFFICIENT_VALUE_OUTPUT");
        safeTransfer(token1, recipient, amount1);
        update(balance0, IERC20(token1).balanceOf(address(this)));
        emit Swap(msg.sender, recipient, amount0, amount1, reserve0, reserve1, token0);
    }

    function swap1(address recipient) external lock returns (uint amount0) {
        uint balance1 = IERC20(token1).balanceOf(address(this));
        uint amount1 = balance1.sub(reserve1); // this can fail
        require(amount1 > 0, "UniswapV2: INSUFFICIENT_VALUE_INPUT");
        amount0 = getInputPrice(amount1, reserve1, reserve0);
        require(amount0 > 0, "UniswapV2: INSUFFICIENT_VALUE_OUTPUT");
        safeTransfer(token0, recipient, amount0);
        update(IERC20(token0).balanceOf(address(this)), balance1);
        emit Swap(msg.sender, recipient, amount0, amount1, reserve0, reserve1, token1);
    }

    function sync() external lock {
        update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)));
    }

    // DONT CALL THIS FUNCTION UNLESS token0 IS PERMANENTLY BROKEN // TODO: counterfactual
    function unsafeRageQuit0(address recipient) external lock returns (uint amount1) {
        uint liquidity = balanceOf[address(this)];
        require(liquidity > 0, "UniswapV2: INSUFFICIENT_VALUE");
        amount1 = liquidity.mul(reserve1) / totalSupply;
        require(amount1 > 0, "UniswapV2: INSUFFICIENT_VALUE");
        safeTransfer(token1, recipient, amount1);
        update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)));
        emit LiquidityBurned(msg.sender, recipient, 0, amount1, reserve0, reserve1, liquidity);
    }

    // DONT CALL THIS FUNCTION UNLESS token1 IS PERMANENTLY BROKEN // TODO: counterfactual
    function unsafeRageQuit1(address recipient) external lock returns (uint amount0) {
        uint liquidity = balanceOf[address(this)];
        require(liquidity > 0, "UniswapV2: INSUFFICIENT_VALUE");
        amount0 = liquidity.mul(reserve0) / totalSupply;
        require(amount0 > 0, "UniswapV2: INSUFFICIENT_VALUE");
        safeTransfer(token0, recipient, amount0);
        update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)));
        emit LiquidityBurned(msg.sender, recipient, amount0, 0, reserve0, reserve1, liquidity);
    }
}
