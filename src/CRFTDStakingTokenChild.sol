// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {utils} from "./lib/utils.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {ERC20UDS} from "UDS/tokens/ERC20UDS.sol";
import {OwnableUDS} from "UDS/auth/OwnableUDS.sol";
import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";
import {Multicallable} from "UDS/utils/Multicallable.sol";
import {FxERC721sChild} from "fx-contracts/FxERC721sChild.sol";
import {ERC20RewardUDS} from "UDS/tokens/extensions/ERC20RewardUDS.sol";
import {FxERC721sEnumerableChild} from "fx-contracts/extensions/FxERC721sEnumerableChild.sol";
import {REGISTER_ERC721_IDS_SELECTOR} from "fx-contracts/FxERC721Root.sol";
import {FxERC20UDSChild, MINT_ERC20_SELECTOR} from "fx-contracts/FxERC20UDSChild.sol";

// ------------- storage

/// @dev diamond storage slot `keccak256("diamond.storage.crftd.token.child")`
bytes32 constant DIAMOND_STORAGE_CRFTD_TOKEN_CHILD = 0x2e5e5d1b22fb9bd55c0f1dd4d407243feb0b09e738fecfb81a9a8cb66b229d26;

function s() pure returns (CRFTDTokenChildDS storage diamondStorage) {
    bytes32 slot = DIAMOND_STORAGE_CRFTD_TOKEN_CHILD;
    assembly {
        diamondStorage.slot := slot
    }
}

struct CRFTDTokenChildDS {
    uint256 rewardEndDate;
    mapping(address => uint256) rewardRate;
    mapping(address => mapping(uint256 => address)) ownerOf;
    mapping(address => mapping(uint256 => uint256)) specialRewardRate;
}

// ------------- errors

error ZeroReward();
error InvalidSelector();
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
contract CRFTDStakingToken is FxERC721sEnumerableChild, ERC20RewardUDS, OwnableUDS, UUPSUpgrade, Multicallable {
    event CollectionRegistered(address indexed collection, uint256 rewardRate);

    constructor(address fxChild) FxERC721sEnumerableChild(fxChild) {
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
        return 0.01e18;
    }

    function rewardRate(address collection) public view returns (uint256) {
        return s().rewardRate[collection];
    }

    function specialRewardRate(address collection, uint256 id) public view returns (uint256) {
        return s().specialRewardRate[collection][id];
    }

    function getRewardRate(address collection, uint256 id) public view returns (uint256) {
        uint256 specialRate = s().specialRewardRate[collection][id];

        return (specialRate == 0) ? s().rewardRate[collection] : specialRate;
    }

    function getDailyReward(address user) public view returns (uint256) {
        return _getRewardMultiplier(user) * rewardDailyRate();
    }

    function stakedIdsOf(address collection, address user, uint256) external view returns (uint256[] memory) {
        return FxERC721sEnumerableChild.getOwnedIds(collection, user);
    }

    /* ------------- external ------------- */

    function claimReward() external {
        _claimReward(msg.sender);
    }

    /* ------------- internal ------------- */

    function _processMessageFromRoot(uint256 stateId, address rootMessageSender, bytes calldata message)
        internal
        virtual
        override
    {
        bytes4 selector = bytes4(message);

        if (selector == MINT_ERC20_SELECTOR) {
            (address to, uint256 amount) = abi.decode(message[4:], (address, uint256));

            _mint(to, amount);
        } else {
            FxERC721sChild._processMessageFromRoot(stateId, rootMessageSender, message);
        }
    }

    /* ------------- erc20 ------------- */

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        _claimReward(msg.sender);

        return ERC20UDS.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        _claimReward(from);

        return ERC20UDS.transferFrom(from, to, amount);
    }

    /* ------------- hooks ------------- */

    function _afterIdRegistered(address collection, address from, address to, uint256 id) internal virtual override {
        super._afterIdRegistered(collection, from, to, id);

        uint256 rate = getRewardRate(collection, id);

        if (from != address(0)) {
            _decreaseRewardMultiplier(from, uint216(rate));
        }
        if (to != address(0)) {
            _increaseRewardMultiplier(to, uint216(rate));
        }
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

    function setSpecialRewardRate(address collection, uint256[] calldata ids, uint256[] calldata rates)
        external
        onlyOwner
    {
        for (uint256 i; i < ids.length; ++i) {
            address owner = ownerOf(collection, ids[i]);

            if (owner != address(0)) {
                uint256 oldRate = getRewardRate(collection, ids[i]);

                _decreaseRewardMultiplier(owner, uint216(oldRate));
                _increaseRewardMultiplier(owner, uint216(rates[i]));
            }

            s().specialRewardRate[collection][ids[i]] = rates[i];
        }
    }

    function airdrop(address[] calldata tos, uint256 amount) external onlyOwner {
        for (uint256 i; i < tos.length; ++i) {
            _mint(tos[i], amount);
        }
    }

    function airdrop(address[] calldata tos, uint256[] calldata amounts) external onlyOwner {
        for (uint256 i; i < tos.length; ++i) {
            _mint(tos[i], amounts[i]);
        }
    }

    /* ------------- override ------------- */

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function _authorizeTunnelController() internal override onlyOwner {}
}
