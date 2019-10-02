pragma solidity ^0.5.11;
import './ERC20.sol';
import './Math.sol';
import './interfaces/IERC20.sol';

contract UniswapERC20 is ERC20 {
  using SafeMath for uint256;

  event SwapAForB(address indexed buyer, uint256 amountSold, uint256 amountBought);
  event SwapBForA(address indexed buyer, uint256 amountSold, uint256 amountBought);
  event AddLiquidity(address indexed provider, uint256 amountTokenA, uint256 amountTokenB);
  event RemoveLiquidity(address indexed provider, uint256 amountTokenA, uint256 amountTokenB);

  struct TokenData {
    uint128 reserve;                    // cached reserve for this token
    uint128 accumulator;                // accumulated TWAP value (TODO)
  }

  // ERC20 Data
  string public constant name = 'Uniswap V2';
  string public constant symbol = 'UNI-V2';
  uint256 public constant decimals = 18;

  address public tokenA;                // ERC20 token traded on this contract
  address public tokenB;                // ERC20 token traded on this contract
  address public factory;               // factory that created this contract

  mapping (address => TokenData) public dataForToken;

  bool private rentrancyLock = false;

  modifier nonReentrant() {
    require(!rentrancyLock);
    rentrancyLock = true;
    _;
    rentrancyLock = false;
  }


  constructor(address _tokenA, address _tokenB) public {
    require(address(_tokenA) != address(0) && _tokenB != address(0), 'INVALID_ADDRESS');
    factory = msg.sender;
    tokenA = _tokenA;
    tokenB = _tokenB;
  }


  function () external {}


  function getInputPrice(uint256 inputAmount, uint256 inputReserve, uint256 outputReserve) public pure returns (uint256) {
    require(inputReserve > 0 && outputReserve > 0, 'INVALID_VALUE');
    uint256 inputAmountWithFee = inputAmount.mul(997);
    uint256 numerator = inputAmountWithFee.mul(outputReserve);
    uint256 denominator = inputReserve.mul(1000).add(inputAmountWithFee);
    return numerator / denominator;
  }

  function swap(address inputToken, address outputToken, address recipient) internal returns (uint256, uint256) {
    TokenData memory inputTokenData = dataForToken[inputToken];
    TokenData memory outputTokenData = dataForToken[outputToken];

    uint256 newInputReserve = IERC20(inputToken).balanceOf(address(this));
    uint256 oldInputReserve = uint256(inputTokenData.reserve);
    uint256 currentOutputReserve = IERC20(outputToken).balanceOf(address(this));
    uint256 amountSold = newInputReserve - oldInputReserve;
    uint256 amountBought = getInputPrice(amountSold, oldInputReserve, currentOutputReserve);
    require(IERC20(outputToken).transfer(recipient, amountBought), "TRANSFER_FAILED");
    uint256 newOutputReserve = currentOutputReserve - amountBought;

    dataForToken[inputToken] = TokenData({
      reserve: uint128(newInputReserve),
      accumulator: inputTokenData.accumulator // TODO: update accumulator value
    });
    dataForToken[outputToken] = TokenData({
      reserve: uint128(newOutputReserve),
      accumulator: outputTokenData.accumulator // TODO: update accumulator value
    });

    return (amountSold, amountBought);
  }

  //TO: DO msg.sender is wrapper
  function swapAForB(address recipient) public nonReentrant returns (uint256) {
      (uint256 amountSold, uint256 amountBought) = swap(tokenA, tokenB, recipient);
      emit SwapAForB(msg.sender, amountSold, amountBought);
      return amountBought;
  }

  //TO: DO msg.sender is wrapper
  function swapBForA(address recipient) public nonReentrant returns (uint256) {
      (uint256 amountSold, uint256 amountBought) = swap(tokenB, tokenA, recipient);
      emit SwapBForA(msg.sender, amountSold, amountBought);
      return amountBought;
  }

  function addLiquidity() public nonReentrant returns (uint256) {
    uint256 _totalSupply = totalSupply;

    address _tokenA = tokenA;
    address _tokenB = tokenB;

    TokenData memory tokenAData = dataForToken[_tokenA];
    TokenData memory tokenBData = dataForToken[_tokenB];

    uint256 oldReserveA = uint256(tokenAData.reserve);
    uint256 oldReserveB = uint256(tokenBData.reserve);

    uint256 newReserveA = IERC20(_tokenA).balanceOf(address(this));
    uint256 newReserveB = IERC20(_tokenB).balanceOf(address(this));

    uint256 amountA = newReserveA - oldReserveA;
    uint256 amountB = newReserveB - oldReserveB;

    require(amountA > 0, "INVALID_AMOUNT_A");
    require(amountB > 0, "INVALID_AMOUNT_B");

    uint256 liquidityMinted;

    if (_totalSupply > 0) {
      require(oldReserveA > 0, "INVALID_TOKEN_A_RESERVE");
      require(oldReserveB > 0, "INVALID_TOKEN_B_RESERVE");
      liquidityMinted = Math.min((amountA.mul(_totalSupply).div(oldReserveA)), (amountB.mul(_totalSupply).div(oldReserveB)));
    } else {
      liquidityMinted = Math.sqrt(amountA.mul(amountB));
    }
    balanceOf[msg.sender] = balanceOf[msg.sender].add(liquidityMinted);
    totalSupply = _totalSupply.add(liquidityMinted);

    dataForToken[_tokenA] = TokenData({
      reserve: uint128(newReserveA),
      accumulator: tokenAData.accumulator // TODO: accumulate
    });

    dataForToken[_tokenB] = TokenData({
      reserve: uint128(newReserveB),
      accumulator: tokenBData.accumulator // TODO: accumulate
    });

    emit AddLiquidity(msg.sender, amountA, amountB);
    emit Transfer(address(0), msg.sender, liquidityMinted);

    return liquidityMinted;
  }


  function removeLiquidity(uint256 amount) public nonReentrant returns (uint256, uint256) {
    require(amount > 0);
    address _tokenA = tokenA;
    address _tokenB = tokenB;

    TokenData memory tokenAData = dataForToken[_tokenA];
    TokenData memory tokenBData = dataForToken[_tokenB];

    uint256 reserveA = IERC20(_tokenA).balanceOf(address(this));
    uint256 reserveB = IERC20(_tokenB).balanceOf(address(this));
    uint256 _totalSupply = totalSupply;
    uint256 tokenAAmount = amount.mul(reserveA) / _totalSupply;
    uint256 tokenBAmount = amount.mul(reserveB) / _totalSupply;
    balanceOf[msg.sender] = balanceOf[msg.sender].sub(amount);
    totalSupply = _totalSupply.sub(amount);
    require(IERC20(_tokenA).transfer(msg.sender, tokenAAmount));
    require(IERC20(_tokenB).transfer(msg.sender, tokenBAmount));

    dataForToken[_tokenA] = TokenData({
      reserve: uint128(reserveA - tokenAAmount),
      accumulator: tokenAData.accumulator // TODO: accumulate
    });

    dataForToken[_tokenB] = TokenData({
      reserve: uint128(reserveB - tokenBAmount),
      accumulator: tokenBData.accumulator // TODO: accumulate
    });

    emit RemoveLiquidity(msg.sender, tokenAAmount, tokenBAmount);
    emit Transfer(msg.sender, address(0), amount);
    return (tokenAAmount, tokenBAmount);
  }
}
