// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

import "./Ownable.sol";
import {MarketRegistry} from "./MarketRegistry.sol";

error NotActive();
error NoSupplyLeft();
error InvalidReceiver();
error InsufficientValue();
error MaxEntriesReached();
error ContractCallNotAllowed();

contract Marketplace is Ownable {
    /* ------------- Events ------------- */

    event MarketItemPurchased(uint256 indexed marketId, address indexed user, bytes32 indexed itemHash);

    /* ------------- Structs ------------- */

    struct MarketItemData {
        uint256 start;
        uint256 end;
        uint256 tokenPrice;
        uint256 ethPrice;
        uint256 maxEntries;
        uint256 maxSupply;
        bytes32 dataHash;
    }

    /* ------------- Storage ------------- */

    mapping(bytes32 => uint256) public totalSupply;
    mapping(bytes32 => mapping(address => uint256)) public numEntries;

    /* ------------- External ------------- */

    function purchaseMarketItem(
        uint256 marketId,
        MarketItemData[] calldata marketItemData,
        address token,
        address receiver
    ) external payable onlyEOA {
        uint256 totalPayment;
        bool tokenPayment = token != address(0);

        for (uint256 i; i < marketItemData.length; ) {
            MarketItemData calldata item = marketItemData[i];

            // @note different token results in different itemHash!!!
            bytes32 itemHash = keccak256(abi.encode(marketId, item, token, receiver));

            unchecked {
                if (++totalSupply[itemHash] > item.maxSupply) revert NoSupplyLeft();
                if (block.timestamp < item.start || item.end < block.timestamp) revert NotActive();
                if (++numEntries[itemHash][msg.sender] > item.maxEntries) revert MaxEntriesReached();

                if (tokenPayment) totalPayment += item.ethPrice;
                else totalPayment += item.tokenPrice;
            }

            emit MarketItemPurchased(marketId, msg.sender, itemHash);

            unchecked {
                ++i;
            }
        }

        if (tokenPayment) {
            if (receiver == address(0)) ERC20Burnable(token).burnFrom(msg.sender, totalPayment);
            else ERC20Burnable(token).transferFrom(msg.sender, receiver, totalPayment);
        } else {
            if (receiver == address(0)) revert InvalidReceiver();
            if (msg.value != totalPayment) revert InsufficientValue();
            payable(receiver).transfer(msg.value);
        }
    }

    /* ------------- Modifier ------------- */

    modifier onlyEOA() {
        if (msg.sender != tx.origin) revert ContractCallNotAllowed();
        _;
    }
}
