pragma solidity 0.5.12;

import "./interfaces/IUniswapV2.sol";

import "./libraries/Math.sol";
import "./libraries/SafeMath128.sol";

import "./token/ERC20.sol";
import "./token/SafeTransfer.sol";

contract UniswapV2 is IUniswapV2, ERC20("Uniswap V2", "UNI-V2", 18, 0), SafeTransfer {
    using SafeMath128 for uint128;
    using SafeMath256 for uint256;

    struct TokenData {
        uint128 token0;
        uint128 token1;
    }

    address public factory;
    address public token0;
    address public token1;

    TokenData private reserves;
    TokenData private reservesCumulative;
    TokenData private reservesCumulativeOverflows;
    uint256 private blockNumberLast;

    bool private locked;
    modifier lock() {
        require(!locked, "UniswapV2: LOCKED");
        locked = true;
        _;
        locked = false;
    }

    event LiquidityMinted(
        address indexed sender, address indexed recipient, uint256 liquidity, uint128 amountToken0, uint128 amountToken1
    );
    event LiquidityBurned(
        address indexed sender, address indexed recipient, uint256 liquidity, uint128 amountToken0, uint128 amountToken1
    );
    event Swap(
        address indexed sender, address indexed recipient, address input, uint128 amountToken0, uint128 amountToken1
    );


    constructor() public {
        factory = msg.sender;
    }

    function initialize(address _token0, address _token1, uint256 chainId) external {
        require(msg.sender == factory && token0 == address(0) && token0 == token1, "UniswapV2: ALREADY_INITIALIZED");
        token0 = _token0;
        token1 = _token1;
        initialize(chainId);
    }

    function getReservesCumulativeAndOverflows() external view returns (uint128, uint128, uint128, uint128) {
        require(blockNumberLast > 0, "UniswapV2: NOT_INITIALIZED");

        TokenData memory reservesCumulativeNext;
        TokenData memory reservesCumulativeOverflowsNext;
        // replicate the logic in update
        if (block.number > blockNumberLast) {
                uint128 blocksElapsed = block.number.sub(blockNumberLast).downcast128();

            TokenData memory remaindersMul;
            TokenData memory overflowsMul;
            (remaindersMul.token0, overflowsMul.token0) = reserves.token0.omul(blocksElapsed);
            (remaindersMul.token1, overflowsMul.token1) = reserves.token1.omul(blocksElapsed);

            TokenData memory overflowsAdd;
            (reservesCumulativeNext.token0, overflowsAdd.token0) = reservesCumulative.token0.oadd(remaindersMul.token0);
            (reservesCumulativeNext.token1, overflowsAdd.token1) = reservesCumulative.token1.oadd(remaindersMul.token1);

            reservesCumulativeOverflowsNext = TokenData({
                token0: reservesCumulativeOverflows.token0.add(overflowsMul.token0.add(overflowsAdd.token0)),
                token1: reservesCumulativeOverflows.token1.add(overflowsMul.token1.add(overflowsAdd.token1))
            });
        } else {
            reservesCumulativeNext = reservesCumulative;
            reservesCumulativeOverflowsNext = reservesCumulativeOverflows;
        }

        return (
            reservesCumulativeNext.token0,
            reservesCumulativeNext.token1,
            reservesCumulativeOverflowsNext.token0,
            reservesCumulativeOverflowsNext.token1
        );
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

    function update(TokenData memory reservesNext) private {
        // if any blocks have gone by since the last time this function was called, we have to update
        if (block.number > blockNumberLast) {
            // make sure that this isn't the first time this function is being called
            if (blockNumberLast > 0) {
                uint128 blocksElapsed = block.number.sub(blockNumberLast).downcast128();

                // multiply previous reserves by elapsed blocks in an overflow-safe way
                TokenData memory remaindersMul;
                TokenData memory overflowsMul;
                (remaindersMul.token0, overflowsMul.token0) = reserves.token0.omul(blocksElapsed);
                (remaindersMul.token1, overflowsMul.token1) = reserves.token1.omul(blocksElapsed);

                // update cumulative reserves in an overflow-safe way
                TokenData memory overflowsAdd;
                (reservesCumulative.token0, overflowsAdd.token0) = reservesCumulative.token0.oadd(remaindersMul.token0);
                (reservesCumulative.token1, overflowsAdd.token1) = reservesCumulative.token1.oadd(remaindersMul.token1);

                // update cumulative reserves overflows
                reservesCumulativeOverflows = TokenData({
                    token0: reservesCumulativeOverflows.token0.add(overflowsMul.token0.add(overflowsAdd.token0)),
                    token1: reservesCumulativeOverflows.token1.add(overflowsMul.token1.add(overflowsAdd.token1))
                });
            }

            // update the last block number
            blockNumberLast = block.number;
        }

        // update reserves
        reserves = reservesNext;
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

        mint(recipient, liquidity);
        update(balances);
        emit LiquidityMinted(msg.sender, recipient, liquidity, amounts.token0, amounts.token1);
    }

    function burnLiquidity(address recipient) external lock returns (uint128 amountToken0, uint128 amountToken1) {
        uint256 liquidity = balanceOf[address(this)];

        TokenData memory amounts = TokenData({
            token0: (amountToken0 = (liquidity.mul(reserves.token0) / totalSupply).downcast128()),
            token1: (amountToken1 = (liquidity.mul(reserves.token1) / totalSupply).downcast128())
        });
        require(amounts.token0 == 0 || safeTransfer(token0, recipient, amounts.token0), "UniswapV2: TRANSFER_0_FAILED");
        require(amounts.token1 == 0 || safeTransfer(token1, recipient, amounts.token1), "UniswapV2: TRANSFER_1_FAILED");

        _burn(address(this), liquidity);
        update(TokenData({
            token0: IERC20(token0).balanceOf(address(this)).downcast128(),
            token1: IERC20(token1).balanceOf(address(this)).downcast128()
        }));
        emit LiquidityBurned(msg.sender, recipient, liquidity, amountToken0, amountToken1);
    }

    function swap(address input, address recipient) external lock returns (uint128 amountOutput) {
        uint128 balanceInput = IERC20(input).balanceOf(address(this)).downcast128();

        TokenData memory amounts;
        TokenData memory balances;
        if (input == token0) {
            uint128 amountInput = balanceInput.sub(reserves.token0);
            amounts = TokenData({
                token0: amountInput,
                token1: (amountOutput = getAmountOutput(amountInput, reserves.token0, reserves.token1))
            });
            require(amounts.token1 == 0 || safeTransfer(token1, recipient, amounts.token1), "UniswapV2: TRANSFER_1_FAILED");
            balances = TokenData({
                token0: balanceInput,
                token1: IERC20(token1).balanceOf(address(this)).downcast128()
            });
        } else {
            require(input == token1, "UniswapV2: INVALID_INPUT");
            uint128 amountInput = balanceInput.sub(reserves.token1);
            amounts = TokenData({
                token0: (amountOutput = getAmountOutput(amountInput, reserves.token1, reserves.token0)),
                token1: amountInput
            });
            require(amounts.token0 == 0 || safeTransfer(token0, recipient, amounts.token0), "UniswapV2: TRANSFER_0_FAILED");
            balances = TokenData({
                token0: IERC20(token0).balanceOf(address(this)).downcast128(),
                token1: balanceInput
            });
        }

        update(balances);
        emit Swap(msg.sender, recipient, input, amounts.token0, amounts.token1);
    }
}
