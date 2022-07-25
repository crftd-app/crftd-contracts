// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import "solmate/test/utils/mocks/MockERC721.sol";
import "solmate/tokens/WETH.sol";

import {CRFTDRegistry} from "CRFTD/CRFTDRegistry.sol";
import {CRFTDMarketplace} from "CRFTD/CRFTDMarketplace.sol";
import {CRFTDStakingToken} from "CRFTD/CRFTDStakingToken.sol";

import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";

contract MockUUPSUpgrade is UUPSUpgrade {
    function _authorizeUpgrade() internal virtual override {}
}

/* 
source .env && forge script script/Deploy.s.sol:Deploy --rpc-url $PROVIDER_RINKEBY  --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_KEY -vvvv
source .env && forge script script/Deploy.s.sol:Deploy --rpc-url $PROVIDER_RINKEBY  --private-key $PRIVATE_KEY --resume --verify --etherscan-api-key $ETHERSCAN_KEY -vvvv

source .env && forge script script/Deploy.s.sol:Deploy --rpc-url https://rpc.ankr.com/polygon  --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $POLYGONSCAN_KEY --with-gas-price 30gwei -vvvv
*/

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();

        WETH weth = new WETH();
        MockERC721 mockNFT = new MockERC721("Crafted NFT", "CRFTD");

        CRFTDRegistry registry = new CRFTDRegistry(0.01 ether);
        CRFTDMarketplace marketplace = new CRFTDMarketplace(payable(weth));
        CRFTDStakingToken stakingToken = new CRFTDStakingToken();

        // mockNFT.mint(msg.sender, 1);
        // mockNFT.mint(msg.sender, 2);
        // mockNFT.mint(msg.sender, 3);
        // mockNFT.mint(msg.sender, 5);
        // mockNFT.mint(msg.sender, 6);
        // mockNFT.mint(msg.sender, 9);

        vm.stopBroadcast();

        console.log("weth:");
        console.logAddress(address(weth));
        console.log(",mockNFT:");
        console.logAddress(address(mockNFT));
        console.log(",marketplace:");
        console.logAddress(address(marketplace));
        console.log(",registry:");
        console.logAddress(address(registry));
        console.log(",staking:");
        console.logAddress(address(stakingToken));
    }
}
