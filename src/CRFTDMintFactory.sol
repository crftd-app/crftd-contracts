// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract CRFTDMintFactory is ERC721Enumerable, Ownable {
    using Counters for Counters.Counter;
    using SafeMath for uint256;

    Counters.Counter private supply;

    uint256 public maxTotalSupply;
    uint256 public mintPrice;
    uint256 public globalMaxMintPerWallet;
    uint256 public maxMintPerWallet;
    uint256 public maxMintPerTransaction;
    address[] public revenueAddresses;
    uint256[] public revenuePercents;
    address public CRFTDWalletAddress;

    constructor(
        string _name,
        string _symbol,
        uint256 _maxTotalSupply,
        uint256 _mintPrice,
        uint256 _globalMaxMintPerWallet,
        uint256 _maxMintPerWallet,
        uint256 _maxMintPerTransaction,
        address _CRFTDWalletAddress,
        address[] _revenueAddresses,
        uint256[] _revenuePercents
    ) ERC721(_name, _symbol) {
        require(_mintPrice > 0, "MINT PRICE CAN NOT BE ZERO");
        require(
            _revenueAddresses.length == _revenuePercents.length,
            "NUMBER OF ADDRESSES AND PERCENTS ARE NOT MATCHED"
        );

        maxTotalSupply = _maxTotalSupply;
        mintPrice = _mintPrice;
        globalMaxMintPerWallet = _globalMaxMintPerWallet;
        maxMintPerWallet = _maxMintPerWallet;
        maxMintPerTransaction = _maxMintPerTransaction;
        CRFTDWalletAddress = _CRFTDWalletAddress;

        uint256 sumOfPercent = 0;
        for (uint i = 0; i < _revenueAddresses.length; i++) {
            revenueAddresses.push(_revenueAddresses[i]);
            revenuePercents.push(_revenuePercents[i]);
            sumOfPercent += _revenuePercents[i];
        }
        require(sumOfPercent == 9700, "SUM OF REVENUE PERCENTS SHOULD BE !00%");
    }

    function totalSupply() public view override returns (uint256) {
        return supply.current();
    }

    function mint(uint256 amount) public {
        require(amount > 0, "AMOUNT CANNOT BE 0");
        require(
            amount <= maxMintPerTransaction || maxMintPerTransaction == 0,
            "EXCEED MAX MINT PER TRANSACTION"
        );
        if (globalMaxMintPerWallet > 0) {
            require(
                balanceOf(msg.sender) + amount < globalMaxMintPerWallet,
                "EXCEED GLOBAL MAX MINT PER WALLET"
            );
        } else {
            require(
                balanceOf(msg.sender) + amount < maxMintPerWallet,
                "EXCEED MAX MINT PER WALLET"
            );
        }
        require(totalSupply() + amount <= maxTotalSupply, "SALE ALREADY ENDED");
        require(mintPrice * amount == msg.value, "INVALID ETHER VALUE");

        uint i;
        for (i = 0; i < amount; i++) {
            supply.increment();
            uint256 tokenId = supply.current();
            _safeMint(msg.sender, tokenId);
        }

        uint256 sendAmounts;
        for (i = 0; i < revenueAddresses.length; i++) {
            uint256 sendAmount = msg.value.mul(revenuePercents[i]).div(10000);
            transferCoin(revenueAddresses[i], sendAmount);
            sendAmounts == sendAmount;
        }
        transferCoin(CRFTDWalletAddress, msg.value - sendAmounts);
    }

    function setMintPrice(uint256 _newPrice) external {
        require(_newPrice > 0, "MINT PRICE CAN NOT BE ZERO");
        mintPrice = _newPrice;
    }

    function setGlobalMaxMintPerWallet(uint256 _newMaxMint) external {
        globalMaxMintPerWallet = _newMaxMint;
    }

    function setMaxMintPerWallet(uint256 _newMaxMint) external {
        maxMintPerWallet = _newMaxMint;
    }

    function setMaxMintPerTransaction(uint256 _newMaxMint) external {
        maxMintPerTransaction = _newMaxMint;
    }

    function transferCoin(address receiver, uint256 amount) internal {
        (bool os, ) = payable(receiver).call{value: amount}("");
        require(os);
    }
}
