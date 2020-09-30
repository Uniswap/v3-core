pragma solidity =0.6.11;

import "../interfaces/IUniswapV3Pair.sol";

contract UniswapV3PairTest {
    IUniswapV3Pair pair;

    constructor(address pair_) public {
        pair = IUniswapV3Pair(pair_);
    }

    function getGasCostOfGetFee() public view returns (uint) {
        uint gasBefore = gasleft();
        pair.getFee();
        return gasBefore - gasleft();
    }

    function getGasCostOfGetVirtualSupply() public view returns (uint) {
        uint gasBefore = gasleft();
        pair.getVirtualSupply();
        return gasBefore - gasleft();
    }
}
