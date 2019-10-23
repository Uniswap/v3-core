// TODO ema oracle, review
pragma solidity 0.5.12;

import "./libraries/Math.sol";
import "./libraries/SafeMath.sol";
import "./UniswapV2Factory.sol";
import "./UniswapV2.sol";

contract UniswapV2Helper {
    using SafeMath for uint256;

    event Swap(address inputToken, address outputToken, address indexed buyer, address recipient, uint256 amountSold, uint256 amountBought);

    address factory;                  // Uniswap ERC20 factory

    constructor(address _factory) public  {
        factory = _factory;
    }

    bool private reentrancyLock = false;

    modifier nonReentrant() {
        require(!reentrancyLock, "REENTRANCY_FORBIDDEN");
        reentrancyLock = true;
        _;
        reentrancyLock = false;
    }

    function _send(
        address inputToken,
        address outputToken,
        uint256 amountSold,
        address recipient
    ) internal returns (uint256) {
        address exchange = UniswapV2Factory(factory).getExchange(inputToken, outputToken);
        require(exchange != address(0), "NO_EXCHANGE");
        if (amountSold != 0) {
        require(IERC20(inputToken).transferFrom(msg.sender, exchange, amountSold), "TRANSFER_FAILED");
        }
        return UniswapV2(exchange).swap(inputToken, recipient);
    }

    function send(
        address inputToken,
        address outputToken,
        uint256 amountSold,
        uint256 minBought,
        uint256 deadline,
        address recipient
    ) public nonReentrant returns (uint256) {
        require(block.timestamp <= deadline, "DEADLINE_PASSED");
        uint256 amountBought = _send(inputToken, outputToken, amountSold, recipient);
        require(amountBought >= minBought, "INSUFFICIENT_AMOUNT_BOUGHT");
        emit Swap(inputToken, outputToken, msg.sender, recipient, amountSold, amountBought);
        return amountBought;
    }

    function sendIndirect(
        address inputToken,
        address intermediateToken,
        address outputToken,
        uint256 amountSold,
        uint256 minBought,
        uint256 deadline,
        address recipient
    ) public nonReentrant returns (uint256) {
        require(block.timestamp <= deadline, "DEADLINE_PASSED");
        // send intermediate amount directly to the next contract
        uint256 intermediateAmountBought = _send(inputToken, intermediateToken, amountSold, outputToken);
        emit Swap(inputToken, intermediateToken, msg.sender, msg.sender, amountSold, intermediateAmountBought);
        uint256 amountBought = _send(inputToken, intermediateToken, 0, recipient);
        emit Swap(intermediateToken, outputToken, msg.sender, recipient, intermediateAmountBought, amountBought);
        require(amountBought >= minBought, "INSUFFICIENT_AMOUNT_BOUGHT");
        return amountBought;
    }

    function swap(
        address inputToken,
        address outputToken,
        uint256 amountSold,
        uint256 minBought,
        uint256 deadline
    ) public nonReentrant returns (uint256) {
        return send(inputToken, outputToken, amountSold, minBought, deadline, msg.sender);
    }

    function _addLiquidity(
        address token1,
        address token2,
        uint256 amount1,
        uint256 amount2,
        address exchange,
        address recipient
    ) public nonReentrant returns (uint256) {
        require(IERC20(token1).transferFrom(msg.sender, exchange, amount1), "TRANSFER_FAILED");
        require(IERC20(token2).transferFrom(msg.sender, exchange, amount2), "TRANSFER_FAILED");
        return UniswapV2(exchange).addLiquidity(recipient);
    }

    function addLiquidity(
        address token1,
        address token2,
        uint256 amount1,
        uint256 minBought,
        address recipient,
        uint256 deadline
    ) public nonReentrant returns (uint256) {
        require(block.timestamp <= deadline, "DEADLINE_PASSED");
        address exchange = UniswapV2Factory(factory).getExchange(token1, token2);
        require(exchange != address(0), "NO_EXCHANGE");
        (uint256 reserve1,) = UniswapV2(exchange).dataForToken(token1);
        (uint256 reserve2,) = UniswapV2(exchange).dataForToken(token2);
        uint256 amount2 = amount1.mul(reserve2).div(reserve1);
        uint256 amountBought = _addLiquidity(token1, token2, amount1, amount2, exchange, recipient);
        require(amountBought >= minBought, "INSUFFICIENT_AMOUNT_BOUGHT");
    }

    function removeLiquidity(
        address token1,
        address token2,
        uint256 amount,
        address recipient,
        uint256 deadline
    ) public nonReentrant returns (uint256, uint256) {
        require(block.timestamp <= deadline, "DEADLINE_PASSED");
        address exchange = UniswapV2Factory(factory).getExchange(token1, token2);
        require(exchange != address(0), "NO_EXCHANGE");
        return UniswapV2(exchange).removeLiquidity(amount, recipient);
    }
}
