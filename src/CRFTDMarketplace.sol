// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {utils} from "./lib/utils.sol";
import {choice} from "./lib/choice.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

// ------------- errors

error NotActive();
error NoSupplyLeft();
error InvalidOrder();
error NotAuthorized();
error InvalidSigner();
error InvalidReceiver();
error DeadlineExpired();
error InvalidEthAmount();
error InsufficientValue();
error InvalidPaymentToken();
error MaxPurchasesReached();
error InvalidMarketItemHash();
error ContractCallNotAllowed();
error RandomSeedAlreadyChosen();
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

/// @title CRFTDMarketplace
/// @author phaze (https://github.com/0xPhaze)
/// @notice Marketplace that supports purchasing limited off-chain items
contract CRFTDMarketplace is Owned(msg.sender) {
    using SafeTransferLib for ERC20;

    uint256 immutable INITIAL_CHAIN_ID;
    bytes32 immutable INITIAL_DOMAIN_SEPARATOR;
    bytes32 immutable MARKET_ORDER_TYPE_HASH;

    /* ------------- events ------------- */

    event MarketItemPurchased(
        uint256 indexed marketId,
        bytes32 indexed itemHash,
        address indexed account,
        bytes32 buyerHash,
        address paymentToken,
        uint256 price
    );

    /* ------------- structs ------------- */

    struct ERC20Permit {
        ERC20 token;
        address owner;
        uint256 value;
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    struct MarketOrderPermit {
        address buyer;
        bytes32[] itemHashes;
        address[] paymentTokens;
        bytes32 buyerHash;
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    struct MarketItem {
        uint256 marketId;
        uint256 start;
        uint256 end;
        uint256 expiry;
        uint256 maxPurchases;
        uint256 maxSupply;
        uint256 raffleNumPrizes;
        address[] raffleControllers;
        address receiver;
        bytes32 dataHash;
        address[] acceptedPaymentTokens;
        uint256[] tokenPricesStart;
        uint256[] tokenPricesEnd;
    }

    /* ------------- storage ------------- */

    /// @dev (bytes32 itemHash) => (uint256 totalSupply)
    mapping(bytes32 => uint256) public totalSupply;
    /// @dev (bytes32 itemHash) => (address user) => (uint256 numPurchases)
    mapping(bytes32 => mapping(address => uint256)) public numPurchases;
    /// @dev (bytes32 itemHash) => (uint256 tokenId) => (address user)
    mapping(bytes32 => mapping(uint256 => address)) public raffleEntries;
    /// @dev (bytes32 itemHash) => (uint256 seed)
    mapping(bytes32 => uint256) public raffleRandomSeeds;
    /// @dev (address token) => (bool approved)
    mapping(address => bool) public isAcceptedPaymentToken;
    /// @dev EIP2612 nonces
    mapping(address => uint256) public nonces;

    constructor() {
        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();
        MARKET_ORDER_TYPE_HASH = keccak256(
            "MarketOrder(address buyer,bytes32[] itemHashes,address[] paymentTokens,bytes32 buyerHash,uint256 nonce,uint256 deadline)"
        );
    }

    /* ------------- EIP712 ------------- */

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : computeDomainSeparator();
    }

    function computeDomainSeparator() internal view virtual returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("CRFTDMarketplace"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
    }

    /* ------------- external ------------- */

    function purchaseMarketItems(MarketItem[] calldata items, address[] calldata paymentTokens, bytes32 buyerHash)
        public
        payable
    {
        // Make sure only approved tokens are being used.
        for (uint256 i; i < paymentTokens.length; ++i) {
            if (address(paymentTokens[i]).code.length == 0) revert InvalidPaymentToken();
        }

        _purchaseMarketItems(msg.sender, buyerHash, items, paymentTokens, new bytes32[](0));
    }

    function purchaseMarketItemsWithPermit(
        ERC20Permit[] calldata tokenPermits,
        MarketOrderPermit calldata orderPermit,
        MarketItem[] calldata items
    ) public {
        // Use ERC20 permits if provided.
        if (tokenPermits.length != 0) usePermits(tokenPermits);

        _validateOrder(orderPermit);

        _purchaseMarketItems(
            orderPermit.buyer, orderPermit.buyerHash, items, orderPermit.paymentTokens, orderPermit.itemHashes
        );
    }

    function purchaseMarketItemsWithPermitSafe(
        ERC20Permit[] calldata tokenPermits,
        MarketOrderPermit calldata orderPermit,
        MarketItem[] calldata items
    ) public {
        // Make sure only approved tokens are being used.
        for (uint256 i; i < orderPermit.paymentTokens.length; ++i) {
            if (!isAcceptedPaymentToken[orderPermit.paymentTokens[i]]) revert InvalidPaymentToken();
        }

        purchaseMarketItemsWithPermit(tokenPermits, orderPermit, items);
    }

    function usePermits(ERC20Permit[] calldata permits) public {
        for (uint256 i; i < permits.length; ++i) {
            ERC20Permit calldata permit = permits[i];

            permit.token.permit(
                permit.owner, address(this), permit.value, permit.deadline, permit.v, permit.r, permit.s
            );
        }
    }

    /* ------------- internal ------------- */

    function _purchaseMarketItems(
        address buyer,
        bytes32 buyerHash,
        MarketItem[] calldata items,
        address[] calldata paymentTokens,
        bytes32[] memory itemHashes
    ) private {
        unchecked {
            uint256 msgValue = msg.value;
            // If item hashes are provided, we need
            // to make sure to validate them.
            bool validateItemHashes = itemHashes.length != 0;

            for (uint256 i; i < items.length; ++i) {
                MarketItem calldata item = items[i];

                // Retrieve item's hash.
                bytes32 itemHash = keccak256(abi.encode(item));
                if (validateItemHashes && itemHashes[i] != itemHash) revert InvalidMarketItemHash();

                {
                    // Stack too deep in my ass.
                    // Get current total supply increased by `1`.
                    uint256 supply = ++totalSupply[itemHash];

                    // If it's a raffle, store raffle ticket ownership.
                    if (item.raffleNumPrizes != 0) raffleEntries[itemHash][supply] = buyer;

                    // Validate timestamp and supply.
                    if (block.timestamp < item.start || item.expiry < block.timestamp) revert NotActive();
                    if (++numPurchases[itemHash][buyer] > item.maxPurchases) revert MaxPurchasesReached();
                    if (supply > item.maxSupply) revert NoSupplyLeft();
                }

                // address paymentToken = paymentTokens[i];
                uint256 price;
                {
                    // Get token payment method and price.
                    (bool found, uint256 tokenIndex) = utils.indexOf(item.acceptedPaymentTokens, paymentTokens[i]);
                    if (!found) revert InvalidPaymentToken();

                    price = getItemPrice(item, tokenIndex);
                }

                // Handle token payment.
                if (paymentTokens[i] == address(0)) {
                    if (msgValue < price) revert InvalidEthAmount();

                    msgValue -= price; // Reduce `msgValue` balance.

                    payable(item.receiver).transfer(price); // Transfer ether to `receiver`.
                } else {
                    // Transfer tokens to receiver.
                    ERC20(paymentTokens[i]).safeTransferFrom(buyer, item.receiver, price);
                }

                emit MarketItemPurchased(item.marketId, itemHash, buyer, buyerHash, paymentTokens[i], price);
            }

            // Transfer any remaining value back.
            if (msg.sender == tx.origin && msgValue != 0) payable(msg.sender).transfer(msgValue);
        }
    }

    function _validateOrder(MarketOrderPermit calldata orderPermit) internal {
        // Validate order permit.
        if (orderPermit.itemHashes.length == 0) revert InvalidOrder();
        if (orderPermit.itemHashes.length != orderPermit.paymentTokens.length) revert InvalidOrder();
        if (orderPermit.deadline < block.timestamp) revert DeadlineExpired();

        bytes32 orderHash = keccak256(
            abi.encode(
                MARKET_ORDER_TYPE_HASH,
                orderPermit.buyer,
                keccak256(abi.encodePacked(orderPermit.itemHashes)),
                keccak256(abi.encodePacked(orderPermit.paymentTokens)),
                orderPermit.buyerHash,
                nonces[orderPermit.buyer]++,
                orderPermit.deadline
            )
        );

        // Recover signer.
        address recovered = ecrecover(
            keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR(), orderHash)),
            orderPermit.v,
            orderPermit.r,
            orderPermit.s
        );

        if (recovered == address(0) || recovered != orderPermit.buyer) revert InvalidSigner();
    }

    /* ------------- view (off-chain) ------------- */

    function getItemPrice(MarketItem calldata item, uint256 tokenIndex) public view returns (uint256 price) {
        price = item.tokenPricesStart[tokenIndex];

        // If the end is `!= 0` it is a dutch auction.
        if (item.end != 0) {
            // Clamp timestamp if it's outside of the range.
            uint256 timestamp =
                block.timestamp > item.end ? item.end : block.timestamp < item.start ? item.start : block.timestamp;

            // Linearly interpolate the price.
            // Safecasting is for losers.
            price = uint256(
                int256(price)
                    - (
                        (int256(item.tokenPricesStart[tokenIndex]) - int256(item.tokenPricesEnd[tokenIndex]))
                            * int256(timestamp - item.start)
                    ) / int256(item.end - item.start)
            );
        }
    }

    function getRaffleEntrants(bytes32 itemHash) external view returns (address[] memory entrants) {
        uint256 supply = totalSupply[itemHash];

        // Create address array of entrants.
        entrants = new address[](supply);

        // Loop over supply size and add to array.
        for (uint256 i; i < supply; ++i) {
            entrants[i] = raffleEntries[itemHash][i + 1];
        }
    }

    function getRaffleWinners(bytes32 itemHash, uint256 numPrizes) public view returns (address[] memory winners) {
        // Retrieve the random seed set for this raffle.
        uint256 randomSeed = raffleRandomSeeds[itemHash];
        // Make sure it is not the default `0`.
        if (randomSeed == 0) return winners;

        // Choose the winning ids.
        uint256[] memory winnerIds = choice.selectNOfM(numPrizes, totalSupply[itemHash], randomSeed);

        // Map winning ids to participating addresses.
        uint256 numWinners = winnerIds.length;
        winners = new address[](numWinners);

        for (uint256 i; i < numWinners; ++i) {
            winners[i] = raffleEntries[itemHash][winnerIds[i] + 1];
        }
    }

    /* ------------- restricted ------------- */

    function revealRaffle(MarketItem calldata item) external {
        // Compute item hash.
        bytes32 itemHash = keccak256(abi.encode(item));

        // Must be after raffle expiry time.
        if (block.timestamp < item.expiry) revert NotActive();

        // Make sure the caller is a controller.
        (bool found,) = utils.indexOf(item.raffleControllers, msg.sender);
        if (!found) revert NotAuthorized();

        // Only set the seed once.
        if (raffleRandomSeeds[itemHash] != 0) revert RandomSeedAlreadyChosen();

        // Cheap keccak randomness which can only be influenced by owner.
        raffleRandomSeeds[itemHash] = uint256(keccak256(abi.encode(blockhash(block.number - 1), itemHash)));
    }

    /* ------------- owner ------------- */

    function recoverToken(ERC20 token) external onlyOwner {
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }

    function recoverNFT(ERC721 token, uint256 id) external onlyOwner {
        token.transferFrom(address(this), msg.sender, id);
    }

    function setAcceptedPaymentToken(address token, bool accept) external onlyOwner {
        isAcceptedPaymentToken[token] = accept;
    }
}
