// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Owned} from "solmate/auth/Owned.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";
import {OwnableUDS as Ownable} from "UDS/auth/OwnableUDS.sol";

error IncorrectValue();
error ImplementationNotApproved();

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
    event CollectionRegistered(address indexed user, bytes32 id, uint256 fee);
    event ProxyDeployed(address indexed owner, address indexed proxy);
    event VIPStatusChanged(address indexed user, bool status);

    mapping(address => bool) public approvedImplementation;

    mapping(bytes32 => uint256) public paidStatus;
    mapping(address => bool) public vipRole;


    /* ------------- external ------------- */
    function register(bytes32 id) external payable {
        emit Registered(msg.sender, id, msg.value);
    }

    /// @dev This is reponsible for the collect payment for art generation
    /// @dev tokenId is the keccak256(abi.encodePacked(msg.sender,collectionId,collectionSize))
    function registerCollection(bytes32 tokenId, uint256 collectionSize) external payable {
        uint256 fee = 0.0001 ether * collectionSize;
        if (msg.value != fee) {
            revert IncorrectValue();
        }
        paidStatus[tokenId] = 1;
        emit CollectionRegistered(msg.sender, tokenId, msg.value);
    }

    /// crftd has 1 ETH fixed fee for 10k collection
    function feePreview(uint256 collectionSize) public pure returns(uint256) {
        return 0.0001 ether * collectionSize;
    }

    function changeVipRoleStatus(address user, bool status) external onlyOwner {
        vipRole[user] = status;
        emit VIPStatusChanged(user, status);
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
