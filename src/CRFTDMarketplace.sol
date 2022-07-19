// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {WETH} from "solmate/tokens/WETH.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

WETH constant wrappedEther = WETH(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));

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

    /* ------------- Events ------------- */

    event MarketItemPurchased(uint256 indexed marketId, address indexed user, bytes32 indexed itemHash);

    /* ------------- Structs ------------- */

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

    /* ------------- Storage ------------- */

    /// @dev mapping from (bytes32 itemHash) => (uint256 totalSupply)
    mapping(bytes32 => uint256) public totalSupply;
    /// @dev mapping from (bytes32 itemHash) => (address user) => (uint256 numPurchases)
    mapping(bytes32 => mapping(address => uint256)) public numPurchases;

    /* ------------- Utils ------------- */

    function indexOf(address[] calldata arr, address addr) internal pure returns (bool found, uint256 index) {
        unchecked {
            for (uint256 i; i < arr.length; ++i) if (arr[i] == addr) return (true, i);
        }
        return (false, 0);
    }

    /* ------------- External ------------- */

    function purchaseMarketItems(MarketItem[] calldata items, address[] calldata paymentTokens) external payable {
        uint256 depositedEth;

        if (msg.value > 0) {
            depositedEth = msg.value;
            wrappedEther.deposit{value: msg.value}();
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

            (bool found, uint256 tokenIndex) = indexOf(item.acceptedPaymentTokens, paymentToken);

            if (!found) revert InvalidPaymentToken();

            if (paymentToken == address(0)) {
                depositedEth -= item.tokenPrices[tokenIndex];
                wrappedEther.transfer(item.receiver, item.tokenPrices[tokenIndex]);
            } else {
                /// @note doesn't check for codeSize == 0, market owner's responsibility
                ERC20(paymentToken).safeTransferFrom(msg.sender, item.receiver, item.tokenPrices[tokenIndex]);
            }

            emit MarketItemPurchased(item.marketId, msg.sender, itemHash);
        }

        if (depositedEth != 0) revert InvalidEthAmount();
    }

    /* ------------- Owner ------------- */

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
