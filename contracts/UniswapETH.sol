pragma solidity ^0.5.11;
import './ERC20.sol';
import './interfaces/IERC20.sol';

contract UniswapETH is ERC20 {
  using SafeMath for uint256;

  event TokenPurchase(address indexed buyer, uint256 ethSold, uint256 tokensBought);
  event EthPurchase(address indexed buyer, uint256 tokensSold, uint256 ethBought);
  event AddLiquidity(address indexed provider, uint256 ethAmount, uint256 tokenAmount);
  event RemoveLiquidity(address indexed provider, uint256 ethAmount, uint256 tokenAmount);

  // ERC20 Data
  string public constant name = 'Uniswap V2';
  string public constant symbol = 'UNI-V2';
  uint256 public constant decimals = 18;

  IERC20 token;                         // ERC20 token traded on this contract
  address public factory;               // factory that created this contract
  bool private locked = false;


  // TODO: test this w/ respect to EIP2200 https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/ReentrancyGuard.sol#L20
  modifier nonReentrant() {
    require(!locked);
    locked = true;
    _;
    locked = false;
  }


  constructor(address tokenAddr) public {
    factory = msg.sender;
    token = IERC20(tokenAddr);
  }


  function () external payable {}


  function getInputPrice(uint256 inputAmount, uint256 inputReserve, uint256 outputReserve) public pure returns (uint256) {
    require(inputReserve > 0 && outputReserve > 0, 'INVALID_VALUE');
    uint256 inputAmountWithFee = inputAmount.mul(997);
    uint256 numerator = inputAmountWithFee.mul(outputReserve);
    uint256 denominator = inputReserve.mul(1000).add(inputAmountWithFee);
    return numerator / denominator;
  }


  function ethToToken(address recipient) public payable nonReentrant returns (uint256) {
    require(msg.value > 0 && recipient != address(this) && recipient != address(0), 'INVALID_INPUT');
    uint256 tokenReserve = token.balanceOf(address(this));
    uint256 tokensBought = getInputPrice(msg.value, address(this).balance.sub(msg.value), tokenReserve);
    require(token.transfer(recipient, tokensBought));
    emit TokenPurchase(msg.sender, msg.value, tokensBought);
    return tokensBought;
  }


  function tokenToEth(address payable recipient, uint256 tokensSold) public nonReentrant returns (uint256) {
    require(tokensSold > 0 && recipient != address(this) && recipient != address(0), 'INVALID_INPUT');
    uint256 tokenReserve = token.balanceOf(address(this));
    uint256 ethBought = getInputPrice(tokensSold, tokenReserve, address(this).balance);
    (bool success, ) = recipient.call.value(ethBought)('');
    require(success, 'ETH TRANSFER');
    require(token.transferFrom(msg.sender, address(this), tokensSold));
    emit EthPurchase(msg.sender, tokensSold, ethBought);
    return ethBought;
  }


  function tokenAddress() public view returns (address) {
    return address(token);
  }


  function addLiquidity(address recipient, uint256 initialTokens) public payable nonReentrant returns (uint256) {
    uint256 _totalSupply = totalSupply;

    if (_totalSupply > 0) {
      require(msg.value > 0, 'INVALID_INPUT');
      uint256 ethReserve = address(this).balance.sub(msg.value);
      uint256 tokenReserve = token.balanceOf(address(this));
      uint256 tokenAmount = (msg.value.mul(tokenReserve) / ethReserve).add(1);
      uint256 liquidityMinted = msg.value.mul(_totalSupply) / ethReserve;
      balanceOf[recipient] = balanceOf[msg.sender].add(liquidityMinted);
      totalSupply = _totalSupply.add(liquidityMinted);
      require(token.transferFrom(msg.sender, address(this), tokenAmount));
      emit AddLiquidity(recipient, msg.value, tokenAmount);
      emit Transfer(address(0), msg.sender, liquidityMinted);
      return liquidityMinted;

    } else {
      // TODO: figure out initialLiquidity
      require(initialTokens > 0 && msg.value >= 1000000000, 'INVALID_VALUE');
      uint256 initialLiquidity = address(this).balance;
      totalSupply = initialLiquidity;
      balanceOf[recipient] = initialLiquidity;
      require(token.transferFrom(msg.sender, address(this), initialTokens));
      emit AddLiquidity(recipient, msg.value, initialTokens);
      emit Transfer(address(0), recipient, initialLiquidity);
      return initialLiquidity;
    }
  }


  function removeLiquidity(address payable recipient, uint256 amount) public nonReentrant returns (uint256, uint256) {
    require(amount > 0);
    uint256 _totalSupply = totalSupply;
    uint256 tokenReserve = token.balanceOf(address(this));
    uint256 ethAmount = amount.mul(address(this).balance) / _totalSupply;
    uint256 tokenAmount = amount.mul(tokenReserve) / _totalSupply;
    balanceOf[msg.sender] = balanceOf[msg.sender].sub(amount);
    totalSupply = _totalSupply.sub(amount);
    (bool success, ) = recipient.call.value(ethAmount)('');
    require(success, 'ETH TRANSFER');
    require(token.transfer(recipient, tokenAmount));
    emit RemoveLiquidity(msg.sender, ethAmount, tokenAmount);
    emit Transfer(msg.sender, address(0), amount);
    return (ethAmount, tokenAmount);
  }


  function unsafeRemoveOnlyETH(address payable recipient, uint256 amount) public nonReentrant returns (uint256) {
    require(amount > 0);
    uint256 _totalSupply = totalSupply;
    uint256 ethAmount = amount.mul(address(this).balance) / _totalSupply;
    balanceOf[msg.sender] = balanceOf[msg.sender].sub(amount);
    totalSupply = _totalSupply.sub(amount);
    (bool success, ) = recipient.call.value(ethAmount)('');
    require(success, 'ETH TRANSFER');
    emit RemoveLiquidity(msg.sender, ethAmount, 0);
    emit Transfer(msg.sender, address(0), amount);
    return (ethAmount);
  }
}
