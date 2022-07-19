// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Owned} from "solmate/auth/Owned.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";

error IncorrectValue();

contract CRFTDRegistry is Owned(msg.sender) {
    /* ------------- Events ------------- */

    event Registered(address indexed user, uint256 fee);

    /* ------------- Storage ------------- */

    uint256 public registryFee;

    constructor(uint256 registryFee_) {
        registryFee = registryFee_;
    }

    /* ------------- External ------------- */

    function register() external payable {
        if (msg.value != registryFee) revert IncorrectValue();

        emit Registered(msg.sender, registryFee);
    }

    /* ------------- Owner ------------- */

    function setRegistryFee(uint256 fees) external onlyOwner {
        registryFee = fees;
    }

    function withdrawETH() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    function recoverToken(ERC20 token) external onlyOwner {
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }

    function recoverNFT(ERC721 token, uint256 id) external onlyOwner {
        token.transferFrom(address(this), msg.sender, id);
    }
}
