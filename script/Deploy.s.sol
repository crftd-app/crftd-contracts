// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "CRFTD/lib/VRFConsumerV2.sol";
import {CRFTDRegistry} from "CRFTD/CRFTDRegistry.sol";
import {CollablandProxy} from "CRFTD/lib/CollablandProxy.sol";
import {CRFTDMarketplace} from "CRFTD/CRFTDMarketplace.sol";
import {CRFTDStakingToken as CRFTDStakingTokenRoot} from "CRFTD/CRFTDStakingTokenRoot.sol";
import {CRFTDStakingToken as CRFTDStakingTokenChild} from "CRFTD/CRFTDStakingTokenChild.sol";
import {CRFTDStakingTokenV1} from "CRFTD/legacy/CRFTDStakingToken.sol";

import {WETH} from "solmate/tokens/WETH.sol";
import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";
import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";
import {UpgradeScripts} from "upgrade-scripts/UpgradeScripts.sol";

import {MockERC721} from "../test/mocks/MockERC721.sol";

import "forge-std/Script.sol";
import "forge-std/Test.sol";

contract SetUpBase is UpgradeScripts {
    // chainlink
    address coordinator;
    bytes32 linkKeyHash;
    uint64 linkSubId;

    // PoS Bridge
    address fxRoot;
    address fxChild;
    address fxRootCheckpointManager;

    uint256 chainIdChild;
    uint256 chainIdRoot;

    // set to true to deploy MockFxTunnel (mock tunnel on same chain)
    bool immutable MOCK_TUNNEL_TESTING = true || block.chainid == CHAINID_TEST;

    // Chains
    uint256 constant CHAINID_MAINNET = 1;
    uint256 constant CHAINID_RINKEBY = 4;
    uint256 constant CHAINID_GOERLI = 5;
    uint256 constant CHAINID_POLYGON = 137;
    uint256 constant CHAINID_MUMBAI = 80_001;
    uint256 constant CHAINID_TEST = 31_337;

    uint256 lastDeployConfirmation = 1665831179;

    constructor() {
        if (!isTestnet() && !UPGRADE_SCRIPTS_DRY_RUN) {
            if (block.timestamp - lastDeployConfirmation > 10 minutes) {
                console.log("\nMust reconfirm mainnet deployment:");
                console.log("```");
                console.log("uint256 lastDeployConfirmation = %s;", block.timestamp);
                console.log("```");
                revert(
                    string.concat(
                        "CONFIRMATION REQUIRED: ```\nuint256 lastDeployConfirmation = ",
                        vm.toString(block.timestamp),
                        ";\n```"
                    )
                );
            }
        }

        // setUpFxPortal();
    }

    function setUpChainlink() internal {
        if (block.chainid == CHAINID_POLYGON) {
            coordinator = COORDINATOR_POLYGON;
            linkKeyHash = KEYHASH_POLYGON;
            linkSubId = 344;
        } else if (block.chainid == CHAINID_MUMBAI) {
            coordinator = COORDINATOR_MUMBAI;
            linkKeyHash = KEYHASH_MUMBAI;
            linkSubId = 862;
        } else if (block.chainid == CHAINID_RINKEBY) {
            coordinator = COORDINATOR_RINKEBY;
            linkKeyHash = KEYHASH_RINKEBY;
            linkSubId = 6985;
        } else if (block.chainid == CHAINID_TEST) {
            coordinator = setUpContract("MockVRFCoordinator");
            linkKeyHash = bytes32(uint256(123));
            linkSubId = 123;
        }
    }

    function setUpFxPortal() internal {
        if (MOCK_TUNNEL_TESTING && !isTestnet()) revert("Mock Tunnel not allowed on mainnet.");

        if (MOCK_TUNNEL_TESTING) {
            // link these on same chain via MockTunnel for testing
            fxChild = fxRoot = setUpContract("MockFxTunnel");
            chainIdRoot = block.chainid;
            chainIdChild = block.chainid;
        } else if (block.chainid == CHAINID_MAINNET) {
            chainIdChild = CHAINID_POLYGON;

            fxRoot = 0xfe5e5D361b2ad62c541bAb87C45a0B9B018389a2;
            fxRootCheckpointManager = 0x86E4Dc95c7FBdBf52e33D563BbDB00823894C287;
        } else if (block.chainid == CHAINID_POLYGON) {
            chainIdRoot = CHAINID_MAINNET;

            fxChild = 0x8397259c983751DAf40400790063935a11afa28a;
        } else if (block.chainid == CHAINID_GOERLI) {
            chainIdChild = CHAINID_MUMBAI;

            fxRoot = 0x3d1d3E34f7fB6D26245E6640E1c50710eFFf15bA;
            fxRootCheckpointManager = 0x2890bA17EfE978480615e330ecB65333b880928e;
        } else if (block.chainid == CHAINID_MUMBAI) {
            chainIdRoot = CHAINID_GOERLI;

            fxChild = 0xCf73231F28B7331BBe3124B907840A94851f9f11;
        } else if (block.chainid == CHAINID_RINKEBY) {}

        if (fxRoot != address(0)) vm.label(fxRoot, "FXROOT");
        if (fxChild != address(0)) vm.label(fxChild, "FXCHILD");
        if (fxRootCheckpointManager != address(0)) vm.label(fxChild, "FXROOTCHKPT");
    }

    function isChildChain() internal view returns (bool) {
        return block.chainid == CHAINID_MUMBAI || block.chainid == CHAINID_POLYGON;
    }
}

