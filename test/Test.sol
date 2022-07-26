// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../src/CRFTDStakingToken.sol";
// import "../src/CRFTDStakingPacked.sol";
import "ArrayUtils/ArrayUtils.sol";

import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";
import {MockERC721UDS} from "UDS/../test/mocks/MockERC721UDS.sol";

contract TestStakingToken is Test {
    using ArrayUtils for *;

    CRFTDStakingToken staking;
    MockERC721UDS nft;

    address bob = address(0xb0b);
    address alice = address(0xbabe);
    address tester = address(this);

    function setUp() public {
        nft = new MockERC721UDS();

        address impl = address(new CRFTDStakingToken());

        bytes[] memory initDelegates = new bytes[](2);
        initDelegates[0] = abi.encodeWithSelector(CRFTDStakingToken.registerCollection.selector, address(nft), 100);
        initDelegates[1] = abi.encodeWithSelector(CRFTDStakingToken.setRewardEndDate.selector, block.timestamp + 100);

        bytes memory initCalldata = abi.encodeWithSelector(
            CRFTDStakingToken.init.selector,
            "CRFTD",
            "CRFTD",
            18,
            impl,
            initDelegates
        );

        staking = CRFTDStakingToken(address(new ERC1967Proxy(impl, initCalldata)));

        nft.mint(bob, 1);
        nft.mint(bob, 2);
        nft.mint(bob, 3);
        nft.mint(bob, 4);
        nft.mint(bob, 5);

        nft.mint(alice, 11);
        nft.mint(alice, 12);
        nft.mint(alice, 13);
        nft.mint(alice, 14);
        nft.mint(alice, 15);

        nft.mint(tester, 21);
        nft.mint(tester, 22);
        nft.mint(tester, 23);
        nft.mint(tester, 24);
        nft.mint(tester, 25);

        // staking.registerCollection(address(nft), 100);

        vm.prank(bob);
        nft.setApprovalForAll(address(staking), true);

        vm.prank(alice);
        nft.setApprovalForAll(address(staking), true);

        vm.prank(tester);
        nft.setApprovalForAll(address(staking), true);

        staking.mint(bob, 100);
        staking.mint(tester, 100);

        vm.prank(alice);
        staking.stake(address(nft), [11].toMemory());

        vm.prank(tester);
        staking.stake(address(nft), [21].toMemory());

        skip(100);

        vm.prank(tester);
        staking.unstake(address(nft), [21].toMemory());

        // staking.setRewardEndDate(uint40(block.timestamp + 100 days));
    }

    function test_stake() public {
        vm.prank(bob);
        staking.stake(address(nft), [1].toMemory());
    }

    function test_stake_additional() public {
        vm.prank(alice);
        staking.stake(address(nft), [12].toMemory());
    }

    function test_stake_restake() public {
        vm.prank(tester);
        staking.stake(address(nft), [21].toMemory());
    }

    function test_unstake() public {
        vm.prank(alice);
        staking.unstake(address(nft), [11].toMemory());
    }

    function test_claim() public {
        vm.prank(alice);
        staking.claimVirtualBalance();
    }

    function test_getOwned() public {
        vm.prank(bob);
        staking.stake(address(nft), [1, 3, 5].toMemory());

        assertEq(staking.stakedTokenIdsOf(address(nft), bob, 100), [1, 3, 5].toMemory());
    }
}
