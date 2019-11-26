pragma solidity 0.5.12;

import "./interfaces/IUniswapV2.sol";

import "./libraries/Math.sol";
import "./libraries/SafeMath128.sol";
import "./libraries/UQ104x104.sol";

import "./token/ERC20.sol";
import "./token/SafeTransfer.sol";

contract UniswapV2 is IUniswapV2, ERC20("Uniswap V2", "UNI-V2", 18, 0), SafeTransfer {
    using SafeMath128 for uint128;
    using SafeMath256 for uint256;
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

    OracleData public oracleDataToken0;
    OracleData public oracleDataToken1;

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
        uint128 amountToken0,
        uint128 amountToken1,
        uint128 reserveToken0,
        uint128 reserveToken1,
        uint256 liquidity
    );
    event LiquidityBurned(
        address indexed sender,
        address indexed recipient,
        uint128 amountToken0,
        uint128 amountToken1,
        uint128 reserveToken0,
        uint128 reserveToken1,
        uint256 liquidity
    );
    event Swap(
        address indexed sender,
        address indexed recipient,
        uint128 amountToken0,
        uint128 amountToken1,
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

    function getBlockNumberLast() public view returns (uint32) {
        return oracleDataToken0.blockNumberHalf + (uint32(oracleDataToken1.blockNumberHalf) << 16);
    }

    function getAccumulatedPrices() external view returns (uint256, uint256) {
        uint32 blockNumberLast = getBlockNumberLast();

        require(blockNumberLast > 0, "UniswapV2: NOT_INITIALIZED");

        // replicate the logic in update
        if (block.number > blockNumberLast) {
            uint128 blocksElapsed = (block.number - blockNumberLast).downcast128();

            // get the prices according to the reserves as of the last official interaction with the contract
            uint240 priceToken0 = UQ104x104.encode(reserves.token0).qdiv(reserves.token1);
            uint240 priceToken1 = UQ104x104.encode(reserves.token1).qdiv(reserves.token0);

            return (
                oracleDataToken0.priceAccumulated + priceToken0 * blocksElapsed,
                oracleDataToken0.priceAccumulated + priceToken1 * blocksElapsed
            );
        } else {
            return (
                oracleDataToken0.priceAccumulated,
                oracleDataToken0.priceAccumulated
            );
        }
    }


    function getAmountOutput(uint128 amountInput, uint128 reserveInput, uint128 reserveOutput)
        public pure returns (uint128 amountOutput)
    {
        require(amountInput > 0 && reserveInput > 0 && reserveOutput > 0, "UniswapV2: INVALID_VALUE");
        uint256 amountInputWithFee = uint256(amountInput).mul(1000 - 3);
        uint256 numerator = amountInputWithFee.mul(reserveOutput);
        uint256 denominator = uint256(reserveInput).mul(1000).add(amountInputWithFee);
        amountOutput = (numerator / denominator).downcast128();
    }

    function update(TokenData memory balances) private {
        uint32 blockNumberLast = getBlockNumberLast();

        // if any blocks have gone by since the last time this function was called, we have to update
        if (block.number > blockNumberLast) {
            // make sure that this isn't the first time this function is being called
            uint32 blockNumber = block.number.downcast32();
            if (blockNumberLast > 0) {
                uint32 blocksElapsed = blockNumber - blockNumberLast;

                // get the prices according to the reserves as of the last official interaction with the contract
                uint240 priceToken0 = UQ104x104.encode(reserves.token0).qdiv(reserves.token1);
                uint240 priceToken1 = UQ104x104.encode(reserves.token1).qdiv(reserves.token0);

                // multiply these prices by the number of elapsed blocks and add to the accumulators
                oracleDataToken0.priceAccumulated = oracleDataToken0.priceAccumulated + priceToken0 * blocksElapsed;
                oracleDataToken1.priceAccumulated = oracleDataToken1.priceAccumulated + priceToken1 * blocksElapsed;
            }

            // update the last block number
            oracleDataToken0.blockNumberHalf = uint16(now);
            oracleDataToken1.blockNumberHalf = uint16(uint32(now >> 16));
        }

        // update reserves
        reserves = balances;
    }

    function mintLiquidity(address recipient) external lock returns (uint256 liquidity) {
        TokenData memory balances = TokenData({
            token0: IERC20(token0).balanceOf(address(this)).downcast128(),
            token1: IERC20(token1).balanceOf(address(this)).downcast128()
        });
        TokenData memory amounts = TokenData({
            token0: balances.token0.sub(reserves.token0),
            token1: balances.token1.sub(reserves.token1)
        });

        if (totalSupply == 0) {
            liquidity = Math.sqrt(uint256(amounts.token0).mul(amounts.token1));
        } else {
            liquidity = Math.min(
                uint256(amounts.token0).mul(totalSupply) / reserves.token0,
                uint256(amounts.token1).mul(totalSupply) / reserves.token1
            );
        }

        if (liquidity > 0) mint(recipient, liquidity);
        update(balances);
        emit LiquidityMinted(
            msg.sender, recipient, amounts.token0, amounts.token1, balances.token0, balances.token1, liquidity
        );
    }

    function burnLiquidity(address recipient) external lock returns (uint128 amountToken0, uint128 amountToken1) {
        uint256 liquidity = balanceOf[address(this)];
        TokenData memory amounts = TokenData({
            token0: amountToken0 = (liquidity.mul(reserves.token0) / totalSupply).downcast128(),
            token1: amountToken1 = (liquidity.mul(reserves.token1) / totalSupply).downcast128()
        });
        if (amounts.token0 > 0) safeTransfer(token0, recipient, amounts.token0);
        if (amounts.token1 > 0) safeTransfer(token1, recipient, amounts.token1);
        if (liquidity > 0) _burn(address(this), liquidity);

        TokenData memory balances = TokenData({
            token0: IERC20(token0).balanceOf(address(this)).downcast128(),
            token1: IERC20(token1).balanceOf(address(this)).downcast128()
        });
        update(balances);
        emit LiquidityBurned(
            msg.sender, recipient, amounts.token0, amounts.token1, balances.token0, balances.token1, liquidity
        );
    }

    function rageQuit(address output, address recipient) external lock returns (uint128 amountOutput) {
        uint256 liquidity = balanceOf[address(this)];
        TokenData memory amounts;

        if (output == token0) {
            amounts.token0 = amountOutput = (liquidity.mul(reserves.token0) / totalSupply).downcast128();
            safeTransfer(token0, recipient, amounts.token0);
        } else {
            require(output == token1, "UniswapV2: INVALID_OUTPUT");
            amounts.token1 = amountOutput = (liquidity.mul(reserves.token1) / totalSupply).downcast128();
            safeTransfer(token1, recipient, amounts.token1);
        }

        if (liquidity > 0) _burn(address(this), liquidity);

        TokenData memory balances = TokenData({
            token0: IERC20(token0).balanceOf(address(this)).downcast128(),
            token1: IERC20(token1).balanceOf(address(this)).downcast128()
        });
        update(balances);
        emit LiquidityBurned(
            msg.sender, recipient, amounts.token0, amounts.token1, balances.token0, balances.token1, liquidity
        );
    }

    function swap(address input, address recipient) external lock returns (uint128 amountOutput) {
        TokenData memory balances;
        TokenData memory amounts;

        if (input == token0) {
            balances.token0 = IERC20(input).balanceOf(address(this)).downcast128();
            amounts.token0 = balances.token0.sub(reserves.token0);
            amounts.token1 = amountOutput = getAmountOutput(amounts.token0, reserves.token0, reserves.token1);
            safeTransfer(token1, recipient, amounts.token1);
            balances.token1 = IERC20(token1).balanceOf(address(this)).downcast128();
        } else {
            require(input == token1, "UniswapV2: INVALID_INPUT");
            balances.token1 = IERC20(input).balanceOf(address(this)).downcast128();
            amounts.token1 = balances.token1.sub(reserves.token1);
            amounts.token0 = amountOutput = getAmountOutput(amounts.token1, reserves.token1, reserves.token0);
            safeTransfer(token0, recipient, amounts.token0);
            balances.token0 = IERC20(token0).balanceOf(address(this)).downcast128();
        }

        update(balances);
        emit Swap(
            msg.sender, recipient, amounts.token0, amounts.token1, balances.token0, balances.token1, input
        );
    }
}
