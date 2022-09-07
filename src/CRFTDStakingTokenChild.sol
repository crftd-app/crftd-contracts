// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {utils} from "./utils/utils.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {ERC20UDS} from "UDS/tokens/ERC20UDS.sol";
import {OwnableUDS} from "UDS/auth/OwnableUDS.sol";
import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";
import {MINT_ERC20_SIG} from "fx-contracts/FxERC20RootUDS.sol";
import {ERC20RewardUDS} from "UDS/tokens/extensions/ERC20RewardUDS.sol";
import {FxERC721sEnumerableChildTunnelUDS} from "fx-contracts/extensions/FxERC721sEnumerableChildTunnelUDS.sol";

// ------------- storage

bytes32 constant DIAMOND_STORAGE_CRFTD_TOKEN = keccak256("diamond.storage.crftd.token");

function s() pure returns (CRFTDTokenDS storage diamondStorage) {
    bytes32 slot = DIAMOND_STORAGE_CRFTD_TOKEN;
    assembly { diamondStorage.slot := slot } // prettier-ignore
}

struct CRFTDTokenDS {
    uint256 rewardEndDate;
    mapping(address => uint256) rewardRate;
    mapping(address => mapping(uint256 => address)) ownerOf;
}

// ------------- errors

error ZeroReward();
error CollectionAlreadyRegistered();

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

/// @title CRFTDStakingToken (Cross-Chain Registry)
/// @author phaze (https://github.com/0xPhaze)
/// @notice Minimal ERC721 staking contract supporting multiple collections
/// @notice Relays id ownership to ERC20 Token on L2
contract CRFTDStakingToken is FxERC721sEnumerableChildTunnelUDS, ERC20RewardUDS, OwnableUDS, UUPSUpgrade {
    event CollectionRegistered(address indexed collection, uint256 rewardRate);

    constructor(address fxChild) FxERC721sEnumerableChildTunnelUDS(fxChild) {
        __ERC20_init("CRFTD", "CRFTD", 18);
    }

    /* ------------- init ------------- */

    function init(string calldata name, string calldata symbol) external initializer {
        __Ownable_init();
        __ERC20_init(name, symbol, 18);
    }

    /* ------------- view ------------- */

    function rewardEndDate() public view override returns (uint256) {
        return s().rewardEndDate;
    }

    function rewardDailyRate() public pure override returns (uint256) {
        return 1e16; // 0.01
    }

    function rewardRate(address collection) public view returns (uint256) {
        return s().rewardRate[collection];
    }

    function getDailyReward(address user) public view returns (uint256) {
        return _getRewardMultiplier(user) * rewardDailyRate();
    }

    /* ------------- external ------------- */

    function claimReward() external {
        _claimReward(msg.sender);
    }

    /* ------------- internal ------------- */

    function _processSignature(bytes32 signature, bytes memory data) internal override returns (bool) {
        if (signature == MINT_ERC20_SIG) {
            (address to, uint256 amount) = abi.decode(data, (address, uint256));

            _mint(to, amount);

            return true;
        }
        return false;
    }

    /* ------------- erc20 ------------- */

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        _claimReward(msg.sender);

        return ERC20UDS.transfer(to, amount);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        _claimReward(from);

        return ERC20UDS.transferFrom(from, to, amount);
    }

    /* ------------- hooks ------------- */

    // function _afterIdRegistered(
    //     address collection,
    //     address to,
    //     uint256 id
    // ) internal override {}

    // function _afterIdDeregistered(
    //     address collection,
    //     address from,
    //     uint256 id
    // ) internal override {}

    /* ------------- O(n) read-only ------------- */

    function stakedIdsOf(
        address collection,
        address user,
        uint256
    ) external view returns (uint256[] memory) {
        return FxERC721sEnumerableChildTunnelUDS.getOwnedIds(collection, user);
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

    function airdrop(address[] calldata tos, uint256[] calldata amounts) external onlyOwner {
        for (uint256 i; i < tos.length; ++i) _mint(tos[i], amounts[i]);
    }

    /* ------------- override ------------- */

    function _authorizeUpgrade() internal override onlyOwner {}

    function _authorizeTunnelController() internal override onlyOwner {}
}
