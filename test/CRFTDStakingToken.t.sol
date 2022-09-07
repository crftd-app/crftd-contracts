// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {MockUUPSUpgrade} from "UDS/../test/mocks/MockUUPSUpgrade.sol";
// import {ERC20Test, MockERC20UDS} from "UDS/../test/solmate/ERC20UDS.t.sol";
import {MockERC20UDS} from "UDS/../test/mocks/MockERC20UDS.sol";
import {MockERC721UDS} from "UDS/../test/mocks/MockERC721UDS.sol";

import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";

import "CRFTD/legacy/CRFTDStakingToken.sol";
import "futils/futils.sol";

error TransferFromIncorrectOwner();

contract MockCRFTDStakingToken is CRFTDStakingTokenV1 {
    function burn(address from, uint256 value) public {
        _burn(from, value);
    }

    function mint(address to, uint256 quantity) public {
        _mint(to, quantity);
    }
}

contract TestCRFTDStakingToken is Test {
    using futils for *;

    address bob = makeAddr("bob");
    address alice = makeAddr("babe");
    address tester = address(this);

    address logic;
    MockERC721UDS nft;
    MockCRFTDStakingToken token;

    uint256 rate = 5e18;
    uint256 rewardEndDate = block.timestamp + 1000 days;

    function setUp() public virtual {
        nft = new MockERC721UDS();

        logic = address(new MockCRFTDStakingToken());

        bytes memory initCall = abi.encodeWithSelector(CRFTDStakingTokenV1.init.selector, "Token", "TKN");
        token = MockCRFTDStakingToken(address(new ERC1967Proxy(logic, initCall)));

        token.setRewardEndDate(rewardEndDate);
        token.registerCollection(address(nft), 500);

        nft.mint(tester, 1);
        nft.mint(tester, 2);
        nft.mint(tester, 3);
        nft.mint(tester, 4);
        nft.mint(tester, 5);

        nft.setApprovalForAll(address(token), true);

        vm.label(tester, "tester");
        vm.label(address(nft), "nft");
        vm.label(address(token), "token");
    }

    /* ------------- utils ------------- */

    function resetBalance() internal {
        skip(1 days);

        token.claimReward();

        assertEq(address(token).balanceDiff(tester), 0);

        token.burn(tester, token.balanceOf(tester));

        address(token).balanceDiff(tester);
    }

    /* ------------- setUp() ------------- */

    function test_setUp() public {
        // token.scrambleStorage(0, 100);

        assertEq(token.name(), "Token");
        assertEq(token.symbol(), "TKN");
        assertEq(token.decimals(), 18);

        assertEq(token.rewardRate(address(nft)), 500);
        assertEq(token.rewardEndDate(), rewardEndDate);
        assertEq(token.rewardDailyRate(), 1e16);
    }

    /* ------------- stake() ------------- */

    function test_stake() public {
        token.stake(address(nft), [1, 4, 3].toMemory());

        skip(1 days);

        assertEq(token.ownerOf(address(nft), 1), tester);
        assertEq(token.ownerOf(address(nft), 3), tester);
        assertEq(token.ownerOf(address(nft), 4), tester);

        assertEq(nft.ownerOf(1), address(token));
        assertEq(nft.ownerOf(3), address(token));
        assertEq(nft.ownerOf(4), address(token));

        assertEq(token.totalBalanceOf(tester), 3 * 5e18);
        assertEq(token.getDailyReward(tester), 3 * 5e18);
        assertEq(token.stakedIdsOf(address(nft), tester, 77), [1, 3, 4].toMemory());

        assertEq(address(token).balanceDiff(tester), 0);

        token.unstake(address(nft), [1, 3].toMemory());

        assertEq(token.ownerOf(address(nft), 1), address(0));
        assertEq(token.ownerOf(address(nft), 3), address(0));
        assertEq(token.ownerOf(address(nft), 4), tester);

        assertEq(nft.ownerOf(1), address(tester));
        assertEq(nft.ownerOf(3), address(tester));
        assertEq(nft.ownerOf(4), address(token));

        assertEq(token.totalBalanceOf(tester), 3 * 5e18);
        assertEq(token.getDailyReward(tester), 1 * 5e18);
        assertEq(token.stakedIdsOf(address(nft), tester, 77), [4].toMemory());

        assertEq(address(token).balanceDiff(tester), int256(3) * 5e18);

        skip(1 days);

        token.unstake(address(nft), [4].toMemory());

        assertEq(token.ownerOf(address(nft), 1), address(0));
        assertEq(token.ownerOf(address(nft), 3), address(0));
        assertEq(token.ownerOf(address(nft), 4), address(0));

        assertEq(nft.ownerOf(1), address(tester));
        assertEq(nft.ownerOf(3), address(tester));
        assertEq(nft.ownerOf(4), address(tester));

        assertEq(token.totalBalanceOf(tester), 4 * 5e18);
        assertEq(token.getDailyReward(tester), 0);
        assertEq(token.stakedIdsOf(address(nft), tester, 77).length, 0);

        assertEq(address(token).balanceDiff(tester), int256(1) * 5e18);
    }

    function test_stake_2collections() public {
        token.stake(address(nft), [1, 3, 5].toMemory());

        // register second collection
        MockERC721UDS nft2 = new MockERC721UDS();

        nft2.mint(tester, 1);
        nft2.mint(tester, 2);
        nft2.setApprovalForAll(address(token), true);

        token.registerCollection(address(nft2), 800);
        token.stake(address(nft2), [1, 2].toMemory());

        assertEq(token.ownerOf(address(nft), 1), tester);
        assertEq(token.ownerOf(address(nft), 3), tester);
        assertEq(token.ownerOf(address(nft), 5), tester);
        assertEq(token.ownerOf(address(nft2), 1), tester);
        assertEq(token.ownerOf(address(nft2), 2), tester);

        assertEq(nft.ownerOf(1), address(token));
        assertEq(nft.ownerOf(3), address(token));
        assertEq(nft.ownerOf(5), address(token));
        assertEq(nft2.ownerOf(1), address(token));

        assertEq(token.getDailyReward(tester), 3 * 5e18 + 2 * 8e18);

        skip(1 days);

        token.unstake(address(nft2), [2, 1].toMemory());
        token.unstake(address(nft), [1, 3, 5].toMemory());

        assertEq(nft.ownerOf(1), tester);
        assertEq(nft.ownerOf(3), tester);
        assertEq(nft.ownerOf(5), tester);
        assertEq(nft2.ownerOf(1), tester);

        assertEq(token.getDailyReward(tester), 0);
        assertEq(token.stakedIdsOf(address(nft), tester, 77).length, 0);
        assertEq(token.stakedIdsOf(address(nft2), tester, 77).length, 0);

        assertEq(address(token).balanceDiff(tester), 3 * 5e18 + 2 * 8e18);
    }

    function test_stake2() public {
        test_stake();

        resetBalance();

        test_stake_2collections();

        resetBalance();

        test_stake();

        resetBalance();

        test_stake_2collections();
    }

    function test_stake(
        uint256 amountIn,
        uint256 amountOut,
        uint256 r
    ) public {
        random.seed(r);

        amountIn = bound(amountIn, 0, 100);
        amountOut = bound(amountOut, 0, amountIn);

        uint256[] memory idsIn = 10.shuffledRange(10 + amountIn);
        uint256[] memory idsOut = idsIn.randomSubset(amountOut);

        for (uint256 i; i < amountIn; i++) nft.mint(tester, idsIn[i]);

        token.stake(address(nft), idsIn);

        assertEq(token.getDailyReward(tester), amountIn * 5e18);
        assertEq(token.stakedIdsOf(address(nft), tester, 1000), idsIn.sort());

        skip(10 days);

        token.unstake(address(nft), idsOut);

        assertEq(token.getDailyReward(tester), (amountIn - amountOut) * 5e18);
        assertEq(token.stakedIdsOf(address(nft), tester, 1000), idsIn.exclusion(idsOut).sort());
        assertEq(address(token).balanceDiff(tester), int256(amountIn) * 50e18);

        skip(10 days);

        token.unstake(address(nft), idsIn.exclusion(idsOut));

        assertEq(token.getDailyReward(tester), 0);
        assertEq(token.stakedIdsOf(address(nft), tester, 1000).length, 0);
        assertEq(address(token).balanceDiff(tester), int256(amountIn - amountOut) * 50e18);

        for (uint256 i; i < amountIn; i++) nft.burn(idsIn[i]);
    }

    function test_stake_revert_CollectionNotRegistered() public {
        MockERC721UDS nft2 = new MockERC721UDS();

        vm.expectRevert(CollectionNotRegistered.selector);

        token.stake(address(nft2), [1].toMemory());
    }

    function test_stake_revert_TransferFromIncorrectOwner() public {
        vm.expectRevert(TransferFromIncorrectOwner.selector);

        // duplicates
        token.stake(address(nft), [1, 1].toMemory());
    }

    function test_stake_revert_IncorrectOwner() public {
        token.stake(address(nft), [1, 4, 3].toMemory());

        nft.mint(alice, 10);
        nft.mint(alice, 11);

        vm.startPrank(alice);
        nft.setApprovalForAll(address(token), true);

        token.stake(address(nft), [10, 11].toMemory());

        vm.expectRevert(IncorrectOwner.selector);

        // tester's nfts
        token.unstake(address(nft), [1].toMemory());

        vm.expectRevert(IncorrectOwner.selector);

        // tester's nfts
        token.unstake(address(nft), [10, 3].toMemory());

        vm.expectRevert(IncorrectOwner.selector);

        // duplicate nfts
        token.unstake(address(nft), [10, 10].toMemory());
    }

    /* ------------- transfer() ------------- */

    function test_transfer_autoClaim() public {
        vm.expectRevert(stdError.arithmeticError);

        token.transfer(alice, 100);

        token.stake(address(nft), [1].toMemory());

        skip(1000 days);

        token.transfer(alice, 100);
    }

    /* ------------- transferFrom() ------------- */

    function test_transferFrom_autoClaim() public {
        token.approve(bob, type(uint256).max);

        vm.prank(bob);
        vm.expectRevert(stdError.arithmeticError);

        token.transferFrom(tester, alice, 100);

        token.stake(address(nft), [1].toMemory());

        skip(1000 days);

        vm.prank(bob);
        token.transferFrom(tester, alice, 100);
    }
}
