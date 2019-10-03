pragma solidity ^0.5.11;
import './ERC20.sol';
import './Math.sol';
import './interfaces/IERC20.sol';

contract UniswapERC20 is ERC20 {
  using SafeMath for uint256;

  event Swap(address inputToken, address buyer, address recipient, uint256 amountSold, uint256 amountBought);
  event AddLiquidity(address indexed provider, uint256 amountTokenA, uint256 amountTokenB);
  event RemoveLiquidity(address indexed provider, uint256 amountTokenA, uint256 amountTokenB);

  struct TokenData {
    uint128 reserve;                    // cached reserve for this token
    uint128 accumulator;                // accumulated TWAP value (TODO)
  }

  struct LastUpdate {
    uint128 time;
    uint128 blockNumber;
  }

  // ERC20 Data
  string public constant name = 'Uniswap V2';
  string public constant symbol = 'UNI-V2';
  uint256 public constant decimals = 18;

  address public tokenA;                // ERC20 token traded on this contract
  address public tokenB;                // ERC20 token traded on this contract
  address public factory;               // factory that created this contract

  mapping (address => TokenData) public dataForToken; // cached information about the token

  LastUpdate public lastUpdate;         // information about the last time the reserves were updated

  bool private reentrancyLock = false;

  modifier nonReentrant() {
    require(!reentrancyLock, "REENTRANCY_FORBIDDEN");
    reentrancyLock = true;
    _;
    reentrancyLock = false;
  }


  constructor(address _tokenA, address _tokenB) public {
    require(address(_tokenA) != address(0) && _tokenB != address(0), 'INVALID_ADDRESS');
    factory = msg.sender;
    tokenA = _tokenA;
    tokenB = _tokenB;
  }


  function () external {}

  function getInputPrice(uint256 inputAmount, uint256 inputReserve, uint256 outputReserve) internal pure returns (uint256) {
    require(inputReserve > 0 && outputReserve > 0, 'INVALID_VALUE');
    uint256 inputAmountWithFee = inputAmount.mul(997);
    uint256 numerator = inputAmountWithFee.mul(outputReserve);
    uint256 denominator = inputReserve.mul(1000).add(inputAmountWithFee);
    return numerator / denominator;
  }
  
  function updateData(
      address firstToken,
      address secondToken,
      TokenData memory oldFirstTokenData,
      TokenData memory oldSecondTokenData,
      uint128 newFirstTokenReserve,
      uint128 newSecondTokenReserve
    ) internal returns (uint128, uint128) {
      uint128 diff = uint128(block.number) - lastUpdate.blockNumber;
      dataForToken[firstToken] = TokenData({
          reserve: newFirstTokenReserve,
          accumulator: diff * oldFirstTokenData.reserve + oldFirstTokenData.accumulator
      });
      dataForToken[secondToken] = TokenData({
          reserve: newSecondTokenReserve,
          accumulator: diff * oldSecondTokenData.reserve + oldSecondTokenData.accumulator
      });
      if (diff != 0) {
        lastUpdate = LastUpdate({
          blockNumber: uint128(block.number),
          time: uint128(block.timestamp)
        });
      }
  }


  function swap(address inputToken, address recipient) public returns (uint256) {
    
    address outputToken;
    if (inputToken == tokenA) {
      outputToken = tokenB;
    } else {
      require(inputToken == tokenB, "INVALID_TOKEN");
      outputToken = tokenA;
    }

    TokenData memory inputTokenData = dataForToken[inputToken];
    TokenData memory outputTokenData = dataForToken[outputToken];

    uint256 newInputReserve = IERC20(inputToken).balanceOf(address(this));
    uint256 oldInputReserve = uint256(inputTokenData.reserve);
    uint256 currentOutputReserve = IERC20(outputToken).balanceOf(address(this));
    uint256 amountSold = newInputReserve - oldInputReserve;
    uint256 amountBought = getInputPrice(amountSold, oldInputReserve, currentOutputReserve);
    require(IERC20(outputToken).transfer(recipient, amountBought), "TRANSFER_FAILED");
    uint256 newOutputReserve = currentOutputReserve - amountBought;

    updateData(inputToken, outputToken, inputTokenData, outputTokenData, uint128(newInputReserve), uint128(newOutputReserve));

    emit Swap(inputToken, msg.sender, recipient, amountSold, amountBought);

    return amountBought;
  }

  function addLiquidity(address recipient) public nonReentrant returns (uint256) {
    uint256 _totalSupply = totalSupply;

    address _tokenA = tokenA;
    address _tokenB = tokenB;

    TokenData memory tokenAData = dataForToken[_tokenA];
    TokenData memory tokenBData = dataForToken[_tokenB];

    uint256 newReserveA = IERC20(_tokenA).balanceOf(address(this));
    uint256 newReserveB = IERC20(_tokenB).balanceOf(address(this));

    uint256 amountA = newReserveA - tokenAData.reserve;
    uint256 amountB = newReserveB - tokenBData.reserve;

    uint256 liquidityMinted;

    if (_totalSupply > 0) {
      liquidityMinted = Math.min(amountA.mul(_totalSupply).div(tokenAData.reserve), amountB.mul(_totalSupply).div(tokenBData.reserve));
    } else {
      liquidityMinted = Math.sqrt(amountA.mul(amountB));
    }
    balanceOf[recipient] = balanceOf[recipient].add(liquidityMinted);
    totalSupply = _totalSupply.add(liquidityMinted);

    updateData(_tokenA, _tokenB, tokenAData, tokenBData, uint128(newReserveA), uint128(newReserveB));

    emit AddLiquidity(msg.sender, amountA, amountB);
    emit Transfer(address(0), msg.sender, liquidityMinted);

    return liquidityMinted;
  }


  function removeLiquidity(uint256 amount, address recipient) public nonReentrant returns (uint256, uint256) {
    address _tokenA = tokenA;
    address _tokenB = tokenB;

    TokenData memory tokenAData = dataForToken[_tokenA];
    TokenData memory tokenBData = dataForToken[_tokenB];

    uint256 reserveA = IERC20(_tokenA).balanceOf(address(this));
    uint256 reserveB = IERC20(_tokenB).balanceOf(address(this));
    uint256 _totalSupply = totalSupply;
    uint256 amountA = amount.mul(reserveA) / _totalSupply;
    uint256 amountB = amount.mul(reserveB) / _totalSupply;
    balanceOf[msg.sender] = balanceOf[msg.sender].sub(amount);
    totalSupply = _totalSupply.sub(amount);
    require(IERC20(_tokenA).transfer(recipient, amountA), "TRANSFER_FAILED");
    require(IERC20(_tokenB).transfer(recipient, amountB), "TRANSFER_FAILED");

    updateData(_tokenA, _tokenB, tokenAData, tokenBData, uint128(reserveA - amountA), uint128(reserveB - amountB));

    emit RemoveLiquidity(recipient, amountA, amountB);
    emit Transfer(msg.sender, address(0), amount);
    return (amountA, amountB);
  }
}
