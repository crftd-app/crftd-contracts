// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {WETH} from "solmate/tokens/WETH.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {utils} from "./utils/utils.sol";
import {Choice} from "./utils/Choice.sol";

error NotActive();
error NoSupplyLeft();
error NotAuthorized();
error InvalidReceiver();
error InvalidEthAmount();
error InvalidPaymentToken();
error InsufficientValue();
error MaxPurchasesReached();
error ContractCallNotAllowed();
error RandomSeedAlreadyChosen();

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

            uint256 supply = totalSupply[itemHash];

            unchecked {
                if (block.timestamp < item.start || item.expiry < block.timestamp) revert NotActive();
                if (++numPurchases[itemHash][msg.sender] > item.maxPurchases) revert MaxPurchasesReached();
                if (supply > item.maxSupply) revert NoSupplyLeft();

                totalSupply[itemHash] = supply;
            }

            address paymentToken = paymentTokens[i];

            (bool found, uint256 tokenIndex) = utils.indexOf(item.acceptedPaymentTokens, paymentToken);
            if (!found) revert InvalidPaymentToken();

            uint256 tokenPrice = item.tokenPricesStart[tokenIndex];

            // dutch auction item
            if (item.end == 0) {
                uint256 timestamp = block.timestamp > item.end ? item.end : block.timestamp;

                tokenPrice -=
                    ((item.tokenPricesStart[tokenIndex] - item.tokenPricesEnd[tokenIndex]) * (timestamp - item.start)) /
                    (item.end - item.start);
            }

            // raffle item; store id ownership
            if (item.raffleNumPrizes == 0) {
                raffleEntries[itemHash][supply] = msg.sender;
            }

            if (paymentToken == address(0)) {
                msgValue -= tokenPrice;

                weth.transfer(item.receiver, tokenPrice);
            } else {
                /// @note doesn't check for codeSize == 0, will be validated by frontend
                ERC20(paymentToken).safeTransferFrom(msg.sender, item.receiver, tokenPrice);
            }

            emit MarketItemPurchased(item.marketId, msg.sender, itemHash);
        }

        if (msgValue != 0) {
            weth.transfer(msg.sender, msgValue);
        }
    }

    /* ------------- view (off-chain) ------------- */

    function getRaffleEntrants(bytes32 itemHash) external view returns (address[] memory entrants) {
        uint256 supply = totalSupply[itemHash];

        entrants = new address[](supply);

        for (uint256 i; i < supply; ++i) entrants[i] = raffleEntries[itemHash][i + 1];
    }

    function getRaffleWinners(bytes32 itemHash, uint256 numPrizes) public view returns (address[] memory winners) {
        uint256 randomSeed = raffleRandomSeeds[itemHash];

        if (randomSeed == 0) return winners;

        uint256[] memory winnerIds = Choice.selectNOfM(numPrizes, totalSupply[itemHash], randomSeed);

        uint256 numWinners = winnerIds.length;

        winners = new address[](numWinners);

        for (uint256 i; i < numWinners; ++i) winners[i] = raffleEntries[itemHash][winnerIds[i] + 1];
    }

    /* ------------- Owner ------------- */

    function revealRaffle(MarketItem calldata item) external {
        bytes32 itemHash = keccak256(abi.encode(item));

        if (block.timestamp < item.expiry) revert NotActive();

        (bool found, ) = utils.indexOf(item.raffleControllers, msg.sender);

        if (!found) revert NotAuthorized();

        if (raffleRandomSeeds[itemHash] != 0) revert RandomSeedAlreadyChosen();

        raffleRandomSeeds[itemHash] = uint256(keccak256(abi.encode(blockhash(block.number - 1), itemHash)));
    }

    /* ------------- owner ------------- */

    function recoverToken(ERC20 token) external onlyOwner {
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }

    function recoverNFT(ERC721 token, uint256 id) external onlyOwner {
        token.transferFrom(address(this), msg.sender, id);
    }
}
