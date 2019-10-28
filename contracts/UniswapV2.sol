pragma solidity 0.5.12;

import "./interfaces/IUniswapV2.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IIncompatibleERC20.sol";

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

    function initialize(address _token0, address _token1, uint256 chainId) public {
        require(token0 == address(0) && token1 == address(0), "UniswapV2: ALREADY_INITIALIZED");
        token0 = _token0;
        token1 = _token1;
        initialize(chainId);
    }

    // https://medium.com/coinmonks/missing-return-value-bug-at-least-130-tokens-affected-d67bf08521ca
	function safeTransfer(address token, address to, uint value) private returns (bool result) {
		IIncompatibleERC20(token).transfer(to, value);
		
		assembly {
			switch returndatasize()   
				case 0 {
					result := not(0)
                }
				case 32 {
                    returndatacopy(0, 0, 32)
                    result := mload(0)
                }
				default {
					revert(0, 0)
				}
        }
    }

    function updateData(uint256 reserveToken0, uint256 reserveToken1) private {
        uint64 blockNumber = (block.number).downcastTo64();
        uint64 blocksElapsed = blockNumber - lastUpdate.blockNumber;

        // get token data
        TokenData storage tokenDataToken0 = tokenData[token0];
        TokenData storage tokenDataToken1 = tokenData[token1];

        if (blocksElapsed > 0) {
            // TODO do edge case math here
            // update accumulators
            tokenDataToken0.accumulator += tokenDataToken0.reserve * blocksElapsed;
            tokenDataToken1.accumulator += tokenDataToken1.reserve * blocksElapsed;

            // update last update
            lastUpdate.blockNumber = blockNumber;
            lastUpdate.blockTimestamp = (block.timestamp).downcastTo64();
        }

        tokenDataToken0.reserve = reserveToken0.downcastTo128();
        tokenDataToken1.reserve = reserveToken1.downcastTo128();
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

        // TODO think about what happens if this fails
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

        burn(liquidity); // TODO gas golf?
        require(safeTransfer(token0, recipient, amountToken0), "UniswapV2: TRANSFER_FAILED");
        require(safeTransfer(token1, recipient, amountToken1), "UniswapV2: TRANSFER_FAILED");

        // get balances
        uint256 balanceToken0 = IERC20(token0).balanceOf(address(this));
        uint256 balanceToken1 = IERC20(token1).balanceOf(address(this));
        updateData(balanceToken0, balanceToken1);

        emit LiquidityBurned(msg.sender, recipient, liquidity, amountToken0, amountToken1);
    }

    function swap(address input, address recipient) public lock returns (uint256 amountOutput) {
        require(input == token0 || input == token1, "UniswapV2: INVALID_INPUT");
        address output = input == token0 ? token1 : token0;

        // get input balance
        uint256 balanceInput = IERC20(input).balanceOf(address(this));

        // get reserves
        uint256 reserveInput = uint256(tokenData[input].reserve);
        uint256 reserveOutput = uint256(tokenData[output].reserve);

        // TODO think about what happens if this fails
        // get input amount
        uint256 amountInput = balanceInput.sub(reserveInput);
        require(amountInput > 0, "UniswapV2: ZERO_AMOUNT");

        // calculate output amount and send to the recipient
        amountOutput = getAmountOutput(amountInput, reserveInput, reserveOutput);
        require(safeTransfer(output, recipient, amountOutput), "UniswapV2: TRANSFER_FAILED");

        // update data
        // TODO re-fetch input balance here?
        uint256 balanceOutput = IERC20(output).balanceOf(address(this));
        input == token0 ? updateData(balanceInput, balanceOutput) : updateData(balanceOutput, balanceInput);

        emit Swap(input, msg.sender, recipient, amountInput, amountOutput);
    }
}