/* 
# Anvil
source .env && forge script deploy --rpc-url $RPC_ANVIL --private-key $PRIVATE_KEY_ANVIL -vvvv --ffi --broadcast

# Mumbai
source .env && forge script deploy --rpc-url $RPC_MUMBAI  --private-key $PRIVATE_KEY --verify --etherscan-api-key $POLYGONSCAN_KEY -vvvv  --ffi --broadcast

# Polygon
source .env && US_DRY_RUN=true forge script deploy --rpc-url $RPC_POLYGON --private-key $PRIVATE_KEY -vvvv --ffi
source .env && forge script deploy --rpc-url $RPC_POLYGON  --private-key $PRIVATE_KEY --verify --etherscan-api-key $POLYGONSCAN_KEY -vvvv --ffi --broadcast

# MAINNET
source .env && US_DRY_RUN=true forge script deploy --rpc-url $RPC_MAINNET --private-key $CRFTD_KEY -vvvv --ffi
source .env && forge script deploy --rpc-url $RPC_MAINNET --private-key $CRFTD_KEY --verify --etherscan-api-key $ETHERSCAN_KEY -vvvv --ffi --broadcast

# Goerli
source .env && US_DRY_RUN=true forge script deploy --rpc-url $RPC_GOERLI --private-key $PRIVATE_KEY -vvvv --ffi
source .env && forge script deploy --rpc-url $RPC_GOERLI --private-key $PRIVATE_KEY --verify --etherscan-api-key $ETHERSCAN_KEY -vvvv --ffi --broadcast 

cp ~/git/eth/CRFTD/out/CRFTDRegistry.sol/CRFTDRegistry.json ~/git/eth/crftd-web/data/abi
cp ~/git/eth/CRFTD/out/CRFTDMarketplace.sol/CRFTDMarketplace.json ~/git/eth/crftd-web/data/abi
cp ~/git/eth/CRFTD/out/CRFTDStakingTokenRoot.sol/CRFTDStakingToken.json ~/git/eth/crftd-web/data/abi/CRFTDStakingTokenRoot.sol
cp ~/git/eth/CRFTD/out/CRFTDStakingTokenChild.sol/CRFTDStakingToken.json ~/git/eth/crftd-web/data/abi/CRFTDStakingTokenChild.sol
cp ~/git/eth/CRFTD/deployments/80001/deploy-latest.json ~/git/eth/crftd-web/data/deployments_80001.json
cp ~/git/eth/CRFTD/deployments/5/deploy-latest.json ~/git/eth/crftd-web/data/deployments_5.json
cp ~/git/eth/CRFTD/deployments/1/deploy-latest.json ~/git/eth/crftd-web/data/deployments_1.json

*/

contract deploy is SetUpBase {
    CRFTDRegistry registry;
    CRFTDMarketplace marketplace;

    // Root
    CRFTDStakingTokenRoot crftdStakingTokenRoot;

    // Child
    CRFTDStakingTokenChild crftdStakingTokenChild;

    function setUpContractsRoot() internal {
        registry = CRFTDRegistry(setUpContract("CRFTDRegistry", "", "CRFTDRegistryRoot"));
        marketplace = CRFTDMarketplace(setUpContract("CRFTDMarketplace", "", "CRFTDMarketplaceRoot"));
        crftdStakingTokenRoot = CRFTDStakingTokenRoot(
            setUpContract(
                "CRFTDStakingTokenRoot.sol:CRFTDStakingToken",
                abi.encode(fxRootCheckpointManager, fxRoot),
                "CRFTDStakingTokenRoot"
            )
        );

        if (!registry.approvedImplementation(address(crftdStakingTokenRoot))) {
            registry.setImplementationApproved(address(crftdStakingTokenRoot), true);
        }
    }

    function setUpContractsChild() internal {
        registry = CRFTDRegistry(setUpContract("CRFTDRegistry", "", "CRFTDRegistryChild"));
        marketplace = CRFTDMarketplace(setUpContract("CRFTDMarketplace", "", "CRFTDMarketplaceChild"));
        crftdStakingTokenChild = CRFTDStakingTokenChild(
            setUpContract("CRFTDStakingTokenChild.sol:CRFTDStakingToken", abi.encode(fxChild), "CRFTDStakingTokenChild")
        );

        if (!registry.approvedImplementation(address(crftdStakingTokenChild))) {
            registry.setImplementationApproved(address(crftdStakingTokenChild), true);
        }
    }

    function run() external {
        vm.startBroadcast();

        if (MOCK_TUNNEL_TESTING) {
            setUpContractsChild();
            setUpContractsRoot();
        } else if (isChildChain()) {
            setUpContractsChild();
        } else {
            setUpContractsRoot();
        }

        if (isTestnet()) {
            setUpContract("MockERC721");
        }

        // // WETH weth = new WETH();
        // MockERC721 mockNFT = new MockERC721();
        // // vm.getCode("CRFTDStakingTokenRoot.sol");
        // address crftdToken = setUpContract(
        //     "CRFTDStakingTokenRoot.sol:CRFTDStakingToken",
        //     abi.encode(fxRootCheckpointManager, fxRoot),
        //     "CRFTDStakingToken"
        // );
        // // CRFTDStakingToken stakingToken = new CRFTDStakingToken(fxRootCheckpointManager, fxRoot);
        // registry.setImplementationAllowed(address(crftdToken), true);
        // mockNFT.mint(msg.sender);
        // mockNFT.mint(msg.sender);
        // mockNFT.mint(msg.sender);
        // mockNFT.mint(msg.sender);
        // mockNFT.mint(msg.sender);
        // mockNFT.mint(msg.sender);
        vm.stopBroadcast();

        storeLatestDeployments();
    }
}
