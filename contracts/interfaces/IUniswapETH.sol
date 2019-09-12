pragma solidity ^0.5.0;

interface IUniswapExchange {
  event TokenPurchase(address indexed buyer, uint256 indexed eth_sold, uint256 indexed tokens_bought);
  event EthPurchase(address indexed buyer, uint256 indexed tokens_sold, uint256 indexed eth_bought);
  event AddLiquidity(address indexed provider, uint256 indexed eth_amount, uint256 indexed token_amount);
  event RemoveLiquidity(address indexed provider, uint256 indexed eth_amount, uint256 indexed token_amount);

   /**
   * @notice Convert ETH to Tokens.
   * @dev User specifies exact input (msg.value).
   * @dev User cannot specify minimum output or deadline.
   */
  function () external payable;

  /**
    * @dev Pricing function for converting between ETH && Tokens.
    * @param inputAmount Amount of ETH or Tokens being sold.
    * @param inputReserve Amount of ETH or Tokens (input type) in exchange reserves.
    * @param outputReserve Amount of ETH or Tokens (output type) in exchange reserves.
    * @return Amount of ETH or Tokens bought.
    */
  function getInputPrice(uint256 inputAmount, uint256 inputReserve, uint256 outputReserve) external view returns (uint256);

  /**
    * @dev Pricing function for converting between ETH && Tokens.
    * @param outputAmount Amount of ETH or Tokens being bought.
    * @param inputReserve Amount of ETH or Tokens (input type) in exchange reserves.
    * @param outputReserve Amount of ETH or Tokens (output type) in exchange reserves.
    * @return Amount of ETH or Tokens sold.
    */
  function getOutputPrice(uint256 outputAmount, uint256 inputReserve, uint256 outputReserve) external view returns (uint256);


  /**
   * @notice Convert ETH to Tokens.
   * @dev User specifies exact input (msg.value) && minimum output.
   * @param minTokens Minimum Tokens bought.
   * @param deadline Time after which this transaction can no longer be executed.
   * @return Amount of Tokens bought.
   */
  function ethToTokenSwapInput(uint256 minTokens, uint256 deadline) external payable returns (uint256);

  /**
   * @notice Convert ETH to Tokens && transfers Tokens to recipient.
   * @dev User specifies exact input (msg.value) && minimum output
   * @param minTokens Minimum Tokens bought.
   * @param deadline Time after which this transaction can no longer be executed.
   * @param recipient The address that receives output Tokens.
   * @return  Amount of Tokens bought.
   */
  function ethToTokenTransferInput(uint256 minTokens, uint256 deadline, address recipient) external payable returns(uint256);


  /**
   * @notice Convert ETH to Tokens.
   * @dev User specifies maximum input (msg.value) && exact output.
   * @param tokensBought Amount of tokens bought.
   * @param deadline Time after which this transaction can no longer be executed.
   * @return Amount of ETH sold.
   */
  function ethToTokenSwapOutput(uint256 tokensBought, uint256 deadline) external payable returns(uint256);

  /**
   * @notice Convert ETH to Tokens && transfers Tokens to recipient.
   * @dev User specifies maximum input (msg.value) && exact output.
   * @param tokensBought Amount of tokens bought.
   * @param deadline Time after which this transaction can no longer be executed.
   * @param recipient The address that receives output Tokens.
   * @return Amount of ETH sold.
   */
  function ethToTokenTransferOutput(uint256 tokensBought, uint256 deadline, address recipient) external payable returns (uint256);

  /**
   * @notice Convert Tokens to ETH.
   * @dev User specifies exact input && minimum output.
   * @param tokensSold Amount of Tokens sold.
   * @param minEth Minimum ETH purchased.
   * @param deadline Time after which this transaction can no longer be executed.
   * @return Amount of ETH bought.
   */
  function tokenToEthSwapInput(uint256 tokensSold, uint256 minEth, uint256 deadline) external returns (uint256);

  /**
   * @notice Convert Tokens to ETH && transfers ETH to recipient.
   * @dev User specifies exact input && minimum output.
   * @param tokensSold Amount of Tokens sold.
   * @param minEth Minimum ETH purchased.
   * @param deadline Time after which this transaction can no longer be executed.
   * @param recipient The address that receives output ETH.
   * @return  Amount of ETH bought.
   */
  function tokenToEthTransferInput(uint256 tokensSold, uint256 minEth, uint256 deadline, address recipient) external returns (uint256);

  /**
   * @notice Convert Tokens to ETH.
   * @dev User specifies maximum input && exact output.
   * @param ethBought Amount of ETH purchased.
   * @param maxTokens Maximum Tokens sold.
   * @param deadline Time after which this transaction can no longer be executed.
   * @return Amount of Tokens sold.
   */
  function tokenToEthSwapOutput(uint256 ethBought, uint256 maxTokens, uint256 deadline) external returns (uint256);

  /**
   * @notice Convert Tokens to ETH && transfers ETH to recipient.
   * @dev User specifies maximum input && exact output.
   * @param ethBought Amount of ETH purchased.
   * @param maxTokens Maximum Tokens sold.
   * @param deadline Time after which this transaction can no longer be executed.
   * @param recipient The address that receives output ETH.
   * @return Amount of Tokens sold.
   */
  function tokenToEthTransferOutput(uint256 ethBought, uint256 maxTokens, uint256 deadline, address recipient) external returns (uint256);

