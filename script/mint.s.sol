// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import {WETH} from "solmate/tokens/WETH.sol";

import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";
import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";

import {CRFTDRegistry} from "CRFTD/CRFTDRegistry.sol";
import {CRFTDMarketplace} from "CRFTD/CRFTDMarketplace.sol";
// import {CRFTDStakingToken} from "CRFTD/CRFTDStakingToken.sol";
import {CRFTDStakingToken} from "CRFTD/CRFTDStakingTokenRoot.sol";

import {MockERC721} from "./MockERC721.sol";

/* 
source .env.local && forge script Deploy --rpc-url $PROVIDER_MAINNET  --private-key $CRFTD_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_KEY -vvvv

source .env.local && forge script Deploy --rpc-url $PROVIDER_RINKEBY  --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_KEY -vvvv
source .env.local && forge script Deploy --rpc-url $PROVIDER_RINKEBY  --private-key $PRIVATE_KEY --resume --verify --etherscan-api-key $ETHERSCAN_KEY -vvvv

source .env.local && forge script Deploy --rpc-url https://rpc.ankr.com/polygon  --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $POLYGONSCAN_KEY --with-gas-price 30gwei -vvvv

source .env.local && forge script Deploy --rpc-url https://eth-goerli.g.alchemy.com/v2/lNJjaSqBw517GDQil1y8IJgfK17IzeKz  --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_KEY --with-gas-price 2000000000000000000 -vvvv
*/

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();

        // WETH weth = new WETH();
        // MockERC721 mockNFT = new MockERC721();

        // CRFTDRegistry registry = new CRFTDRegistry(0.1 ether);
        // CRFTDMarketplace marketplace = new CRFTDMarketplace();
        CRFTDStakingToken stakingToken = new CRFTDStakingToken(address(0), address(0));

        // registry.setImplementationAllowed(address(stakingToken), true);

        // mockNFT.mint(msg.sender);
        // mockNFT.mint(msg.sender);
        // mockNFT.mint(msg.sender);
        // mockNFT.mint(msg.sender);
        // mockNFT.mint(msg.sender);
        // mockNFT.mint(msg.sender);

        // vm.stopBroadcast();

        // console.log('mockERC721:"');
        // console.logAddress(address(mockNFT));
        // console.log('",crftdMarketplace:"');
        // console.logAddress(address(marketplace));
        // console.log('",crftdRegistry:"');
        // console.logAddress(address(registry));
        // console.log('",crftdStakingToken:"');
        // console.logAddress(address(stakingToken));
        // console.log('"');
    }
}
