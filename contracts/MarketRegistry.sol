// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

import "../lib/solmate/src/tokens/ERC20.sol";
import "../lib/solmate/src/test/utils/mocks/MockERC20.sol";

import "./Ownable.sol";

error IncorrectValue();

contract MarketRegistry is Ownable {
    /* ------------- Events ------------- */

    event Registered(address indexed user);

    /* ------------- Storage ------------- */

    uint256 public registryFees;
    mapping(address => bool) public registered;

    constructor(uint256 registryFees_) {
        registryFees = registryFees_;
    }

    /* ------------- External ------------- */

    function register() external payable {
        if (msg.value != registryFees) revert IncorrectValue();
        if (!registered[msg.sender]) revert IncorrectValue();

        registered[msg.sender] = true;
    }

    /* ------------- Owner ------------- */

    function setRegistryFees(uint256 fees) external onlyOwner {
        registryFees = fees;
    }

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
