// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CRFTDNFT is ERC721Enumerable, Ownable {
    using Counters for Counters.Counter;
    
    Counters.Counter private supply;

    uint256 public maxTotalSupply;
    uint256 public mintPrice;
    uint256 public globalMaxMintPerWallet;
    uint256 public maxMintPerWallet;
    uint256 public maxMintPerTransaction;

    constructor(
      string _name,
      string _symbol,
      uint256 _maxTotalSupply,
      uint256 _mintPrice,
      uint256 _globalMaxMintPerWallet,
      uint256 _maxMintPerWallet,
      uint256 _maxMintPerTransaction,
    ) ERC721(_name, _symbol) {
      require(_mintPrice > 0, 'MINT PRICE CAN NOT BE ZERO');
      maxTotalSupply = _maxTotalSupply;
      mintPrice = _mintPrice;
      globalMaxMintPerWallet = _globalMaxMintPerWallet;
      maxMintPerWallet = _maxMintPerWallet;
      maxMintPerTransaction = _maxMintPerTransaction;
    }

    function totalSupply() public view override returns (uint256) {
        return supply.current();
    }

    function mint(uint256 amount) public {
      require(amount > 0, 'AMOUNT CANNOT BE 0');
      require(amount <= maxMintPerTransaction || maxMintPerTransaction == 0, 'EXCEED MAX MINT PER TRANSACTION');
      if (globalMaxMintPerWallet > 0) {
        require(balanceOf(msg.sender) + amount < globalMaxMintPerWallet, 'EXCEED GLOBAL MAX MINT PER WALLET');
      } else {
        require(balanceOf(msg.sender) + amount < maxMintPerWallet, 'EXCEED MAX MINT PER WALLET');
      }
      require(totalSupply() + amount <= maxTotalSupply, 'SALE ALREADY ENDED');
      require(mintPrice * amount == msg.value, 'INVALID ETHER VALUE');

      for (uint i = 0; i < amount; i++) {
        supply.increment();
        uint256 tokenId = supply.current();
        _safeMint(msg.sender, tokenId);
      }
    }

    function setMintPrice(uint256 _newPrice) external {
      require(_newPrice > 0, 'MINT PRICE CAN NOT BE ZERO');
      mintPrice = _newPrice;
    }

    function setGlobalMaxMintPerWallet(uint256 _newMaxMint) {
      globalMaxMintPerWallet = _newMaxMint;
    }

    function setMaxMintPerWallet(uint256 _newMaxMint) {
      maxMintPerWallet = _newMaxMint;
    }

    function setMaxMintPerTransaction(uint256 _newMaxMint) {
      maxMintPerTransaction = _newMaxMint;
    }
}
