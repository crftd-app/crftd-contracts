// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20RewardUDS} from "UDS/tokens/ERC20RewardUDS.sol";
import {OwnableUDS} from "UDS/auth/OwnableUDS.sol";
import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";

import {ERC721} from "solmate/tokens/ERC721.sol";
import {Owned} from "solmate/auth/Owned.sol";

import {utils} from "./utils/utils.sol";

// ------------- storage

// keccak256("diamond.storage.crftd.token") == 0x0e539be85842d1c3b5b43263a827c1e07ab5a9c9536bf840ece723e480d80db7;
bytes32 constant DIAMOND_STORAGE_CRFTD_TOKEN = 0x0e539be85842d1c3b5b43263a827c1e07ab5a9c9536bf840ece723e480d80db7;

function s() pure returns (CRFTDTokenDS storage diamondStorage) {
    assembly { diamondStorage.slot := DIAMOND_STORAGE_CRFTD_TOKEN } // prettier-ignore
}

struct CRFTDTokenDS {
    uint256 rewardEndDate;
    mapping(address => uint256) rewardRate;
    mapping(address => mapping(uint256 => address)) ownerOf;
}

// ------------- errors

error ZeroReward();
error IncorrectOwner();
error CollectionNotRegistered();
error CollectionAlreadyRegistered();

/// @title CRFTDStakingToken
/// @author phaze (https://github.com/0xPhaze)
/// @notice Minimal ERC721 staking contract supporting multiple collections
/// @notice Combines ERC20 Token to avoid external calls
contract CRFTDStakingToken is ERC20RewardUDS, UUPSUpgrade, OwnableUDS {
    event CollectionRegistered(address indexed collection, uint256 rewardRate);

    /* ------------- init ------------- */

    function init(
        string calldata name,
        string calldata symbol,
        uint8 decimals,
        address callAddr,
        bytes[] calldata calls
    ) external initializer {
        __Ownable_init();
        __ERC20_init(name, symbol, decimals);

        utils.delegatecalls(callAddr, calls);
    }

    /* ------------- public ------------- */

    function rewardEndDate() public view override returns (uint256) {
        return s().rewardEndDate;
    }

    function rewardDailyRate() public pure override returns (uint256) {
        return 1e16;
    }

    function rewardRate(address collection) public view returns (uint256) {
        return s().rewardRate[collection];
    }

    function ownerOf(address collection, uint256 id) public view returns (address) {
        return s().ownerOf[collection][id];
    }

    /* ------------- external ------------- */

    function stake(address collection, uint256[] calldata tokenIds) external {
        uint256 rate = s().rewardRate[collection];

        if (rate == 0) revert CollectionNotRegistered();

        _increaseRewardMultiplier(msg.sender, uint216(tokenIds.length * rate));

        for (uint256 i; i < tokenIds.length; ++i) {
            ERC721(collection).transferFrom(msg.sender, address(this), tokenIds[i]);

            s().ownerOf[collection][tokenIds[i]] = msg.sender;
        }
    }

    function unstake(address collection, uint256[] calldata tokenIds) external {
        uint256 rate = s().rewardRate[collection];

        if (rate == 0) revert CollectionNotRegistered();

        _decreaseRewardMultiplier(msg.sender, uint216(tokenIds.length * rate));

        for (uint256 i; i < tokenIds.length; ++i) {
            if (s().ownerOf[collection][tokenIds[i]] != msg.sender) revert IncorrectOwner();

            delete s().ownerOf[collection][tokenIds[i]];

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
        return utils.getOwnedIds(s().ownerOf[collection], user, collectionSize);
    }

    /* ------------- owner ------------- */

    function registerCollection(address collection, uint200 rate) external onlyOwner {
        if (rate == 0) revert ZeroReward();
        if (s().rewardRate[collection] != 0) revert CollectionAlreadyRegistered();

        s().rewardRate[collection] = rate;

        emit CollectionRegistered(collection, rate);
    }

    function setRewardEndDate(uint256 endDate) external onlyOwner {
        s().rewardEndDate = endDate;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /* ------------- UUPSUpgrade ------------- */

    function _authorizeUpgrade() internal override onlyOwner {}
}