  /**
   * @notice Convert Tokens (token) to Tokens (tokenAddr).
   * @dev User specifies exact input && minimum output.
   * @param tokensSold Amount of Tokens sold.
   * @param minTokensBought Minimum Tokens (tokenAddr) purchased.
   * @param minEthBought Minimum ETH purchased as intermediary.
   * @param deadline Time after which this transaction can no longer be executed.
   * @param tokenAddr The address of the token being purchased.
   * @return Amount of Tokens (tokenAddr) bought.
   */
  function tokenToTokenSwapInput(
    uint256 tokensSold,
    uint256 minTokensBought,
    uint256 minEthBought,
    uint256 deadline,
    address tokenAddr)
    external returns (uint256);

    /**
     * @notice Convert Tokens (token) to Tokens (tokenAddr) && transfers
     *         Tokens (tokenAddr) to recipient.
     * @dev User specifies exact input && minimum output.
     * @param tokensSold Amount of Tokens sold.
     * @param minTokensBought Minimum Tokens (tokenAddr) purchased.
     * @param minEthBought Minimum ETH purchased as intermediary.
     * @param deadline Time after which this transaction can no longer be executed.
     * @param recipient The address that receives output ETH.
     * @param tokenAddr The address of the token being purchased.
     * @return Amount of Tokens (tokenAddr) bought.
     */
  function tokenToTokenTransferInput(
    uint256 tokensSold,
    uint256 minTokensBought,
    uint256 minEthBought,
    uint256 deadline,
    address recipient,
    address tokenAddr)
    external returns (uint256);


    /**
     * @notice Convert Tokens (token) to Tokens (tokenAddr).
     * @dev User specifies maximum input && exact output.
     * @param tokensBought Amount of Tokens (tokenAddr) bought.
     * @param maxTokensSold Maximum Tokens (token) sold.
     * @param maxEthSold Maximum ETH purchased as intermediary.
     * @param deadline Time after which this transaction can no longer be executed.
     * @param tokenAddr The address of the token being purchased.
     * @return Amount of Tokens (token) sold.
     */
  function tokenToTokenSwapOutput(
    uint256 tokensBought,
    uint256 maxTokensSold,
    uint256 maxEthSold,
    uint256 deadline,
    address tokenAddr)
    external returns (uint256);

    /**
     * @notice Convert Tokens (token) to Tokens (tokenAddr) && transfers
     *         Tokens (tokenAddr) to recipient.
     * @dev User specifies maximum input && exact output.
     * @param tokensBought Amount of Tokens (tokenAddr) bought.
     * @param maxTokensSold Maximum Tokens (token) sold.
     * @param maxEthSold Maximum ETH purchased as intermediary.
     * @param deadline Time after which this transaction can no longer be executed.
     * @param recipient The address that receives output ETH.
     * @param tokenAddr The address of the token being purchased.
     * @return Amount of Tokens (token) sold.
     */
  function tokenToTokenTransferOutput(
    uint256 tokensBought,
    uint256 maxTokensSold,
    uint256 maxEthSold,
    uint256 deadline,
    address recipient,
    address tokenAddr)
    external returns (uint256);


    /**
     * @notice Public price function for ETH to Token trades with an exact input.
     * @param ethSold Amount of ETH sold.
     * @return Amount of Tokens that can be bought with input ETH.
     */
  function getEthToTokenInputPrice(uint256 ethSold) external view returns (uint256);

  /**
   * @notice Public price function for ETH to Token trades with an exact output.
   * @param tokensBought Amount of Tokens bought.
   * @return Amount of ETH needed to buy output Tokens.
   */
  function getEthToTokenOutputPrice(uint256 tokensBought) external view returns (uint256);

  /**
   * @notice Public price function for Token to ETH trades with an exact input.
   * @param tokensSold Amount of Tokens sold.
   * @return Amount of ETH that can be bought with input Tokens.
   */
  function getTokenToEthInputPrice(uint256 tokensSold) external view returns (uint256);

  /**
   * @notice Public price function for Token to ETH trades with an exact output.
   * @param ethBought Amount of output ETH.
   * @return Amount of Tokens needed to buy output ETH.
   */
  function getTokenToEthOutputPrice(uint256 ethBought) external view returns (uint256);

  /**
   * @return Address of Token that is sold on this exchange.
   */
  function tokenAddress() external view returns (address);

  /**
   * @return Address of factory that created this exchange.
   */
  function factoryAddress() external view returns (address);


  /**
   * @notice Deposit ETH && Tokens (token) at current ratio to mint UNI tokens.
   * @dev minLiquidity does nothing when total UNI supply is 0.
   * @param minLiquidity Minimum number of UNI sender will mint if total UNI supply is greater than 0.
   * @param maxTokens Maximum number of tokens deposited. Deposits max amount if total UNI supply is 0.
   * @param deadline Time after which this transaction can no longer be executed.
   * @return The amount of UNI minted.
   */
  function addLiquidity(uint256 minLiquidity, uint256 maxTokens, uint256 deadline) external payable returns (uint256);

  /**
   * @dev Burn UNI tokens to withdraw ETH && Tokens at current ratio.
   * @param amount Amount of UNI burned.
   * @param minEth Minimum ETH withdrawn.
   * @param minTokens Minimum Tokens withdrawn.
   * @param deadline Time after which this transaction can no longer be executed.
   * @return The amount of ETH && Tokens withdrawn.
   */
  function removeLiquidity(uint256 amount, uint256 minEth, uint256 minTokens, uint256 deadline) external returns (uint256, uint256);
}
