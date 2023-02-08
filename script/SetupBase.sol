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

contract SetupBase is UpgradeScripts {
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
    bool MOCK_TUNNEL_TESTING;

    // Chains
    uint256 constant CHAINID_MAINNET = 1;
    uint256 constant CHAINID_RINKEBY = 4;
    uint256 constant CHAINID_GOERLI = 5;
    uint256 constant CHAINID_POLYGON = 137;
    uint256 constant CHAINID_MUMBAI = 80_001;
    uint256 constant CHAINID_TEST = 31_337;

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
