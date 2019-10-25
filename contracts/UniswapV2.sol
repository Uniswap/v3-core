// TODO overflow counter, review, fee
pragma solidity 0.5.12;

import "./interfaces/IUniswapV2.sol";
import "./interfaces/IERC20.sol";

import "./libraries/Math.sol";
import "./libraries/SafeMath.sol";

import "./token/ERC20.sol";

contract UniswapV2 is IUniswapV2, ERC20("Uniswap V2", "UNI-V2", 18, 0) {
    using Math for uint256;
    using SafeMath for uint256;

    event Swap(
        address indexed input,
        address indexed sender,
        address indexed recipient,
        uint256 amountInput,
        uint256 amountOutput
    );
    event LiquidityMinted(
        address indexed sender,
        address indexed recipient,
        uint256 liquidity,
        uint256 amountToken0,
        uint256 amountToken1
    );
    event LiquidityBurned(
        address indexed sender,
        address indexed recipient,
        uint256 liquidity,
        uint256 amountToken0,
        uint256 amountToken1
    );

    struct TokenData {
        uint128 reserve;
        uint128 accumulator;
    }

    struct LastUpdate {
        uint64 blockNumber;
        uint64 blockTimestamp; // overflows about 280 billion years after the earth's sun explodes
    }

    bool public initialized;
    bool private locked;
    
    address public factory;
    address public token0;
    address public token1;

    mapping (address => TokenData) private tokenData;
    LastUpdate private lastUpdate;

    modifier lock() {
        require(!locked, "UniswapV2: LOCKED");
        locked = true;
        _;
        locked = false;
    }

    constructor() public {
        factory = msg.sender;
    }

    function initialize(address _token0, address _token1) public {
        require(!initialized, "UniswapV2: ALREADY_INITIALIZED");
        initialized = true;

        token0 = _token0;
        token1 = _token1;
    }

    function updateData(uint256 balanceToken0, uint256 balanceToken1) private {
        require(balanceToken0 <= uint128(-1) && balanceToken1 <= uint128(-1), "UniswapV2: OVERFLOW");

        require(block.number <= uint64(-1), "UniswapV2: BLOCK_NUMBER_TOO_HIGH");
        uint64 blocksElapsed = uint64(block.number) - lastUpdate.blockNumber;

        // get token data
        TokenData storage tokenDataToken0 = tokenData[token0];
        TokenData storage tokenDataToken1 = tokenData[token1];
        // TODO does this have a gas impact because it unnecessarily triggers for the 2nd+ trades within a block?
        // update accumulators
        tokenDataToken0.accumulator += tokenDataToken0.reserve * blocksElapsed;
        tokenDataToken1.accumulator += tokenDataToken1.reserve * blocksElapsed;
        // update reserves
        tokenDataToken0.reserve = uint128(balanceToken0);
        tokenDataToken1.reserve = uint128(balanceToken1);

        if (blocksElapsed > 0) {
            require(block.timestamp <= uint64(-1), "UniswapV2: BLOCK_TIMESTAMP_TOO_HIGH");
            lastUpdate.blockNumber = uint64(block.number);
            lastUpdate.blockTimestamp = uint64(block.timestamp);
        }
    }

    // TODO merge/sync/donate function? think about the difference between over/under cases

    function getAmountOutput(
        uint256 amountInput,
        uint256 reserveInput,
        uint256 reserveOutput
    ) public pure returns (uint256 amountOutput) {
        require(reserveInput > 0 && reserveOutput > 0, "UniswapV2: INVALID_VALUE");
        uint256 amountInputWithFee = amountInput.mul(997);
        uint256 numerator = amountInputWithFee.mul(reserveOutput);
        uint256 denominator = reserveInput.mul(1000).add(amountInputWithFee);
        amountOutput = numerator.div(denominator);
    }

    function mintLiquidity(address recipient) public lock returns (uint256 liquidity) {
        // get balances
        uint256 balanceToken0 = IERC20(token0).balanceOf(address(this));
        uint256 balanceToken1 = IERC20(token1).balanceOf(address(this));

        // get reserves
        uint256 reserveToken0 = uint256(tokenData[token0].reserve);
        uint256 reserveToken1 = uint256(tokenData[token1].reserve);

        // get amounts
        uint256 amountToken0 = balanceToken0.sub(reserveToken0);
        uint256 amountToken1 = balanceToken1.sub(reserveToken1);

        if (totalSupply == 0) {
            liquidity = amountToken0.mul(amountToken1).sqrt(); // TODO think through this (enforce min amount?)
        } else {
            // TODO think about "donating" the non-min token amount somehow
            // TODO think about rounding here
            liquidity = Math.min(
                amountToken0.mul(totalSupply).div(reserveToken0),
                amountToken1.mul(totalSupply).div(reserveToken1)
            );
        }

        mint(recipient, liquidity); // TODO gas golf?
        
        updateData(balanceToken0, balanceToken1);

        emit LiquidityMinted(msg.sender, recipient, liquidity, amountToken0, amountToken1);
    }

    function burnLiquidity(
        uint256 liquidity,
        address recipient
    ) public lock returns (uint256 amountToken0, uint256 amountToken1) {
        require(liquidity > 0, "UniswapV2: ZERO_AMOUNT");

        amountToken0 = liquidity.mul(tokenData[token0].reserve).div(totalSupply);
        amountToken1 = liquidity.mul(tokenData[token1].reserve).div(totalSupply);

        burnFrom(msg.sender, liquidity); // TODO gas golf?
        require(IERC20(token0).transfer(recipient, amountToken0), "UniswapV2: TRANSFER_FAILED");
        require(IERC20(token1).transfer(recipient, amountToken1), "UniswapV2: TRANSFER_FAILED");

        // get balances
        uint256 balanceToken0 = IERC20(token0).balanceOf(address(this));
        uint256 balanceToken1 = IERC20(token1).balanceOf(address(this));
        updateData(balanceToken0, balanceToken1);

        emit LiquidityBurned(msg.sender, recipient, liquidity, amountToken0, amountToken1);
    }

    function swap(address input, address recipient) public lock returns (uint256 amountOutput) {
        require(input == token0 || input == token1, "UniswapV2: INVALID_INPUT");
        address output = input == token0 ? token1 : token0;

        // get balances
        uint256 balanceInput = IERC20(input).balanceOf(address(this));

        // get reserves
        uint256 reserveInput = uint256(tokenData[input].reserve);
        uint256 reserveOutput = uint256(tokenData[output].reserve);

        // get input amount
        uint256 amountInput = balanceInput.sub(reserveInput); // TODO think through edge cases here
        require(amountInput > 0, "UniswapV2: ZERO_AMOUNT");

        // calculate output amount and send to the recipient
        amountOutput = getAmountOutput(amountInput, reserveInput, reserveOutput);
        require(IERC20(output).transfer(recipient, amountOutput), "UniswapV2: TRANSFER_FAILED"); // TODO fallback here

        // update data
        uint256 balanceOutput = IERC20(output).balanceOf(address(this));
        input == token0 ? updateData(balanceInput, balanceOutput) : updateData(balanceOutput, balanceInput);

        emit Swap(input, msg.sender, recipient, amountInput, amountOutput);
    }
}
