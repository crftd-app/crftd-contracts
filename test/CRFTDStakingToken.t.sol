// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, stdError} from "forge-std/Test.sol";

import {MockUUPSUpgrade} from "UDS/../test/mocks/MockUUPSUpgrade.sol";
// import {ERC20Test, MockERC20UDS} from "UDS/../test/solmate/ERC20UDS.t.sol";
import {MockERC20UDS} from "UDS/../test/mocks/MockERC20UDS.sol";
import {MockERC721UDS} from "UDS/../test/mocks/MockERC721UDS.sol";

import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";

import "CRFTD/CRFTDStakingToken.sol";
import "f-utils/futils.sol";

contract MockCRFTDStakingToken is CRFTDStakingToken {
    function burn(address from, uint256 value) public {
        _burn(from, value);
    }

    function mint(address to, uint256 quantity) public {
        _mint(to, quantity);
    }
}

contract TestCRFTDStakingToken is Test {
    using futils for *;

    address bob = address(0xb0b);
    address alice = address(0xbabe);
    address tester = address(this);

    address logic;
    MockCRFTDStakingToken token;
    MockERC721UDS nft;

    uint256 rate = 1e18;

    function setUp() public {
        nft = new MockERC721UDS();

        logic = address(new MockCRFTDStakingToken());

        bytes memory initCalldata = abi.encodeWithSelector(CRFTDStakingToken.init.selector, "Token", "TKN", 18);
        token = MockCRFTDStakingToken(address(new ERC1967Proxy(logic, initCalldata)));
        token.setRewardEndDate(block.timestamp + 1000 days);

        token.registerCollection(address(nft), 100);

        nft.mint(tester, 1);
        nft.mint(tester, 2);
        nft.mint(tester, 3);
        nft.mint(tester, 4);
        nft.mint(tester, 5);

        nft.setApprovalForAll(address(token), true);
    }

    /* ------------- setUp() ------------- */

    function test_setUp() public {
        // token.scrambleStorage(0, 100);

        assertEq(token.name(), "Token");
        assertEq(token.symbol(), "TKN");
        assertEq(token.decimals(), 18);
        assertEq(token.rewardDailyRate(), 1e16);
        assertEq(token.rewardEndDate(), block.timestamp + 1000 days);
        assertEq(token.rewardRate(address(nft)), 100);
    }

    /* ------------- stake() ------------- */

    function test_stake() public {
        token.stake(address(nft), [1].toMemory());

        assertEq(token.ownerOf(address(nft), 1), tester);

        token.unstake(address(nft), [1].toMemory());

        assertEq(nft.ownerOf(1), tester);
        assertEq(token.ownerOf(address(nft), 1), address(0));
    }

    function test_stake_CollectionNotRegistered() public {
        MockERC721UDS nft2 = new MockERC721UDS();

        vm.expectRevert(CollectionNotRegistered.selector);

        token.stake(address(nft2), [1].toMemory());
    }

    function test_stake2() public {
        token.stake(address(nft), [1, 3, 5].toMemory());

        // register second collection
        MockERC721UDS nft2 = new MockERC721UDS();

        nft2.mint(tester, 1);
        nft2.setApprovalForAll(address(token), true);

        token.registerCollection(address(nft2), 500);

        token.stake(address(nft2), [1].toMemory());

        assertEq(token.getDailyReward(tester), 3e18 + 5e18);

        token.unstake(address(nft2), [1].toMemory());
        token.unstake(address(nft), [1, 3, 5].toMemory());

        assertEq(token.getDailyReward(tester), 0);
    }

    // function test_stake(
    //     uint256 amountIn,
    //     uint256 amountOut,
    //     uint256 r
    // ) public {
    //     amountIn = bound(amountIn, 0, 100);
    //     // amountOut = bound(amountOut, 0, amountIn);

    //     uint256[] memory idsIn = 10.shuffledRange(10 + amountIn, r);
    //     // uint256[] memory idsOut = idsIn.randomSubset(amountOut, r);

    //     for (uint256 i; i < amountIn; i++) nft.mint(tester, idsIn[i]);

    //     token.stake(address(nft), idsIn);

    //     assertEq(token.stakedIdsOf(address(nft), tester, 1000), 10.range(10 + amountIn));
    //     // assertEq(token.getDailyReward(tester), amountIn * 1e18);

    //     // token.unstake(address(nft), idsIn);
    // }

    // /* ------------- decreaseMultiplier() ------------- */

    // function test_decreaseMultiplier(uint216 amountIn, uint216 amountOut) public {
    //     (amountIn, amountOut) = amountIn < amountOut ? (amountOut, amountIn) : (amountIn, amountOut);

    //     token.increaseMultiplier(alice, amountIn);

    //     token.decreaseMultiplier(alice, amountOut);

    //     assertEq(token.getMultiplier(alice), amountIn - amountOut);
    // }

    // function test_decreaseMultiplier_fail_Underflow(uint216 amountIn, uint216 amountOut) public {
    //     vm.assume(amountIn != amountOut);

    //     (amountIn, amountOut) = amountIn > amountOut ? (amountOut, amountIn) : (amountIn, amountOut);

    //     token.increaseMultiplier(alice, amountIn);

    //     vm.expectRevert(stdError.arithmeticError);
    //     token.decreaseMultiplier(alice, amountOut);
    // }

    // /* ------------- pendingReward() ------------- */

    // function test_pendingReward() public {
    //     token.increaseMultiplier(alice, 1_000);

    //     assertEq(token.balanceOf(alice), 0);
    //     assertEq(token.pendingReward(alice), 0);

    //     skip(100 days);

    //     assertEq(token.balanceOf(alice), 100_000e18);
    //     assertEq(token.pendingReward(alice), 100_000e18);

    //     // increasing claims for the user
    //     token.increaseMultiplier(alice, 1_000);

    //     assertEq(token.balanceOf(alice), 100_000e18);
    //     assertEq(token.pendingReward(alice), 0);

    //     skip(200 days);

    //     assertEq(token.balanceOf(alice), 500_000e18);
    //     assertEq(token.pendingReward(alice), 400_000e18);

    //     token.decreaseMultiplier(alice, 2_000);

    //     assertEq(token.balanceOf(alice), 500_000e18);
    //     assertEq(token.pendingReward(alice), 0);
    // }

    // /* ------------- claimReward() ------------- */

    // function test_claimReward() public {
    //     token.increaseMultiplier(alice, 1_000);

    //     token.claimReward();

    //     assertEq(token.balanceOf(alice), 0);
    //     assertEq(token.pendingReward(alice), 0);

    //     skip(100 days);

    //     assertEq(token.balanceOf(alice), 100_000e18);
    //     assertEq(token.pendingReward(alice), 100_000e18);

    //     // claim virtual balance to balance
    //     vm.prank(alice);
    //     token.claimReward();

    //     assertEq(token.balanceOf(alice), 100_000e18);
    //     assertEq(token.pendingReward(alice), 0);

    //     skip(100 days);

    //     // another 100 days
    //     assertEq(token.balanceOf(alice), 200_000e18);
    //     assertEq(token.pendingReward(alice), 100_000e18);

    //     vm.prank(alice);
    //     token.claimReward();

    //     // claiming twice doesn't change
    //     vm.prank(alice);
    //     token.claimReward();

    //     assertEq(token.balanceOf(alice), 200_000e18);
    //     assertEq(token.pendingReward(alice), 0);
    // }

    // /* ------------- endDate() ------------- */

    // function test_endDate() public {
    //     token.increaseMultiplier(alice, 1_000);

    //     skip(100 days);

    //     assertEq(token.balanceOf(alice), 100_000e18);
    //     assertEq(token.pendingReward(alice), 100_000e18);

    //     vm.prank(alice);
    //     token.claimReward();

    //     // skip to end date
    //     skip(900 days);

    //     assertEq(token.balanceOf(alice), 1_000_000e18);
    //     assertEq(token.pendingReward(alice), 900_000e18);

    //     // waiting any longer doesn't give more due to rewardEndDate
    //     skip(900 days);

    //     assertEq(token.balanceOf(alice), 1_000_000e18);
    //     assertEq(token.pendingReward(alice), 900_000e18);

    //     // claim all balance past end date
    //     vm.prank(alice);
    //     token.claimReward();

    //     skip(100 days);

    //     assertEq(token.balanceOf(alice), 1_000_000e18);
    //     assertEq(token.pendingReward(alice), 0);
    // }

    // /* ------------- transfer() ------------- */

    // function test_transfer() public {
    //     vm.prank(alice);
    //     token.approve(tester, type(uint256).max);

    //     token.increaseMultiplier(alice, 1_000);

    //     skip(100 days);

    //     // alice should have 100_000 tokens at her disposal
    //     assertEq(token.balanceOf(alice), 100_000e18);

    //     vm.prank(alice);
    //     token.transfer(bob, 20_000e18);

    //     assertEq(token.balanceOf(alice), 80_000e18);
    //     assertEq(token.balanceOf(bob), 20_000e18);

    //     assertEq(token.pendingReward(alice), 0);
    //     assertEq(token.pendingReward(bob), 0);

    //     // further claiming virtual tokens should have no effect
    //     vm.prank(alice);
    //     token.claimReward();

    //     assertEq(token.balanceOf(alice), 80_000e18);
    //     assertEq(token.balanceOf(bob), 20_000e18);

    //     vm.prank(alice);
    //     token.transfer(bob, 80_000e18);

    //     assertEq(token.balanceOf(alice), 0);
    //     assertEq(token.balanceOf(bob), 100_000e18);
    // }

    // /* ------------- transferFrom() ------------- */

    // function test_transferFrom() public {
    //     vm.prank(alice);
    //     token.approve(tester, type(uint256).max);

    //     token.increaseMultiplier(alice, 1_000);

    //     skip(100 days);

    //     // alice should have 100_000 tokens at her disposal
    //     assertEq(token.balanceOf(alice), 100_000e18);

    //     token.transferFrom(alice, bob, 20_000e18);

    //     assertEq(token.balanceOf(alice), 80_000e18);
    //     assertEq(token.balanceOf(bob), 20_000e18);

    //     assertEq(token.pendingReward(alice), 0);
    //     assertEq(token.pendingReward(bob), 0);

    //     // further claiming virtual tokens should have no effect
    //     vm.prank(alice);
    //     token.claimReward();

    //     assertEq(token.balanceOf(alice), 80_000e18);
    //     assertEq(token.balanceOf(bob), 20_000e18);

    //     token.transferFrom(alice, bob, 80_000e18);

    //     assertEq(token.balanceOf(alice), 0);
    //     assertEq(token.balanceOf(bob), 100_000e18);
    // }
}

// // all solmate ERC20 tests should pass
// contract TestERC20UDS is ERC20Test {
//     function setUp() public override {
//         logic = address(new MockCRFTDStakingToken());

//         bytes memory initCalldata = abi.encodeWithSelector(CRFTDStakingToken.init.selector, "Token", "TKN", 18);
//         token = MockERC20UDS(address(new ERC1967Proxy(logic, initCalldata)));
//     }
// }
