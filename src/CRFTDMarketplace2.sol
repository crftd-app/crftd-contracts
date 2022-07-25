// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {WETH} from "solmate/tokens/WETH.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {utils} from "./utils/utils.sol";

error NotActive();
error NoSupplyLeft();
error InvalidReceiver();
error InvalidEthAmount();
error InvalidPaymentToken();
error InsufficientValue();
error MaxPurchasesReached();
error ContractCallNotAllowed();

contract CRFTDMarketplace is Owned(msg.sender) {
    using SafeTransferLib for ERC20;

    WETH immutable weth;

    constructor(address payable wrappedEth) {
        weth = WETH(wrappedEth);
    }

    /* ------------- events ------------- */

    event MarketItemPurchased(uint256 indexed marketId, address indexed user, bytes32 indexed itemHash);

    /* ------------- structs ------------- */

    struct MarketItem {
        uint256 marketId;
        uint256 start;
        uint256 end;
        uint256 maxPurchases;
        uint256 maxSupply;
        address receiver;
        bytes32 dataHash;
        address[] acceptedPaymentTokens;
        uint256[] tokenPrices;
    }

    /* ------------- storage ------------- */

    /// @dev mapping from (bytes32 itemHash) => (uint256 totalSupply)
    mapping(bytes32 => uint256) public totalSupply;
    /// @dev mapping from (bytes32 itemHash) => (address user) => (uint256 numPurchases)
    mapping(bytes32 => mapping(address => uint256)) public numPurchases;

    /* ------------- external ------------- */

    function purchaseMarketItems(MarketItem[] calldata items, address[] calldata paymentTokens) external payable {
        uint256 msgValue;

        if (msg.value > 0) {
            msgValue = msg.value;
            weth.deposit{value: msg.value}();
        }

        for (uint256 i; i < items.length; ++i) {
            MarketItem calldata item = items[i];

            bytes32 itemHash = keccak256(abi.encode(item));

            unchecked {
                if (++totalSupply[itemHash] > item.maxSupply) revert NoSupplyLeft();
                if (++numPurchases[itemHash][msg.sender] > item.maxPurchases) revert MaxPurchasesReached();
                if (block.timestamp < item.start || item.end < block.timestamp) revert NotActive();
            }

            address paymentToken = paymentTokens[i];

            (bool found, uint256 tokenIndex) = utils.indexOf(item.acceptedPaymentTokens, paymentToken);

            if (!found) revert InvalidPaymentToken();

            if (paymentToken == address(0)) {
                msgValue -= item.tokenPrices[tokenIndex];
                weth.transfer(item.receiver, item.tokenPrices[tokenIndex]);
            } else {
                /// @note doesn't check for codeSize == 0, market owner's responsibility
                ERC20(paymentToken).safeTransferFrom(msg.sender, item.receiver, item.tokenPrices[tokenIndex]);
            }

            emit MarketItemPurchased(item.marketId, msg.sender, itemHash);
        }

        if (msgValue != 0) revert InvalidEthAmount();
    }

    /* ------------- owner ------------- */

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
