// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {MockUUPSUpgrade} from "UDS/../test/mocks/MockUUPSUpgrade.sol";
// import {ERC20Test, MockERC20UDS} from "UDS/../test/solmate/ERC20UDS.t.sol";
import {MockERC20UDS} from "UDS/../test/mocks/MockERC20UDS.sol";
import {MockERC721UDS} from "UDS/../test/mocks/MockERC721UDS.sol";

import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";

import "src/legacy/CRFTDStakingToken.sol";
import "futils/futils.sol";

error TransferFromIncorrectOwner();

contract TestCRFTDStakingToken is Test {
    using futils for *;

    address bob = makeAddr("Bob");
    address alice = makeAddr("Alice");
    address self = address(this);

    address logic;
    MockERC721UDS nft;
    CRFTDStakingTokenV1 token;

    uint256 rate = 5e18;
    uint256 rewardEndDate = block.timestamp + 1000 days;

    function setUp() public virtual {
        nft = new MockERC721UDS();

        logic = address(new CRFTDStakingTokenV1());

        bytes memory initCall = abi.encodeWithSelector(CRFTDStakingTokenV1.init.selector, "Token", "TKN");
        token = CRFTDStakingTokenV1(address(new ERC1967Proxy(logic, initCall)));

        token.setRewardEndDate(rewardEndDate);
        token.registerCollection(address(nft), 500);

        nft.mint(self, 1);
        nft.mint(self, 2);
        nft.mint(self, 3);
        nft.mint(self, 4);
        nft.mint(self, 5);

        nft.setApprovalForAll(address(token), true);

        vm.label(self, "SELF");
        vm.label(address(nft), "NFT");
        vm.label(address(token), "TKN");
    }

    /* ------------- utils ------------- */

    function resetBalance() internal {
        skip(1 days);

        token.claimReward();

        assertEq(address(token).balanceDiff(self), 0);

        token.transfer(address(0xdead), token.balanceOf(self));

        address(token).balanceDiff(self);
    }

    /* ------------- setUp() ------------- */

    function test_setUp() public {
        // token.scrambleStorage(0, 100);
        CRFTDTokenDS storage diamondStorage = s();

        bytes32 slot;

        assembly {
            slot := diamondStorage.slot
        }

        assertEq(slot, keccak256("diamond.storage.crftd.token"));
        assertEq(DIAMOND_STORAGE_CRFTD_TOKEN, keccak256("diamond.storage.crftd.token"));

        assertEq(token.name(), "Token");
        assertEq(token.symbol(), "TKN");
        assertEq(token.decimals(), 18);

        assertEq(token.rewardRate(address(nft)), 500);
        assertEq(token.rewardEndDate(), rewardEndDate);
        assertEq(token.rewardDailyRate(), 0.01e18);
    }

    /* ------------- stake() ------------- */

    function test_stake_unstake() public {
        token.stake(address(nft), [1, 4, 3].toMemory());

        skip(1 days);

        assertEq(token.ownerOf(address(nft), 1), self);
        assertEq(token.ownerOf(address(nft), 3), self);
        assertEq(token.ownerOf(address(nft), 4), self);

        assertEq(nft.ownerOf(1), address(token));
        assertEq(nft.ownerOf(3), address(token));
        assertEq(nft.ownerOf(4), address(token));

        assertEq(token.totalBalanceOf(self), 3 * 5e18);
        assertEq(token.getDailyReward(self), 3 * 5e18);
        assertEq(token.stakedIdsOf(address(nft), self, 77), [1, 3, 4].toMemory());

        assertEq(address(token).balanceDiff(self), 0);

        token.unstake(address(nft), [1, 3].toMemory());

        assertEq(token.ownerOf(address(nft), 1), address(0));
        assertEq(token.ownerOf(address(nft), 3), address(0));
        assertEq(token.ownerOf(address(nft), 4), self);

        assertEq(nft.ownerOf(1), address(self));
        assertEq(nft.ownerOf(3), address(self));
        assertEq(nft.ownerOf(4), address(token));

        assertEq(token.totalBalanceOf(self), 3 * 5e18);
        assertEq(token.getDailyReward(self), 1 * 5e18);
        assertEq(token.stakedIdsOf(address(nft), self, 77), [4].toMemory());

        assertEq(address(token).balanceDiff(self), int256(3) * 5e18);

        skip(1 days);

        token.unstake(address(nft), [4].toMemory());

        assertEq(token.ownerOf(address(nft), 1), address(0));
        assertEq(token.ownerOf(address(nft), 3), address(0));
        assertEq(token.ownerOf(address(nft), 4), address(0));

        assertEq(nft.ownerOf(1), address(self));
        assertEq(nft.ownerOf(3), address(self));
        assertEq(nft.ownerOf(4), address(self));

        assertEq(token.totalBalanceOf(self), 4 * 5e18);
        assertEq(token.getDailyReward(self), 0);
        assertEq(token.stakedIdsOf(address(nft), self, 77).length, 0);

        assertEq(address(token).balanceDiff(self), int256(1) * 5e18);
    }

    function test_stake_2collections() public {
        token.stake(address(nft), [1, 3, 5].toMemory());

        // register second collection
        MockERC721UDS nft2 = new MockERC721UDS();

        nft2.mint(self, 1);
        nft2.mint(self, 2);
        nft2.setApprovalForAll(address(token), true);

        token.registerCollection(address(nft2), 800);
        token.stake(address(nft2), [1, 2].toMemory());

        assertEq(token.ownerOf(address(nft), 1), self);
        assertEq(token.ownerOf(address(nft), 3), self);
        assertEq(token.ownerOf(address(nft), 5), self);
        assertEq(token.ownerOf(address(nft2), 1), self);
        assertEq(token.ownerOf(address(nft2), 2), self);

        assertEq(nft.ownerOf(1), address(token));
        assertEq(nft.ownerOf(3), address(token));
        assertEq(nft.ownerOf(5), address(token));
        assertEq(nft2.ownerOf(1), address(token));

        assertEq(token.getDailyReward(self), 3 * 5e18 + 2 * 8e18);

        skip(1 days);

        token.unstake(address(nft2), [2, 1].toMemory());
        token.unstake(address(nft), [1, 3, 5].toMemory());

        assertEq(nft.ownerOf(1), self);
        assertEq(nft.ownerOf(3), self);
        assertEq(nft.ownerOf(5), self);
        assertEq(nft2.ownerOf(1), self);

        assertEq(token.getDailyReward(self), 0);
        assertEq(token.stakedIdsOf(address(nft), self, 77).length, 0);
        assertEq(token.stakedIdsOf(address(nft2), self, 77).length, 0);

        assertEq(address(token).balanceDiff(self), 3 * 5e18 + 2 * 8e18);
    }

    function test_stake_unstake_multiple_times() public {
        test_stake_unstake();

        resetBalance();

        test_stake_2collections();

        resetBalance();

        test_stake_unstake();

        resetBalance();

        test_stake_2collections();
    }

    function test_stake(uint256 amountIn, uint256 amountOut, uint256 r) public {
        random.seed(r);

        amountIn = bound(amountIn, 0, 20);
        amountOut = bound(amountOut, 0, amountIn);

        uint256[] memory idsIn = 10.shuffledRange(10 + amountIn);
        uint256[] memory idsOut = idsIn.randomSubset(amountOut);

        for (uint256 i; i < amountIn; i++) {
            nft.mint(self, idsIn[i]);
        }

        token.stake(address(nft), idsIn);

        assertEq(token.getDailyReward(self), amountIn * 5e18);
        assertEq(token.stakedIdsOf(address(nft), self, 1000), idsIn.sort());

        skip(10 days);

        token.unstake(address(nft), idsOut);

        assertEq(token.getDailyReward(self), (amountIn - amountOut) * 5e18);
        assertEq(token.stakedIdsOf(address(nft), self, 1000), idsIn.exclusion(idsOut).sort());
        assertEq(address(token).balanceDiff(self), int256(amountIn) * 50e18);

        skip(10 days);

        token.unstake(address(nft), idsIn.exclusion(idsOut));

        assertEq(token.getDailyReward(self), 0);
        assertEq(token.stakedIdsOf(address(nft), self, 1000).length, 0);
        assertEq(address(token).balanceDiff(self), int256(amountIn - amountOut) * 50e18);

        for (uint256 i; i < amountIn; i++) {
            nft.burn(idsIn[i]);
        }
    }

    function test_stake_revert_CollectionNotRegistered() public {
        MockERC721UDS nft2 = new MockERC721UDS();

        nft2.mint(self, 1);
        nft2.setApprovalForAll(address(token), true);

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

        // self's nfts
        token.unstake(address(nft), [1].toMemory());

        vm.expectRevert(IncorrectOwner.selector);

        // self's nfts
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

        token.transferFrom(self, alice, 100);

        token.stake(address(nft), [1].toMemory());

        skip(1000 days);

        vm.prank(bob);
        token.transferFrom(self, alice, 100);
    }
}
