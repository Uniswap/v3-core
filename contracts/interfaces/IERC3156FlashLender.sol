// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

interface IERC3156FlashLender {
    function flashLoan(
        address receiver,
        address token,
        uint256 value,
        bytes calldata data
    ) external;

    /**
     * @dev The fee to be charged for a given loan.
     * @param token The loan currency.
     * @param value The amount of tokens lent.
     * @return The amount of `token` to be charged for the loan, on top of the returned principal.
     */
    function flashFee(address token, uint256 value) external view returns (uint256);

    /**
     * @dev The amount of currency available to be lended.
     * @param token The loan currency.
     * @return The amount of `token` that can be borrowed.
     */
    function flashSupply(address token) external view returns (uint256);
}
