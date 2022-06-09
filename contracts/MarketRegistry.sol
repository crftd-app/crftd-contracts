// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

import "./Ownable.sol";

error IncorrectValue();

contract MarketRegistry is Ownable {
    /* ------------- Events ------------- */

    event Registered(address indexed user);

    /* ------------- Storage ------------- */

    uint256 marketFees;
    mapping(address => bool) public registry;

    constructor(uint256 marketFees_) {
        marketFees = marketFees_;
    }

    /* ------------- External ------------- */

    function register() external payable {
        if (msg.value != marketFees) revert IncorrectValue();
        registry[msg.sender] = true;
    }

    /* ------------- Owner ------------- */

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    function recoverToken(IERC20 token) external onlyOwner {
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }

    function recoverNFT(IERC721 token, uint256 id) external onlyOwner {
        token.transferFrom(address(this), msg.sender, id);
    }
}
