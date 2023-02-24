// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CRFTDNFT is ERC721, Ownable {
    using Counters for Counters.Counter;
    
    Counters.Counter private supply;

    constructor(
      string _name,
      string _symbol,
    ) ERC721(_name, _symbol) {}
}
