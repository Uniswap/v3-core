pragma solidity ^0.5.11;

interface IUniswapERC20 {

  event SwapAForB(address indexed buyer, uint256 amountSold, uint256 amountBought);
  event SwapBForA(address indexed buyer, uint256 amountSold, uint256 amountBought);
  event AddLiquidity(address indexed provider, uint256 amountTokenA, uint256 amountTokenB);
  event RemoveLiquidity(address indexed provider, uint256 amountTokenA, uint256 amountTokenB);


  function getInputPrice(uint256 inputAmount, uint256 inputReserve, uint256 outputReserve) external pure returns (uint256);


  function getOutputPrice(uint256 outputAmount, uint256 inputReserve, uint256 outputReserve) external pure returns (uint256);


  //TO: DO msg.sender is wrapper
  function swapInput(address inputToken, uint256 amountSold, address recipient) external returns (uint256);


  //TO: DO msg.sender is wrapper
  function swapOutput(address outputToken, uint256 amountBought, address recipient) external returns (uint256);


  function getInputPrice(address inputToken, uint256 amountSold) external view returns (uint256);


  function getOutputPrice(address outputToken, uint256 amountBought) external view returns (uint256);


  function tokenAAddress() external view returns (address);


  function tokenBAddress() external view returns (address);


  function addLiquidity(uint256 amountA, uint256 maxTokenB, uint256 minLiquidity) external returns (uint256);


  function removeLiquidity(uint256 amount, uint256 minTokenA, uint256 minTokenB) external returns (uint256, uint256);
}
