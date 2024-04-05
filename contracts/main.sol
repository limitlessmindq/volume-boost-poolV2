// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "./BalancerFlashLoan.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {NonameToken} from "./NoNameToken.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

import "hardhat/console.sol";

contract main {
    //how many jumps of work you need
    uint public interactions;
    uint256 public amountForSwaps;
    uint public numberOfSwaps;

    // address public constant vault = 0xBA12222222228d8Ba445958a75a0704d566BF2C8; // mainnet
    address public constant vault = 0xBA12222222228d8Ba445958a75a0704d566BF2C8; // arbitrum
    // address public constant keeper = 0x8EB8a3b98659Cce290402893d0123abb75E3ab28; // mainnet
    address public constant keeper = 0xC3E5607Cd4ca0D5Fe51e09B60Ed97a0Ae6F874dd; // arbitrum


    // IUniswapV2Router02 public uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D); // mainnet
    IUniswapV2Router02 public uniswapV2Router = IUniswapV2Router02(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506); // arbitrum
    IUniswapV2Pair public uniswapV2Pair;

    NonameToken public token0; // NNT
    // IERC20 public token1 = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); // WETH // mainnet
    IERC20 public token1 = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1); // WETH // arbitrum

    constructor (address payable _noNameToken, address payable _uniswapV2Pair) {
        token0 = NonameToken(_noNameToken);
        uniswapV2Pair = IUniswapV2Pair(_uniswapV2Pair);
    }

    receive() external payable {}

    function receiveFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory
    ) external {
        console.log("balance after loan:", token1.balanceOf(address(this)));
        work(tokens, amounts);
        console.log("balance after removing loan:", token1.balanceOf(address(this)));

        for (uint256 i; i < tokens.length; ) {
            IERC20 token = tokens[i];
            uint256 amount = amounts[i];

            disadvantage(token, amount);

            console.log("borrowed amount:", amount);
            uint256 feeAmount = feeAmounts[i];
            console.log("flashloan fee: ", feeAmount);

            // Return loan
            token.transfer(vault, amount);

            unchecked {
                ++i;
            }
        }
        (uint112 reserve0, uint112 reserve1, ) = uniswapV2Pair.getReserves();
        console.log("reservs after loan: ", reserve0, reserve1);
    }

    function flashLoan() external {
        (uint112 reserve0, uint112 reserve1, ) = uniswapV2Pair.getReserves();
        console.log("reservs Before loan: ", reserve0, reserve1);
        IERC20[] memory tokens = new IERC20[](1);
        uint256[] memory amounts = new uint256[](1);

        tokens[0] = token1;
        // подсчет количества эфира для нужного количества токенов + комса на свапы и эфир на свапы
        amounts[0] = countAmountOfTokens();

        for(uint i; i < interactions; ){
            console.log("amount: ", amounts[i]);
            console.log("amount before loan:", token1.balanceOf(address(this)));
            IBalancerVault(vault).flashLoan(
                IFlashLoanRecipient(address(this)),
                tokens,
                amounts,
                ""
            );

            unchecked {
                ++i;
            }
        }
    }

    function setup(uint _interactions, uint256 _amountForSwaps, uint _numberOfSwaps) external {
        interactions = _interactions;
        amountForSwaps = _amountForSwaps;
        numberOfSwaps = _numberOfSwaps;
        token1.approve(address(uniswapV2Router), type(uint256).max);
        token0.approve(address(uniswapV2Router), type(uint256).max);
        token1.approve(address(uniswapV2Pair), type(uint256).max);
        token0.approve(address(uniswapV2Pair), type(uint256).max);
        uniswapV2Pair.approve(address(uniswapV2Router), type(uint256).max);
    }

    function addLiq(uint256 amount_token_0, uint256 amount_token_1) external {
        uniswapV2Router.addLiquidityETH{ value:amount_token_1 }(
            address(token0),
            amount_token_0,
            0,
            0,
            address(this),
            3600000000000000
        );
    }

    function work (
        IERC20[] memory tokens,
        uint256[] memory amounts
        ) public {
        // console.log("ho"token1.balanceOf(address(this)));
        console.log("amount for liquidity: ", amounts[0] - amountForSwaps);
        require( token1.balanceOf(address(this)) >=amounts[0] - amountForSwaps, "no balance" );
        (, , uint liquidity) = uniswapV2Router.addLiquidity(
            address(token0),
            address(token1),
            token0.balanceOf(address(this)),
            amounts[0] - amountForSwaps,
            0,
            0,
            address(this),
            36000000000);
        console.log("here");
        for (uint i; i < numberOfSwaps; i++) {
            uint256 start_balance_0 = token0.balanceOf(address(this));
            uint256 start_balance_1 = tokens[0].balanceOf(address(this));
            if (i % 2 == 0) {
                console.log("swap amount in WETH: ", start_balance_1);
                address[] memory path = new address[](2);
                path[0] = address(tokens[0]);
                path[1] = address(token0);
                uniswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    start_balance_1,
                    0,
                    path,
                    address(this),
                    36000000000
                );
            } else {
                console.log("swap amount in NoNameToken: ", start_balance_0);
                address[] memory path = new address[](2);
                path[0] = address(token0);
                path[1] = address(tokens[0]);
                uniswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    start_balance_0,
                    0,
                    path,
                    address(this),
                    36000000000
                );
            }
        }
        console.log("LP: ", uniswapV2Pair.balanceOf(address(this)));
        uniswapV2Router.removeLiquidity(
            address(token0),
            address(token1),
            liquidity,
            0,
            0,
            address(this),
            36000000000
        );
        console.log("LP1: ", uniswapV2Pair.balanceOf(address(this)));
    }

    function disadvantage(IERC20 token, uint256 amount) internal {
        uint256 currentAmount = token.balanceOf(address(this));
        if(currentAmount < amount) {
            console.log("keeper amount: ", token.balanceOf(address(keeper)));
            uint256 missingQuantity = amount - currentAmount;
            console.log("missingQuantity amount: ", missingQuantity);
            require(token.balanceOf(address(keeper)) >= missingQuantity, "keeper has not enough WETH");
            token.transferFrom(keeper, address(this), missingQuantity);
        }
    }

    function countAmountOfTokens() internal view returns (uint256) {
        uint256 count_0 = token0.balanceOf(address(this));
        (uint112 reserve0, uint112 reserve1, ) = uniswapV2Pair.getReserves();
        require((reserve0 > 0) && (reserve1 > 0), "Empty pool");
        // x / y = (x + x1) / (y + y1) => x * y + x * y1 = x * y + x1 * y => x * y1 = x1 * y => y1 = x1 * y / x
        return count_0 * reserve1 / reserve0 + amountForSwaps;
    }
}
