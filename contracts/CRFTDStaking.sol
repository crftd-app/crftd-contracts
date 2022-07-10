// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC721} from "solmate/tokens/ERC721.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {Owned} from "solmate/auth/Owned.sol";

error IncorrectOwner();

/// Minimal ERC721 staking contract
/// Combined ERC20 Token to avoid external calls during claim
/// @author phaze (https://github.com/0xPhaze/ERC721M)
contract CRFTDStakingToken is ERC20("Token", "TKN", 18) {
    /* ------------- Structs ------------- */

    struct StakeData {
        uint128 numStaked;
        uint128 lastClaimed;
    }

    /* ------------- Storage ------------- */

    mapping(uint256 => address) public ownerOf;
    mapping(address => StakeData) public stakeData;

    ERC721 immutable nft;

    constructor(ERC721 nft_) {
        nft = nft_;
    }

    /* ------------- View ------------- */

    function pendingReward(address user) public view returns (uint256) {
        unchecked {
            return (stakeData[user].numStaked * 1e18 * (block.timestamp - stakeData[user].lastClaimed)) / (1 days);
        }
    }

    function numStaked(address user) external view returns (uint256) {
        return stakeData[user].numStaked;
    }

    function numOwned(address user) external view returns (uint256) {
        return nft.balanceOf(user) + stakeData[user].numStaked;
    }

    function totalNumStaked() external view returns (uint256) {
        return nft.balanceOf(address(this));
    }

    /* ------------- External ------------- */

    function stake(uint256[] calldata tokenIds) external {
        unchecked {
            claimReward();

            for (uint256 i; i < tokenIds.length; ++i) {
                nft.transferFrom(msg.sender, address(this), tokenIds[i]);

                ownerOf[tokenIds[i]] = msg.sender;
            }

            stakeData[msg.sender].numStaked += uint128(tokenIds.length);
        }
    }

    function unstake(uint256[] calldata tokenIds) external {
        unchecked {
            claimReward();

            for (uint256 i; i < tokenIds.length; ++i) {
                if (ownerOf[tokenIds[i]] != msg.sender) revert IncorrectOwner();

                delete ownerOf[tokenIds[i]];

                nft.transferFrom(address(this), msg.sender, tokenIds[i]);
            }

            stakeData[msg.sender].numStaked -= uint128(tokenIds.length);
        }
    }

    function claimReward() public {
        uint256 reward = pendingReward(msg.sender);

        _mint(msg.sender, reward);

        stakeData[msg.sender].lastClaimed = uint128(block.timestamp);
    }

    /* ------------- O(n) Read-Only ------------- */

    function stakedTokenIdsOf(address user) external view returns (uint256[] memory) {
        uint256 staked = stakeData[user].numStaked;

        uint256[] memory stakedIds = new uint256[](staked);

        if (staked != 0) {
            uint256 count;

            for (uint256 id = 1; id < 3888 + 1; ++id) {
                if (ownerOf[id] == user) {
                    stakedIds[count++] = id;

                    if (staked == count) break;
                }
            }
        }

        return stakedIds;
    }
}
