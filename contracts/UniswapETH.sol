pragma solidity ^0.5.11;
import './ERC20.sol';
import './interfaces/IERC20.sol';
import './interfaces/IUniswapETHFactory.sol';
import './interfaces/IUniswapETH.sol';


contract UniswapETH is ERC20 {

  event TokenPurchase(address indexed buyer, uint256 indexed ethSold, uint256 indexed tokensBought);
  event EthPurchase(address indexed buyer, uint256 indexed tokensSold, uint256 indexed ethBought);
  event AddLiquidity(address indexed provider, uint256 indexed ethAmount, uint256 indexed tokenAmount);
  event RemoveLiquidity(address indexed provider, uint256 indexed ethAmount, uint256 indexed tokenAmount);

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


  function () external payable {
    ethToTokenInput(msg.value, 1, block.timestamp, msg.sender, msg.sender);
  }


  function getInputPrice(uint256 inputAmount, uint256 inputReserve, uint256 outputReserve) public pure returns (uint256) {
    require(inputReserve > 0 && outputReserve > 0, 'INVALID_VALUE');
    uint256 inputAmountWithFee = inputAmount.mul(997);
    uint256 numerator = inputAmountWithFee.mul(outputReserve);
    uint256 denominator = inputReserve.mul(1000).add(inputAmountWithFee);
    return numerator / denominator;
  }


  function getOutputPrice(uint256 outputAmount, uint256 inputReserve, uint256 outputReserve) public pure returns (uint256) {
    require(inputReserve > 0 && outputReserve > 0);
    uint256 numerator = inputReserve.mul(outputAmount).mul(1000);
    uint256 denominator = (outputReserve.sub(outputAmount)).mul(997);
    return (numerator / denominator).add(1);
  }

  function ethToTokenInput(uint256 ethSold, uint256 minTokens, uint256 deadline, address buyer, address recipient) private nonReentrant returns (uint256) {
    require(deadline >= block.timestamp && ethSold > 0 && minTokens > 0);
    uint256 tokenReserve = token.balanceOf(address(this));
    uint256 tokensBought = getInputPrice(ethSold, address(this).balance.sub(ethSold), tokenReserve);
    require(tokensBought >= minTokens);
    require(token.transfer(recipient, tokensBought));
    emit TokenPurchase(buyer, ethSold, tokensBought);
    return tokensBought;
  }


  function ethToTokenSwapInput(uint256 minTokens, uint256 deadline) public payable returns (uint256) {
    return ethToTokenInput(msg.value, minTokens, deadline, msg.sender, msg.sender);
  }


  function ethToTokenTransferInput(uint256 minTokens, uint256 deadline, address recipient) public payable returns(uint256) {
    require(recipient != address(this) && recipient != address(0));
    return ethToTokenInput(msg.value, minTokens, deadline, msg.sender, recipient);
  }

  function ethToTokenOutput(uint256 tokensBought, uint256 maxEth, uint256 deadline, address payable buyer, address recipient) private nonReentrant returns (uint256) {
    require(deadline >= block.timestamp && tokensBought > 0 && maxEth > 0);
    uint256 tokenReserve = token.balanceOf(address(this));
    uint256 ethSold = getOutputPrice(tokensBought, address(this).balance.sub(maxEth), tokenReserve);
    // Throws if ethSold > maxEth
    uint256 ethRefund = maxEth.sub(ethSold);
    if (ethRefund > 0) {
      buyer.transfer(ethRefund);
    }
    require(token.transfer(recipient, tokensBought));
    emit TokenPurchase(buyer, ethSold, tokensBought);
    return ethSold;
  }


  function ethToTokenSwapOutput(uint256 tokensBought, uint256 deadline) public payable returns(uint256) {
    return ethToTokenOutput(tokensBought, msg.value, deadline, msg.sender, msg.sender);
  }


  function ethToTokenTransferOutput(uint256 tokensBought, uint256 deadline, address recipient) public payable returns (uint256) {
    require(recipient != address(this) && recipient != address(0));
    return ethToTokenOutput(tokensBought, msg.value, deadline, msg.sender, recipient);
  }

  function tokenToEthInput(uint256 tokensSold, uint256 minEth, uint256 deadline, address buyer, address payable recipient) private nonReentrant returns (uint256) {
    require(deadline >= block.timestamp && tokensSold > 0 && minEth > 0);
    uint256 tokenReserve = token.balanceOf(address(this));
    uint256 ethBought = getInputPrice(tokensSold, tokenReserve, address(this).balance);
    require(ethBought >= minEth);
    recipient.transfer(ethBought);
    require(token.transferFrom(buyer, address(this), tokensSold));
    emit EthPurchase(buyer, tokensSold, ethBought);
    return ethBought;
  }


  function tokenToEthSwapInput(uint256 tokensSold, uint256 minEth, uint256 deadline) public returns (uint256) {
    return tokenToEthInput(tokensSold, minEth, deadline, msg.sender, msg.sender);
  }


  function tokenToEthTransferInput(uint256 tokensSold, uint256 minEth, uint256 deadline, address payable recipient) public returns (uint256) {
    require(recipient != address(this) && recipient != address(0));
    return tokenToEthInput(tokensSold, minEth, deadline, msg.sender, recipient);
  }

  function tokenToEthOutput(uint256 ethBought, uint256 maxTokens, uint256 deadline, address buyer, address payable recipient) private nonReentrant returns (uint256) {
    require(deadline >= block.timestamp && ethBought > 0);
    uint256 tokenReserve = token.balanceOf(address(this));
    uint256 tokensSold = getOutputPrice(ethBought, tokenReserve, address(this).balance);
    // tokens sold is always > 0
    require(maxTokens >= tokensSold);
    recipient.transfer(ethBought);
    require(token.transferFrom(buyer, address(this), tokensSold));
    emit EthPurchase(buyer, tokensSold, ethBought);
    return tokensSold;
  }


  function tokenToEthSwapOutput(uint256 ethBought, uint256 maxTokens, uint256 deadline) public returns (uint256) {
    return tokenToEthOutput(ethBought, maxTokens, deadline, msg.sender, msg.sender);
  }


  function tokenToEthTransferOutput(uint256 ethBought, uint256 maxTokens, uint256 deadline, address payable recipient) public returns (uint256) {
    require(recipient != address(this) && recipient != address(0));
    return tokenToEthOutput(ethBought, maxTokens, deadline, msg.sender, recipient);
  }

  function tokenToTokenInput(
    uint256 tokensSold,
    uint256 minTokensBought,
    uint256 minEthBought,
    uint256 deadline,
    address buyer,
    address recipient,
    address payable exchangeAddr)
    private nonReentrant returns (uint256)
  {
    require(deadline >= block.timestamp && tokensSold > 0 && minTokensBought > 0 && minEthBought > 0);
    require(exchangeAddr != address(this) && exchangeAddr != address(0));
    uint256 tokenReserve = token.balanceOf(address(this));
    uint256 ethBought = getInputPrice(tokensSold, tokenReserve, address(this).balance);
    require(ethBought >= minEthBought);
    require(token.transferFrom(buyer, address(this), tokensSold));
    uint256 tokensBought = IUniswapExchange(exchangeAddr).ethToTokenTransferInput.value(ethBought)(minTokensBought, deadline, recipient);
    emit EthPurchase(buyer, tokensSold, ethBought);
    return tokensBought;
  }


  function tokenToTokenSwapInput(
    uint256 tokensSold,
    uint256 minTokensBought,
    uint256 minEthBought,
    uint256 deadline,
    address tokenAddr)
    public returns (uint256)
  {
    address payable exchangeAddr = factory.getExchange(tokenAddr);
    return tokenToTokenInput(tokensSold, minTokensBought, minEthBought, deadline, msg.sender, msg.sender, exchangeAddr);
  }


  function tokenToTokenTransferInput(
    uint256 tokensSold,
    uint256 minTokensBought,
    uint256 minEthBought,
    uint256 deadline,
    address recipient,
    address tokenAddr)
    public returns (uint256)
  {
    address payable exchangeAddr = factory.getExchange(tokenAddr);
    return tokenToTokenInput(tokensSold, minTokensBought, minEthBought, deadline, msg.sender, recipient, exchangeAddr);
  }

  function tokenToTokenOutput(
    uint256 tokensBought,
    uint256 maxTokensSold,
    uint256 maxEthSold,
    uint256 deadline,
    address buyer,
    address recipient,
    address payable exchangeAddr)
    private nonReentrant returns (uint256)
  {
    require(deadline >= block.timestamp && (tokensBought > 0 && maxEthSold > 0));
    require(exchangeAddr != address(this) && exchangeAddr != address(0));
    uint256 ethBought = IUniswapExchange(exchangeAddr).getEthToTokenOutputPrice(tokensBought);
    uint256 tokenReserve = token.balanceOf(address(this));
    uint256 tokensSold = getOutputPrice(ethBought, tokenReserve, address(this).balance);
    // tokens sold is always > 0
    require(maxTokensSold >= tokensSold && maxEthSold >= ethBought);
    require(token.transferFrom(buyer, address(this), tokensSold));
    IUniswapExchange(exchangeAddr).ethToTokenTransferOutput.value(ethBought)(tokensBought, deadline, recipient);
    emit EthPurchase(buyer, tokensSold, ethBought);
    return tokensSold;
  }


  function tokenToTokenSwapOutput(
    uint256 tokensBought,
    uint256 maxTokensSold,
    uint256 maxEthSold,
    uint256 deadline,
    address tokenAddr)
    public returns (uint256)
  {
    address payable exchangeAddr = factory.getExchange(tokenAddr);
    return tokenToTokenOutput(tokensBought, maxTokensSold, maxEthSold, deadline, msg.sender, msg.sender, exchangeAddr);
  }


  function tokenToTokenTransferOutput(
    uint256 tokensBought,
    uint256 maxTokensSold,
    uint256 maxEthSold,
    uint256 deadline,
    address recipient,
    address tokenAddr)
    public returns (uint256)
  {
    address payable exchangeAddr = factory.getExchange(tokenAddr);
    return tokenToTokenOutput(tokensBought, maxTokensSold, maxEthSold, deadline, msg.sender, recipient, exchangeAddr);
  }


  function getEthToTokenInputPrice(uint256 ethSold) public view returns (uint256) {
    require(ethSold > 0);
    uint256 tokenReserve = token.balanceOf(address(this));
    return getInputPrice(ethSold, address(this).balance, tokenReserve);
  }


  function getEthToTokenOutputPrice(uint256 tokensBought) public view returns (uint256) {
    require(tokensBought > 0);
    uint256 tokenReserve = token.balanceOf(address(this));
    uint256 ethSold = getOutputPrice(tokensBought, address(this).balance, tokenReserve);
    return ethSold;
  }


  function getTokenToEthInputPrice(uint256 tokensSold) public view returns (uint256) {
    require(tokensSold > 0);
    uint256 tokenReserve = token.balanceOf(address(this));
    uint256 ethBought = getInputPrice(tokensSold, tokenReserve, address(this).balance);
    return ethBought;
  }


  function getTokenToEthOutputPrice(uint256 ethBought) public view returns (uint256) {
    require(ethBought > 0);
    uint256 tokenReserve = token.balanceOf(address(this));
    return getOutputPrice(ethBought, tokenReserve, address(this).balance);
  }


  function tokenAddress() public view returns (address) {
    return address(token);
  }


  function factoryAddress() public view returns (address) {
    return address(factory);
  }


  function addLiquidity(uint256 minLiquidity, uint256 maxTokens, uint256 deadline) public payable nonReentrant returns (uint256) {
    require(deadline >= block.timestamp && maxTokens > 0 && msg.value > 0, 'INVALID_INPUT');
    uint256 totalLiquidity = totalSupply;

    if (totalLiquidity > 0) {
      require(minLiquidity > 0);
      uint256 ethReserve = address(this).balance.sub(msg.value);
      uint256 tokenReserve = token.balanceOf(address(this));
      uint256 tokenAmount = (msg.value.mul(tokenReserve) / ethReserve).add(1);
      uint256 liquidityMinted = msg.value.mul(totalLiquidity) / ethReserve;
      require(maxTokens >= tokenAmount && liquidityMinted >= minLiquidity);
      balanceOf[msg.sender] = balanceOf[msg.sender].add(liquidityMinted);
      totalSupply = totalLiquidity.add(liquidityMinted);
      require(token.transferFrom(msg.sender, address(this), tokenAmount));
      emit AddLiquidity(msg.sender, msg.value, tokenAmount);
      emit Transfer(address(0), msg.sender, liquidityMinted);
      return liquidityMinted;

    } else {
      require(msg.value >= 1000000000, 'INVALID_VALUE');
      require(factory.getExchange(address(token)) == address(this));
      uint256 tokenAmount = maxTokens;
      uint256 initialLiquidity = address(this).balance;
      totalSupply = initialLiquidity;
      balanceOf[msg.sender] = initialLiquidity;
      require(token.transferFrom(msg.sender, address(this), tokenAmount));
      emit AddLiquidity(msg.sender, msg.value, tokenAmount);
      emit Transfer(address(0), msg.sender, initialLiquidity);
      return initialLiquidity;
    }
  }


  function removeLiquidity(uint256 amount, uint256 minEth, uint256 minTokens, uint256 deadline) public nonReentrant returns (uint256, uint256) {
    require(amount > 0 && deadline >= block.timestamp && minEth > 0 && minTokens > 0);
    uint256 totalLiquidity = totalSupply;
    require(totalLiquidity > 0);
    uint256 tokenReserve = token.balanceOf(address(this));
    uint256 ethAmount = amount.mul(address(this).balance) / totalLiquidity;
    uint256 tokenAmount = amount.mul(tokenReserve) / totalLiquidity;
    require(ethAmount >= minEth && tokenAmount >= minTokens);
    balanceOf[msg.sender] = balanceOf[msg.sender].sub(amount);
    totalSupply = totalLiquidity.sub(amount);
    msg.sender.transfer(ethAmount);
    require(token.transfer(msg.sender, tokenAmount));
    emit RemoveLiquidity(msg.sender, ethAmount, tokenAmount);
    emit Transfer(msg.sender, address(0), amount);
    return (ethAmount, tokenAmount);
  }
}
