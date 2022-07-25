// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {s as erc20DS} from "UDS/tokens/ERC20UDS.sol";
import {ERC20RewardUDS} from "UDS/tokens/ERC20RewardUDS.sol";

// ------------- storage

// keccak256("diamond.storage.erc20.reward.packed") == 0xe77c083536addb2f4fadd17cf16cec8267539940ec38f787e867e3c1310b731f;
bytes32 constant DIAMOND_STORAGE_ERC20_REWARD_PACKED = 0xe77c083536addb2f4fadd17cf16cec8267539940ec38f787e867e3c1310b731f;

function s() pure returns (ERC20RewardPackedDS storage diamondStorage) {
    assembly { diamondStorage.slot := DIAMOND_STORAGE_ERC20_REWARD_PACKED } // prettier-ignore
}

struct ERC20RewardPackedDS {
    uint40 rewardEndDate;
    uint216 totalSupply;
}

/// Minimal ERC721 staking contract for multiple collections
/// Combined ERC20 Token to avoid external calls during claim
/// @author phaze (https://github.com/0xPhaze)
abstract contract ERC20RewardPackedUDS is ERC20RewardUDS {
    /* ------------- init ------------- */

    function __ERC20RewardPacked_init(uint40 endDate) internal initializer {
        s().rewardEndDate = endDate;
    }

    /* ------------- view ------------- */

    function rewardEndDate() public view virtual override returns (uint256) {
        return s().rewardEndDate;
    }

    function totalSupply() external view virtual override returns (uint256) {
        return s().totalSupply;
    }

    /* ------------- internal ------------- */

    function _setRewardEndDate(uint40 endDate) internal {
        s().rewardEndDate = endDate;
    }

    function _mint(address to, uint256 amount) internal virtual override {
        if (amount > type(uint216).max) revert();

        s().totalSupply += uint216(amount);

        unchecked {
            erc20DS().balanceOf[to] += amount;
        }

        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal virtual override {
        if (amount > type(uint216).max) revert();

        erc20DS().balanceOf[from] -= amount;

        unchecked {
            s().totalSupply -= uint216(amount);
        }

        emit Transfer(from, address(0), amount);
    }
}
