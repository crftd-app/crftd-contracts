// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20DripUDS} from "UDS/tokens/ERC20DripUDS.sol";
import {OwnableUDS} from "UDS/auth/OwnableUDS.sol";
import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";
import {LibERC1967ProxyWithImmutableArgs} from "UDS/proxy/ERC1967ProxyWithImmutableArgs.sol";

import {ERC721} from "solmate/tokens/ERC721.sol";
import {Owned} from "solmate/auth/Owned.sol";

import {utils} from "./utils/utils.sol";

error ZeroReward();
error IncorrectOwner();
error CollectionNotRegistered();
error CollectionAlreadyRegistered();

/// Minimal ERC721 staking contract for multiple collections
/// Combined ERC20 Token to avoid external calls during claim
/// @author phaze (https://github.com/0xPhaze)
contract CRFTDStakingDrip is ERC20DripUDS, UUPSUpgrade, OwnableUDS {
    event CollectionRegistered(address indexed collection, uint256 rewardRate);

    /* ------------- Storage ------------- */

    uint256 _rewardEndDate;
    mapping(address => mapping(uint256 => address)) public ownerOf;
    mapping(address => uint256) public rewardRate;

    function rewardEndDate() public view override returns (uint256) {
        return _rewardEndDate;
    }

    function rewardDailyRate() public pure override returns (uint256) {
        return 1e16; // 0.01
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

    /* ------------- O(n) Read-Only ------------- */

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

    function setRewardEndDate(uint256 endDate) external onlyOwner {
        _rewardEndDate = endDate;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /* ------------- UUPSUpgrade ------------- */

    function _authorizeUpgrade() internal override onlyOwner {}
}
