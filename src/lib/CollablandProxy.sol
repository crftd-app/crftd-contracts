// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC721UDS} from "UDS/tokens/ERC721UDS.sol";
import {CRFTDStakingToken} from "../CRFTDStakingTokenRoot.sol";

/// @title Collabland Proxy
/// @author phaze (https://github.com/0xPhaze)
contract CollablandProxy {
    address immutable token;
    address immutable staking;
    uint256 maxSupply;

    constructor(
        address token_,
        address staking_,
        uint256 maxSupply_
    ) {
        token = token_;
        staking = staking_;
        maxSupply = maxSupply_;
    }

    function balanceOf(address user) public view returns (uint256) {
        return ERC721UDS(token).balanceOf(user) + CRFTDStakingToken(staking).stakedIdsOf(token, user, maxSupply).length;
    }
}
