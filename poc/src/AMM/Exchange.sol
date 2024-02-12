// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Exchange is ERC20 {
    // libs
    using SafeERC20 for IERC20;
    // errors
    error Exchange__Invalid_address();
    error Exchange__Invalid_Reserves();
    error Exchange__Amount_is_small();

    address public immutable i_token;
    uint16 constant BASE = 10_000;

    constructor(address _token) ERC20("Xuniswap-V1", "XUNI-V1") {
        if (_token == address(0)) {
            revert Exchange__Invalid_address();
        }

        i_token = _token;
    }

    // add liquidity
    function addLiquidity(uint256 _amount) public payable returns (uint256) {
        if (getReserve() == 0) {
            IERC20 token = IERC20(i_token);
            token.safeTransferFrom(msg.sender, address(this), _amount);
            uint256 liquidity = address(this).balance;
            _mint(msg.sender, liquidity);
            return liquidity;
        } else {
            uint256 ethReserve = address(this).balance - msg.value;
            uint256 tokenReserve = getReserve();
            uint256 tokenAmount = (msg.value * tokenReserve) / ethReserve;
            if (_amount < tokenAmount) {
                revert Exchange__Amount_is_small();
            }

            IERC20 token = IERC20(i_token);
            token.safeTransferFrom(msg.sender, address(this), _amount);
            uint256 liquidity = (totalSupply() * msg.value) / ethReserve;
            _mint(msg.sender, liquidity);

            return liquidity;
        }
    }

    function getReserve() public view returns (uint256) {
        return IERC20(i_token).balanceOf(address(this));
    }

    /**
     * Using the constant product formula x * y = k
     */
    function getAmount(
        uint256 inputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    ) private pure returns (uint256) {
        if (!(inputReserve > 0 && outputReserve > 0)) {
            revert Exchange__Invalid_Reserves();
        }

        return (inputAmount * outputReserve) / (inputReserve + inputAmount);
    }

    function getTokenAmount(uint256 _ethSold) public view returns (uint256) {
        if (_ethSold == 0) {
            revert Exchange__Amount_is_small();
        }

        uint256 tokenReserve = getReserve();

        return getAmount(_ethSold, address(this).balance, tokenReserve);
    }

    function getEthAmount(uint256 _tokenSold) public view returns (uint256) {
        if (_tokenSold == 0) {
            revert Exchange__Amount_is_small();
        }

        uint256 tokenReserve = getReserve();

        return getAmount(_tokenSold, tokenReserve, address(this).balance);
    }

    function getPrice(
        uint256 inputReserve,
        uint256 outputReserve
    ) public pure returns (uint256) {
        if (inputReserve == 0 && outputReserve == 0) {
            revert Exchange__Invalid_Reserves();
        }
        return (inputReserve * BASE) / outputReserve;
    }

    function removeLiquidity(
        uint256 amountOfLPTokens
    ) public returns (uint256, uint256) {
        // Check that the user wants to remove >0 LP tokens
        if (amountOfLPTokens == 0) {
            revert Exchange__Amount_is_small();
        }

        uint256 ethReserveBalance = address(this).balance;
        uint256 lpTokenTotalSupply = totalSupply();

        // Calculate the amount of ETH and tokens to return to the user
        uint256 ethToReturn = (ethReserveBalance * amountOfLPTokens) /
            lpTokenTotalSupply;
        uint256 tokenToReturn = (getReserve() * amountOfLPTokens) /
            lpTokenTotalSupply;

        // Burn the LP tokens from the user, and transfer the ETH and tokens to the user
        _burn(msg.sender, amountOfLPTokens);
        payable(msg.sender).transfer(ethToReturn);
        ERC20(i_token).transfer(msg.sender, tokenToReturn);

        return (ethToReturn, tokenToReturn);
    }
}
