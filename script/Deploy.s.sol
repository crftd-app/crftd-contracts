// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import "solmate/test/utils/mocks/MockERC721.sol";
import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";

import {CRFTDMarketplace} from "/CRFTDMarketplace.sol";
import {CRFTDRegistry} from "/CRFTDRegistry.sol";
import {CRFTDStakingDrip} from "/CRFTDStakingDrip.sol";

/* 
source .env && forge script script/Deploy.s.sol:Deploy --rpc-url $PROVIDER_RINKEBY  --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_KEY -vvvv

source .env && forge script script/Deploy.s.sol:Deploy --rpc-url https://rpc.ankr.com/polygon  --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $POLYGONSCAN_KEY --with-gas-price 30gwei -vvvv
*/

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();

        MockERC721 mock = new MockERC721("NFT", "nft");

        CRFTDMarketplace marketplace = new CRFTDMarketplace();
        CRFTDRegistry registry = new CRFTDRegistry(0.01 ether);
        CRFTDStakingDrip stakingToken = new CRFTDStakingDrip();

        vm.stopBroadcast();

        console.log("mock:");
        console.logAddress(address(mock));
        console.log(",marketplace:");
        console.logAddress(address(marketplace));
        console.log(",registry:");
        console.logAddress(address(registry));
        console.log(",staking:");
        console.logAddress(address(stakingToken));
    }
}
