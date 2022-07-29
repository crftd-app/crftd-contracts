// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Owned} from "solmate/auth/Owned.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";

import {OwnableUDS as Ownable} from "UDS/auth/OwnableUDS.sol";
import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";

error IncorrectValue();

contract CRFTDRegistry is Owned(msg.sender) {
    /* ------------- events ------------- */

    event Registered(address indexed user, uint256 fee);

    event ProxyDeployed(address indexed owner, address indexed implementation);

    /* ------------- storage ------------- */

    uint256 public registryFee;

    constructor(uint256 registryFee_) {
        registryFee = registryFee_;
    }

    /* ------------- external ------------- */

    function register() external payable {
        if (msg.value != registryFee) revert IncorrectValue();

        emit Registered(msg.sender, registryFee);
    }

    function deployProxy(
        address implementation,
        bytes calldata initCalldata,
        bytes[] calldata calls
    ) external returns (address proxy) {
        proxy = address(new ERC1967Proxy(implementation, initCalldata));

        for (uint256 i; i < calls.length; ++i) {
            (bool success, ) = proxy.call(calls[i]);

            if (!success) {
                assembly {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
            }
        }

        Ownable(proxy).transferOwnership(msg.sender);

        emit ProxyDeployed(msg.sender, proxy);
    }

    /* ------------- owner ------------- */

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
