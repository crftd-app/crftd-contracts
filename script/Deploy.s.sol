// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "src/lib/VRFConsumerV2.sol";
import {CRFTDRegistry} from "src/CRFTDRegistry.sol";
import {CollablandProxy} from "src/lib/CollablandProxy.sol";
import {CRFTDMarketplace} from "src/CRFTDMarketplace.sol";
import {CRFTDStakingToken as CRFTDStakingTokenRoot} from "src/CRFTDStakingTokenRoot.sol";
import {CRFTDStakingToken as CRFTDStakingTokenChild} from "src/CRFTDStakingTokenChild.sol";
import {CRFTDStakingTokenV1} from "src/legacy/CRFTDStakingToken.sol";

import {WETH} from "solmate/tokens/WETH.sol";
import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";
import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";
import {UpgradeScripts} from "upgrade-scripts/UpgradeScripts.sol";

import {MockERC721} from "../test/mocks/MockERC721.sol";

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import {SetupBase} from "./SetupBase.sol";

/* 
# Anvil
source .env && forge script deploy --rpc-url $RPC_ANVIL --private-key $PRIVATE_KEY_ANVIL -vvvv --ffi --broadcast

# Mumbai
source .env && forge script deploy --rpc-url $RPC_MUMBAI  --private-key $PRIVATE_KEY --verify --etherscan-api-key $POLYGONSCAN_KEY -vvvv  --ffi --broadcast

# Polygon
source .env && US_DRY_RUN=true forge script deploy --rpc-url $RPC_POLYGON --private-key $PRIVATE_KEY_CRFTD -vvvv --ffi
source .env && forge script deploy --rpc-url $RPC_POLYGON  --private-key $PRIVATE_KEY_CRFTD --verify --etherscan-api-key $POLYGONSCAN_KEY -vvvv --ffi --broadcast

# MAINNET
source .env && US_DRY_RUN=true forge script deploy --rpc-url $RPC_MAINNET --private-key $PRIVATE_KEY_CRFTD -vvvv --ffi
source .env && forge script deploy --rpc-url $RPC_MAINNET --private-key $PRIVATE_KEY_CRFTD --verify --etherscan-api-key $ETHERSCAN_KEY -vvvv --ffi --broadcast

# Goerli
source .env && US_DRY_RUN=true forge script deploy --rpc-url $RPC_GOERLI --private-key $PRIVATE_KEY -vvvv --ffi
source .env && forge script deploy --rpc-url $RPC_GOERLI --private-key $PRIVATE_KEY --verify --etherscan-api-key $ETHERSCAN_KEY -vvvv --ffi --broadcast 

cp ~/git/eth/crftd-staking/out/CRFTDRegistry.sol/CRFTDRegistry.json ~/git/eth/crftd-web/data/abi
cp ~/git/eth/crftd-staking/out/CRFTDMarketplace.sol/CRFTDMarketplace.json ~/git/eth/crftd-web/data/abi
cp ~/git/eth/crftd-staking/out/CRFTDStakingTokenRoot.sol/CRFTDStakingToken.json ~/git/eth/crftd-web/data/abi/CRFTDStakingTokenRoot.json
cp ~/git/eth/crftd-staking/out/CRFTDStakingTokenChild.sol/CRFTDStakingToken.json ~/git/eth/crftd-web/data/abi/CRFTDStakingTokenChild.json
cp ~/git/eth/crftd-staking/deployments/80001/deploy-latest.json ~/git/eth/crftd-web/data/deployments_80001.json
cp ~/git/eth/crftd-staking/deployments/137/deploy-latest.json ~/git/eth/crftd-web/data/deployments_137.json
cp ~/git/eth/crftd-staking/deployments/5/deploy-latest.json ~/git/eth/crftd-web/data/deployments_5.json
cp ~/git/eth/crftd-staking/deployments/1/deploy-latest.json ~/git/eth/crftd-web/data/deployments_1.json
//*/

contract deploy is SetupBase {
    CRFTDRegistry registry;
    CRFTDMarketplace marketplace;

    // Root
    CRFTDStakingTokenRoot crftdStakingTokenRoot;

    // Child
    CRFTDStakingTokenChild crftdStakingTokenChild;

    function run() external {
        MOCK_TUNNEL_TESTING = false;
        mainnetConfirmation = 1675596383;

        setUpFxPortal();
        setUpChainlink();

        upgradeScriptsBroadcast();

        if (isTestnet() && MOCK_TUNNEL_TESTING) {
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

    function setUpContractsRoot() internal {
        registry = CRFTDRegistry(setUpContract("CRFTDRegistry", "", "CRFTDRegistryRoot"));
        marketplace = CRFTDMarketplace(setUpContract("CRFTDMarketplace", "", "CRFTDMarketplaceRoot", true));
        crftdStakingTokenRoot = CRFTDStakingTokenRoot(
            setUpContract(
                "CRFTDStakingTokenRoot.sol:CRFTDStakingToken",
                abi.encode(fxRootCheckpointManager, fxRoot),
                "CRFTDStakingTokenRoot"
            )
        );

        if (!registry.approvedImplementation(address(crftdStakingTokenRoot))) {
            address oldImplementation = loadLatestDeployedAddress("CRFTDStakingTokenRoot");

            if (oldImplementation != address(0)) registry.setImplementationApproved(oldImplementation, false);

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
            address oldImplementation = loadLatestDeployedAddress("CRFTDStakingTokenRoot");

            if (oldImplementation != address(0)) registry.setImplementationApproved(oldImplementation, false);

            registry.setImplementationApproved(address(crftdStakingTokenChild), true);
        }
    }
}
