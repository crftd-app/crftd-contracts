// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";
import {ERC721UDS, s as erc721ds} from "UDS/tokens/ERC721UDS.sol";

import "solmate/utils/LibString.sol";
import "CRFTD/utils/utils.sol";

contract MockERC721 is UUPSUpgrade, ERC721UDS {
    string baseURI;

    uint256 public totalSupply;

    function init(
        string memory _name,
        string memory _symbol,
        string memory uri
    ) external initializer {
        __ERC721_init(_name, _symbol);

        baseURI = uri;

        for (uint256 i; i < 20; i++) mint(msg.sender);
    }

    function tokenURI(uint256 id) public view virtual override returns (string memory) {
        return string.concat(baseURI, LibString.toString(id), ".json");
    }

    function mint(address to) public virtual {
        _mint(to, ++totalSupply);
    }

    function getOwnedIds(address user) external view returns (uint256[] memory ids) {
        return utils.getOwnedIds(erc721ds().ownerOf, user, 500);
    }

    function _authorizeUpgrade() internal virtual override {}
}
