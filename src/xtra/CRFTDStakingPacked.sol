// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20RewardPackedUDS} from "./ERC20RewardPacked.sol";
import {OwnableUDS} from "UDS/auth/OwnableUDS.sol";
import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";

import {ERC721} from "solmate/tokens/ERC721.sol";
import {Owned} from "solmate/auth/Owned.sol";

import {utils} from "../utils/utils.sol";

error ZeroReward();
error IncorrectOwner();
error CollectionNotRegistered();
error CollectionAlreadyRegistered();

/// Minimal ERC721 staking contract for multiple collections
/// Combined ERC20 Token to avoid external calls during claim
/// @author phaze (https://github.com/0xPhaze)
contract CRFTDStakingToken is ERC20RewardPackedUDS, UUPSUpgrade, OwnableUDS {
    event CollectionRegistered(address indexed collection, uint256 rewardRate);

    mapping(address => uint256) public rewardRate;
    mapping(address => mapping(uint256 => address)) public ownerOf;

    /* ------------- init ------------- */

    function init(
        string calldata name,
        string calldata symbol,
        uint8 decimals
    ) public initializer {
        __Ownable_init();
        __ERC20_init(name, symbol, decimals);
    }

    /* ------------- pure ------------- */

    function rewardDailyRate() public pure override returns (uint256) {
        return 1e16;
    }

    /* ------------- external ------------- */

    function stake(address collection, uint256[] calldata tokenIds) external {
        uint256 rate = rewardRate[collection];

        if (rate == 0) revert CollectionNotRegistered();

        _increaseRewardMultiplier(msg.sender, uint160(tokenIds.length * rate));

        for (uint256 i; i < tokenIds.length; ++i) {
            ERC721(collection).transferFrom(msg.sender, address(this), tokenIds[i]);

            ownerOf[collection][tokenIds[i]] = msg.sender;
        }
    }

    function unstake(address collection, uint256[] calldata tokenIds) external {
        uint256 rate = rewardRate[collection];

        if (rate == 0) revert CollectionNotRegistered();

        _decreaseRewardMultiplier(msg.sender, uint160(tokenIds.length));

        for (uint256 i; i < tokenIds.length; ++i) {
            if (ownerOf[collection][tokenIds[i]] != msg.sender) revert IncorrectOwner();

            delete ownerOf[collection][tokenIds[i]];

            ERC721(collection).transferFrom(address(this), msg.sender, tokenIds[i]);
        }
    }

    function claimVirtualBalance() external {
        _claimVirtualBalance(msg.sender);
    }

    /* ------------- O(n) read-only ------------- */

    function stakedTokenIdsOf(
        address collection,
        address user,
        uint256 collectionSize
    ) external view returns (uint256[] memory stakedIds) {
        return utils.getOwnedIds(ownerOf[collection], user, collectionSize);
    }

    /* ------------- owner ------------- */

    function registerCollection(address collection, uint200 rate) external onlyOwner {
        if (rate == 0) revert ZeroReward();
        if (rewardRate[collection] != 0) revert CollectionAlreadyRegistered();

        rewardRate[collection] = rate;

        emit CollectionRegistered(collection, rate);
    }

    function setRewardEndDate(uint40 endDate) external onlyOwner {
        _setRewardEndDate(endDate);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /* ------------- UUPSUpgrade ------------- */

    function _authorizeUpgrade() internal override onlyOwner {}
}
