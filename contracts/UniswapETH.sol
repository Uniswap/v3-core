pragma solidity ^0.5.11;
import './ERC20.sol';
import './interfaces/IERC20.sol';
import './interfaces/IUniswapETHFactory.sol';
import './interfaces/IUniswapETH.sol';


contract UniswapETH is ERC20 {

  event TokenPurchase(address indexed buyer, uint256 ethSold, uint256 tokensBought);
  event EthPurchase(address indexed buyer, uint256 tokensSold, uint256 ethBought);
  event AddLiquidity(address indexed provider, uint256 ethAmount, uint256 tokenAmount);
  event RemoveLiquidity(address indexed provider, uint256 ethAmount, uint256 tokenAmount);

  string public name;                   // Uniswap V2
  string public symbol;                 // UNI-V2
  uint256 public decimals;              // 18
  IERC20 token;                         // ERC20 token traded on this contract
  IUniswapFactory factory;              // factory that created this contract

  bool private rentrancyLock = false;


  modifier nonReentrant() {
    require(!rentrancyLock);
    rentrancyLock = true;
    _;
    rentrancyLock = false;
  }


  constructor(address tokenAddr) public {
    require(address(tokenAddr) != address(0), 'INVALID_ADDRESS');
    factory = IUniswapFactory(msg.sender);
    token = IERC20(tokenAddr);
    name = 'Uniswap V2';
    symbol = 'UNI-V2';
    decimals = 18;
  }


  function () external payable {}


  function getInputPrice(uint256 inputAmount, uint256 inputReserve, uint256 outputReserve) public pure returns (uint256) {
    require(inputReserve > 0 && outputReserve > 0, 'INVALID_VALUE');
    uint256 inputAmountWithFee = inputAmount.mul(997);
    uint256 numerator = inputAmountWithFee.mul(outputReserve);
    uint256 denominator = inputReserve.mul(1000).add(inputAmountWithFee);
    return numerator / denominator;
  }


  function ethToToken() public payable nonReentrant returns (uint256) {
    require(msg.value > 0);
    uint256 tokenReserve = token.balanceOf(address(this));
    uint256 tokensBought = getInputPrice(msg.value, address(this).balance.sub(msg.value), tokenReserve);
    require(token.transfer(msg.sender, tokensBought));
    emit TokenPurchase(msg.sender, msg.value, tokensBought);
    return tokensBought;
  }


  function tokenToEth(uint256 tokensSold) public nonReentrant returns (uint256) {
    require(tokensSold > 0);
    uint256 tokenReserve = token.balanceOf(address(this));
    uint256 ethBought = getInputPrice(tokensSold, tokenReserve, address(this).balance);
    msg.sender.transfer(ethBought);
    require(token.transferFrom(msg.sender, address(this), tokensSold));
    emit EthPurchase(msg.sender, tokensSold, ethBought);
    return ethBought;
  }


  function tokenAddress() public view returns (address) {
    return address(token);
  }


  function factoryAddress() public view returns (address) {
    return address(factory);
  }


  function addLiquidity(uint256 initialTokens) public payable nonReentrant returns (uint256) {
    uint256 _totalSupply = totalSupply;

    if (_totalSupply > 0) {
      require(msg.value > 0, 'INVALID_INPUT');
      uint256 ethReserve = address(this).balance.sub(msg.value);
      uint256 tokenReserve = token.balanceOf(address(this));
      uint256 tokenAmount = (msg.value.mul(tokenReserve) / ethReserve).add(1);
      uint256 liquidityMinted = msg.value.mul(_totalSupply) / ethReserve;
      balanceOf[msg.sender] = balanceOf[msg.sender].add(liquidityMinted);
      totalSupply = _totalSupply.add(liquidityMinted);
      require(token.transferFrom(msg.sender, address(this), tokenAmount));
      emit AddLiquidity(msg.sender, msg.value, tokenAmount);
      emit Transfer(address(0), msg.sender, liquidityMinted);
      return liquidityMinted;

    } else {
      require(initialTokens > 0 && msg.value >= 1000000000, 'INVALID_VALUE');
      uint256 initialLiquidity = address(this).balance;
      totalSupply = initialLiquidity;
      balanceOf[msg.sender] = initialLiquidity;
      require(token.transferFrom(msg.sender, address(this), initialTokens));
      emit AddLiquidity(msg.sender, msg.value, initialTokens);
      emit Transfer(address(0), msg.sender, initialLiquidity);
      return initialLiquidity;
    }
  }


  function removeLiquidity(uint256 amount) public nonReentrant returns (uint256, uint256) {
    uint256 _totalSupply = totalSupply;
    require(amount > 0 && _totalSupply > 0);
    uint256 tokenReserve = token.balanceOf(address(this));
    uint256 ethAmount = amount.mul(address(this).balance) / _totalSupply;
    uint256 tokenAmount = amount.mul(tokenReserve) / _totalSupply;
    balanceOf[msg.sender] = balanceOf[msg.sender].sub(amount);
    totalSupply = _totalSupply.sub(amount);
    msg.sender.transfer(ethAmount);
    require(token.transfer(msg.sender, tokenAmount));
    emit RemoveLiquidity(msg.sender, ethAmount, tokenAmount);
    emit Transfer(msg.sender, address(0), amount);
    return (ethAmount, tokenAmount);
  }
}
