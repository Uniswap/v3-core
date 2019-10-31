pragma solidity 0.5.12;

import "./interfaces/IUniswapV2.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IIncompatibleERC20.sol";

import "./libraries/Math.sol";
import "./libraries/SafeMath128.sol";
import "./libraries/SafeMath256.sol";

import "./token/ERC20.sol";

contract UniswapV2 is IUniswapV2, ERC20("Uniswap V2", "UNI-V2", 18, 0) {
    using Math for uint256;
    using SafeMath128 for uint128;
    using SafeMath256 for uint256;

    event LiquidityMinted(
        address indexed sender, address indexed recipient, uint256 liquidity, uint128 amountToken0, uint128 amountToken1
    );
    event LiquidityBurned(
        address indexed sender, address indexed recipient, uint256 liquidity, uint128 amountToken0, uint128 amountToken1
    );
    event Swap(
        address indexed sender, address indexed recipient, address input, uint128 amountInput, uint128 amountOutput
    );

    struct TokenData {
        uint128 token0;
        uint128 token1;
    }

    struct Time {
        uint64 blockNumber;
        uint64 blockTimestamp; // overflows about 280 billion years after the earth's sun explodes
    }

    bool private locked; // reentrancy lock

    address public factory;
    address public token0;
    address public token1;

    TokenData private reserves;
    TokenData private reservesCumulative;
    Time private lastUpdate;

    modifier lock() {
        require(!locked, "UniswapV2: LOCKED");
        locked = true;
        _;
        locked = false;
    }

    constructor() public {
        factory = msg.sender;
    }

    function initialize(address _token0, address _token1, uint256 chainId) external {
        require(token0 == address(0) && token1 == address(0), "UniswapV2: ALREADY_INITIALIZED");
        token0 = _token0;
        token1 = _token1;
        initialize(chainId);
    }

    // https://medium.com/coinmonks/missing-return-value-bug-at-least-130-tokens-affected-d67bf08521ca
    function safeTransfer(address token, address to, uint128 value) private returns (bool result) {
        IIncompatibleERC20(token).transfer(to, uint256(value));
        assembly {
            switch returndatasize()
                case 0 {
                    result := not(0) // for no-bool responses, treat as successful
                }
                case 32 {
                    returndatacopy(0, 0, 32)
                    result := mload(0) // for (presumably) bool responses, return whatever the function returned
                }
                default {
                    revert(0, 0) // for invalid responses, revert
                }
        }
    }

    // TODO sync/merge/donate function? think about the difference between over/under cases

    function getReserves() external view returns (uint128, uint128) {
        return (reserves.token0, reserves.token1);
    }

    function getReservesCumulative() external view returns (uint128, uint128) {
        return (reservesCumulative.token0, reservesCumulative.token1);
    }

    function getLastUpdate() external view returns (uint64, uint64) {
        return (lastUpdate.blockNumber, lastUpdate.blockTimestamp);
    }

    function updateReserves(TokenData memory reservesNext) private {
        uint64 blockNumber = block.number.downcastTo64();
        uint64 blocksElapsed = blockNumber - lastUpdate.blockNumber;

        if (blocksElapsed > 0) {
            // if this isn't the first-ever call to this function, update the accumulators
            if (lastUpdate.blockNumber != 0) {
                // TODO do edge case math here
                reservesCumulative.token0 += reserves.token0 * blocksElapsed;
                reservesCumulative.token1 += reserves.token1 * blocksElapsed;
            }

            // update last update
            lastUpdate.blockNumber = blockNumber;
            lastUpdate.blockTimestamp = block.timestamp.downcastTo64();
        }

        reserves.token0 = reservesNext.token0;
        reserves.token1 = reservesNext.token1;
    }

    function getAmountOutput(
        uint128 amountInput, uint128 reserveInput, uint128 reserveOutput
    ) public pure returns (uint128 amountOutput) {
        require(amountInput > 0 && reserveInput > 0 && reserveOutput > 0, "UniswapV2: INVALID_VALUE");
        uint256 amountInputWithFee = uint256(amountInput).mul(1000 - 3); // 30 bips for now, TODO think through this later
        uint256 numerator = amountInputWithFee.mul(uint256(reserveOutput));
        uint256 denominator = uint256(reserveInput).mul(1000).add(amountInputWithFee);
        amountOutput = numerator.div(denominator).downcastTo128();
    }

    function mintLiquidity(address recipient) external lock returns (uint256 liquidity) {
        // get balances
        TokenData memory balances = TokenData({
            token0: IERC20(token0).balanceOf(address(this)).downcastTo128(),
            token1: IERC20(token1).balanceOf(address(this)).downcastTo128()
        });

        // get amounts sent to be added as liquidity
        TokenData memory amounts = TokenData({
            token0: balances.token0.sub(reserves.token0),
            token1: balances.token1.sub(reserves.token1)
        });

        if (totalSupply == 0) {
            // TODO is this right? enforce min amount? enforce no remainder?
            liquidity = Math.sqrt(uint256(amounts.token0).mul(uint256(amounts.token1)));
        } else {
            // TODO is this right?
            // TODO "donate" or ignore the non-min token amount?
            // TODO does this round the way we want?
            liquidity = Math.min(
                uint256(amounts.token0).mul(totalSupply).div(uint256(reserves.token0)),
                uint256(amounts.token1).mul(totalSupply).div(uint256(reserves.token1))
            );
        }

        mint(recipient, liquidity); // TODO gas golf?
        updateReserves(balances);
        emit LiquidityMinted(msg.sender, recipient, liquidity, amounts.token0, amounts.token1);
    }

    function burnLiquidity(
        uint256 liquidity, address recipient
    ) external lock returns (uint128 amountToken0, uint128 amountToken1) {
        require(liquidity > 0, "UniswapV2: ZERO_AMOUNT");

        // send tokens back
         // TODO is this right?
        TokenData memory amounts = TokenData({
            token0: liquidity.mul(uint256(reserves.token0)).div(totalSupply).downcastTo128(),
            token1: liquidity.mul(uint256(reserves.token1)).div(totalSupply).downcastTo128()
        });
        (amountToken0, amountToken1) = (amounts.token0, amounts.token1);
        require(safeTransfer(token0, recipient, amounts.token0), "UniswapV2: TRANSFER_FAILED");
        require(safeTransfer(token1, recipient, amounts.token1), "UniswapV2: TRANSFER_FAILED");

        _burn(address(this), liquidity); // TODO gas golf?

        TokenData memory balances = TokenData({
            token0: IERC20(token0).balanceOf(address(this)).downcastTo128(),
            token1: IERC20(token1).balanceOf(address(this)).downcastTo128()
        });
        updateReserves(balances);
        emit LiquidityBurned(msg.sender, recipient, liquidity, amountToken0, amountToken1);
    }

    function swap(address input, address recipient) external lock returns (uint128 amountOutput) {
        uint128 inputBalance = IERC20(input).balanceOf(address(this)).downcastTo128();

        uint128 amountInput;
        TokenData memory balances;
        if (input == token0) {
            amountInput = inputBalance.sub(reserves.token0);
            amountOutput = getAmountOutput(amountInput, reserves.token0, reserves.token1);
            require(safeTransfer(token1, recipient, amountOutput), "UniswapV2: TRANSFER_FAILED");
            balances = TokenData({
                token0: inputBalance,
                token1: IERC20(token1).balanceOf(address(this)).downcastTo128()
            });
        } else {
            require(input == token1, "UniswapV2: INVALID_INPUT");

            amountInput = inputBalance.sub(reserves.token1);
            amountOutput = getAmountOutput(amountInput, reserves.token1, reserves.token0);
            require(safeTransfer(token0, recipient, amountOutput), "UniswapV2: TRANSFER_FAILED");
            balances = TokenData({
                token0: IERC20(token0).balanceOf(address(this)).downcastTo128(),
                token1: inputBalance
            });
        }

        updateReserves(balances);
        emit Swap(msg.sender, recipient, input, amountInput, amountOutput);
    }
}
