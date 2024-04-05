// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "../interfaces/IFlashLoanRecipient.sol";
import "../interfaces/IBalancerVault.sol";
import "hardhat/console.sol";

contract BalancerFlashLoan is IFlashLoanRecipient {

    address public constant vault = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;  // заменить
    address public constant keeper = 0xaB889C04a2892D874FAA222fE3CcE5d1490D3338;

    function receiveFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory
    ) external override {
        for (uint256 i; i < tokens.length; ++i) {
            IERC20 token = tokens[i];
            uint256 amount = amounts[i];

            disadvantage(token, amount);

            console.log("borrowed amount:", amount);
            uint256 feeAmount = feeAmounts[i];
            console.log("flashloan fee: ", feeAmount);

            // Return loan
            token.transfer(vault, amount);
        }
    }

    function flashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) external {
        IBalancerVault(vault).flashLoan(
            IFlashLoanRecipient(address(this)),
            tokens,
            amounts,
            userData
        );
    }

    function disadvantage(IERC20 token, uint256 amount) internal {
        uint256 currentAmount = token.balanceOf(address(this));

        if(currentAmount < amount) {
            uint256 missingQuantity = amount - currentAmount;

            token.transferFrom(keeper, address(this), missingQuantity);
        }
    }
}
