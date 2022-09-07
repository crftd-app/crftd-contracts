// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {MockERC721} from "./MockERC721.sol";

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import {WETH} from "solmate/tokens/WETH.sol";
import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";
import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";
import {CRFTDRegistry} from "CRFTD/CRFTDRegistry.sol";
import {CRFTDMarketplace} from "CRFTD/CRFTDMarketplace.sol";
import {CRFTDStakingToken} from "CRFTD/CRFTDStakingTokenRoot.sol";
import {CRFTDStakingTokenV1} from "CRFTD/legacy/CRFTDStakingToken.sol";
import {UpgradeScripts} from "upgrade-scripts/UpgradeScripts.sol";

contract SetUpBase is UpgradeScripts {
    address fxRoot;
    address fxChild;
    address fxRootCheckpointManager;

    uint256 constant CHAINID_MAINNET = 1;
    uint256 constant CHAINID_RINKEBY = 4;
    uint256 constant CHAINID_GOERLI = 5;
    uint256 constant CHAINID_POLYGON = 137;
    uint256 constant CHAINID_MUMBAI = 80_001;
    uint256 constant CHAINID_TEST = 31_337;

    constructor() {
        __setUpFxPortal();
    }

    function __setUpFxPortal() internal {
        if (block.chainid == CHAINID_MAINNET) {
            fxRoot = 0xfe5e5D361b2ad62c541bAb87C45a0B9B018389a2;
            fxRootCheckpointManager = 0x86E4Dc95c7FBdBf52e33D563BbDB00823894C287;
        } else if (block.chainid == CHAINID_POLYGON) {
            fxChild = 0x8397259c983751DAf40400790063935a11afa28a;
        } else if (block.chainid == CHAINID_GOERLI) {
            fxRoot = 0x3d1d3E34f7fB6D26245E6640E1c50710eFFf15bA;
            fxRootCheckpointManager = 0x2890bA17EfE978480615e330ecB65333b880928e;
        } else if (block.chainid == CHAINID_MUMBAI) {
            fxChild = 0xCf73231F28B7331BBe3124B907840A94851f9f11;
        }

        if (fxRoot != address(0)) vm.label(fxRoot, "FXROOT");
        if (fxChild != address(0)) vm.label(fxChild, "FXCHILD");
        if (fxRootCheckpointManager != address(0)) vm.label(fxChild, "FXROOTCHKPT");
    }
}

/* 
# Anvil
source .env && forge script deploy --rpc-url $RPC_ANVIL --private-key $PRIVATE_KEY_ANVIL -vvvv --ffi --broadcast

# Rinkeby
source .env && forge script deploy --rpc-url $RPC_RINKEBY  --private-key $PRIVATE_KEY --verify --etherscan-api-key $ETHERSCAN_KEY -vvvv  --ffi --broadcast

# Polygon
source .env && forge script deploy --rpc-url https://rpc.ankr.com/polygon  --private-key $PRIVATE_KEY --verify --etherscan-api-key $POLYGONSCAN_KEY --with-gas-price 30gwei -vvvv --ffi --broadcast

# MAINNET
source .env && US_DRY_RUN=true forge script deploy --rpc-url $RPC_MAINNET --private-key $CRFTD_KEY --verify --etherscan-api-key $ETHERSCAN_KEY -vvvv --ffi
source .env && forge script deploy --rpc-url $RPC_MAINNET --private-key $CRFTD_KEY --verify --etherscan-api-key $ETHERSCAN_KEY -vvvv --ffi --broadcast
*/

contract deploy is SetUpBase {
    function run() external {
        vm.startBroadcast();

        // if (fxRoot == address(0)) {
        //     console.log("ERR: fxRoot unset");
        //     revert();
        // }

        // WETH weth = new WETH();
        // MockERC721 mockNFT = new MockERC721();

        // CRFTDRegistry registry = new CRFTDRegistry(0.1 ether);
        // CRFTDMarketplace marketplace = new CRFTDMarketplace();
        // new CRFTDStakingToken(fxRootCheckpointManager, fxRoot);
        // vm.getCode("CRFTDStakingTokenRoot.sol");

        setUpContract(
            "CRFTDStakingTokenRoot.sol:CRFTDStakingToken",
            abi.encode(fxRootCheckpointManager, fxRoot),
            "CRFTDStakingToken"
        );

        // CRFTDStakingToken stakingToken = new CRFTDStakingToken(fxRootCheckpointManager, fxRoot);

        // registry.setImplementationAllowed(address(stakingToken), true);

        // mockNFT.mint(msg.sender);
        // mockNFT.mint(msg.sender);
        // mockNFT.mint(msg.sender);
        // mockNFT.mint(msg.sender);
        // mockNFT.mint(msg.sender);
        // mockNFT.mint(msg.sender);

        vm.stopBroadcast();

        logDeployments();
        storeLatestDeployments();
    }
}
