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
    event ProxyDeployed(address indexed owner, address indexed proxy);
    event PurchaseComplete(
        address purchaser,
        string tokenSetId,
        uint256 quantity
    );

    uint256 public exportPrice = 0.0001 ether;

    // mapping(address => bool) public approvedImplementation;
    mapping(string => uint256) public paidExports;

    function export(
        string memory tokenSetId,
        uint256 quantity,
        bytes memory signature
    ) public payable {
        require(quantity > 0, "INVALID_QUANTITY");
        require(msg.value == quantity * exportPrice, "INSUFFICIENT_PAYMENT");
        require(paidExports[tokenSetId] == 0, "ALREADY_PAID");
        bytes32 hash = keccak256(
            abi.encodePacked(msg.sender, tokenSetId, quantity)
        );
        require(verify(hash, signature), "INVALID_SIGNATURE");

        paidExports[tokenSetId] = quantity;
        emit PurchaseComplete(msg.sender, tokenSetId, quantity);
    }

    function verify(
        bytes32 hash,
        bytes memory signature
    ) internal view returns (bool) {
        require(signer != address(0), "INVALID_SIGNER_ADDRESS");
        bytes32 signedHash = hash.toEthSignedMessageHash();
        return signedHash.recover(signature) == signer;
    }

    function setExportPrice(uint256 newExportPrice) external {
        require(newExportPrice != 0, "EXPORT PRICE SHOULD NOT BE ZERO");
        exportPrice = newExportPrice;
    }

    /* ------------- external ------------- */

    function register(bytes32 id) external payable {
        emit Registered(msg.sender, id, msg.value);
    }

    function deployProxy(
        address implementation,
        bytes calldata initCalldata,
        bytes[] calldata calls,
        string memory tokenSetId
    ) external returns (address proxy) {
        // if (!approvedImplementation[implementation]) revert ImplementationNotApproved();
        require(exportPrice[tokenSetId] > 0, "NOT REGISTERED YET");

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

    // function setImplementationApproved(address implementation, bool approved) external onlyOwner {
    //     approvedImplementation[implementation] = approved;
    // }

    function withdrawETH() external onlyOwner {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");

        require(success);
    }

    function recoverToken(ERC20 token) external onlyOwner {
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }

    function recoverNFT(ERC721 token, uint256 id) external onlyOwner {
        token.transferFrom(address(this), msg.sender, id);
    }
}
