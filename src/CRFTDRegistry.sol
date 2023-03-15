// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Owned} from "solmate/auth/Owned.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";
import {OwnableUDS as Ownable} from "UDS/auth/OwnableUDS.sol";

error IncorrectValue();
error ImplementationNotApproved();
error AlreadyPaid();

//       ___           ___           ___                    _____
//      /  /\         /  /\         /  /\       ___        /  /::\
//     /  /:/        /  /::\       /  /:/_     /__/\      /  /:/\:\
//    /  /:/        /  /:/\:\     /  /:/ /\    \  \:\    /  /:/  \:\
//   /  /:/  ___   /  /::\ \:\   /  /:/ /:/     \__\:\  /__/:/ \__\:|
//  /__/:/  /  /\ /__/:/\:\_\:\ /__/:/ /:/      /  /::\ \  \:\ /  /:/
//  \  \:\ /  /:/ \__\/~|::\/:/ \  \:\/:/      /  /:/\:\ \  \:\  /:/
//   \  \:\  /:/     |  |:|::/   \  \::/      /  /:/__\/  \  \:\/:/
//    \  \:\/:/      |  |:|\/     \  \:\     /__/:/        \  \::/
//     \  \::/       |__|:|        \  \:\    \__\/          \__\/
//      \__\/         \__\|         \__\/

/// @title CRFTDRegistry
/// @author phaze (https://github.com/0xPhaze)
/// @notice CRFTD proxy registry
contract CRFTDRegistry is Owned(msg.sender) {
    event Registered(address indexed user, bytes32 id, uint256 fee);
    event TokenSetRegistered(address indexed user, bytes32 id, uint256 fee);
    event ProxyDeployed(address indexed owner, address indexed proxy);

    uint256 public tokenRegisterFee = 0.0001 ether;

    mapping(address contractAddress => bool approved) public approvedImplementation;

    mapping(bytes32 tokenSetId => bool status) public paidStatus;

    mapping(address user => uint256 nonce) public nonces;

    /* ------------- external ------------- */
    function register(bytes32 id) external payable {
        emit Registered(msg.sender, id, msg.value);
    }

    function registerTokenSet(uint256 collectionSize) external payable {
        bytes32 tokenSetId = keccak256(abi.encodePacked(msg.sender,collectionSize, nonces[msg.sender]++));
        if (paidStatus[tokenSetId]) {
            revert AlreadyPaid();
        }
        uint256 fee = tokenRegisterFee * collectionSize;
        if (msg.value != fee || msg.value == 0) revert IncorrectValue();
        paidStatus[tokenSetId] = true;
        emit TokenSetRegistered(msg.sender, tokenSetId, msg.value);
    }

    function deployProxy(address implementation, bytes calldata initCalldata, bytes[] calldata calls)
        external
        returns (address proxy)
    {
        if (!approvedImplementation[implementation]) revert ImplementationNotApproved();

        proxy = address(new ERC1967Proxy(implementation, initCalldata));

        for (uint256 i; i < calls.length; ++i) {
            (bool success,) = proxy.call(calls[i]);

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

    function setImplementationApproved(address implementation, bool approved) external onlyOwner {
        approvedImplementation[implementation] = approved;
    }

    function setTokenRegisterFee(uint256 fee) external onlyOwner {
        tokenRegisterFee = fee;
    }

    function withdrawETH() external onlyOwner {
        (bool success,) = msg.sender.call{value: address(this).balance}("");

        require(success);
    }

    function recoverToken(ERC20 token) external onlyOwner {
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }

    function recoverNFT(ERC721 token, uint256 id) external onlyOwner {
        token.transferFrom(address(this), msg.sender, id);
    }
}
