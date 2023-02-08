// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CRFTDStakingTokenV1} from "src/legacy/CRFTDStakingToken.sol";
import {CRFTDStakingToken as CRFTDStakingTokenRoot} from "src/CRFTDStakingTokenRoot.sol";
import {CRFTDStakingToken as CRFTDStakingTokenChild} from "src/CRFTDStakingTokenChild.sol";

import "src/CRFTDStakingTokenRoot.sol" as RootErrors;
import "src/CRFTDStakingTokenChild.sol" as ChildErrors;
import "src/CRFTDStakingTokenChild.sol";

import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";
import {MockERC20UDS} from "UDS/../test/mocks/MockERC20UDS.sol";
import {MockERC721UDS} from "UDS/../test/mocks/MockERC721UDS.sol";

import {MockFxTunnel} from "./mocks/MockFxTunnel.sol";
import {TestCRFTDStakingToken} from "./CRFTDStakingToken.t.sol";

import "forge-std/Test.sol";
import "futils/futils.sol";

contract TestV1CRFTDStakingTokenV2 is TestCRFTDStakingToken {
    function setUp() public virtual override {
        super.setUp();

        logic = address(new CRFTDStakingTokenRoot(address(0), address(0)));

        bytes memory initCall = abi.encodeWithSelector(CRFTDStakingTokenRoot.init.selector, "Token", "TKN");
        token = CRFTDStakingTokenV1(address(new ERC1967Proxy(logic, initCall)));

        token.setRewardEndDate(rewardEndDate);
        token.registerCollection(address(nft), 500);

        nft.setApprovalForAll(address(token), true);

        vm.label(address(token), "TKN");
    }
}

contract TestCRFTDStakingTokenV2 is TestCRFTDStakingToken {
    using futils for *;

    address logicV2;
    address logicChild;

    MockCRFTDStakingTokenRoot tokenRoot;
    CRFTDStakingTokenChild tokenChild;

    address fxTunnel;

    function setUp() public override {
        TestCRFTDStakingToken.setUp();

        fxTunnel = address(new MockFxTunnel());

        logicV2 = address(new MockCRFTDStakingTokenRoot(address(0), fxTunnel));
        logicChild = address(new CRFTDStakingTokenChild(fxTunnel));

        bytes memory initCall = abi.encodeWithSelector(CRFTDStakingTokenChild.init.selector, "TokenChild", "TKNCHLD");
        tokenChild = CRFTDStakingTokenChild(address(new ERC1967Proxy(logicChild, initCall)));
        tokenChild.setFxRootTunnel(address(token));

        tokenChild.setRewardEndDate(rewardEndDate);
        tokenChild.registerCollection(address(nft), 500);

        vm.label(address(nft), "nftRoot");
        vm.label(address(token), "tokenV1");
        vm.label(address(fxTunnel), "fxTunnel");
        vm.label(address(tokenChild), "tokenChild");
    }

    function upgradeToken() internal {
        token.upgradeToAndCall(logicV2, "");

        tokenRoot = MockCRFTDStakingTokenRoot(address(token));

        vm.label(address(token), "tokenV2Root");
    }

    /* ------------- setUp() ------------- */

    function test_setUpV2() public {
        upgradeToken();

        test_setUp();

        CRFTDTokenChildDS storage diamondStorage = s();

        bytes32 slot;

        assembly {
            slot := diamondStorage.slot
        }

        assertEq(slot, keccak256("diamond.storage.crftd.token.child"));
        assertEq(DIAMOND_STORAGE_CRFTD_TOKEN_CHILD, keccak256("diamond.storage.crftd.token.child"));

        assertEq(tokenChild.name(), "TokenChild");
        assertEq(tokenChild.symbol(), "TKNCHLD");
        assertEq(tokenChild.decimals(), 18);

        assertEq(tokenChild.rewardRate(address(nft)), 500);
        assertEq(tokenChild.rewardEndDate(), rewardEndDate);
        assertEq(tokenChild.rewardDailyRate(), 0.01e18);
    }

    /* ------------- stake() ------------- */

    function test_stakeV2() public {
        test_stake_unstake_multiple_times();

        upgradeToken();

        skip(5 days);

        resetBalance();

        test_stake_unstake_multiple_times();
    }

    function test_stakeV2(uint256 amountIn, uint256 amountOut, uint256 r) public {
        amountIn = bound(amountIn, 0, 20);

        test_stake(amountIn, amountOut, r);

        upgradeToken();
        skip(5 days);
        resetBalance();

        test_stake(amountIn, amountOut, random.next());
    }

    function test_setSpecialRewardRate() public {
        upgradeToken();

        tokenRoot.startMigration(address(tokenChild));
        tokenChild.setSpecialRewardRate(address(nft), [1].toMemory(), [7700].toMemory());
        tokenRoot.stake(address(nft), [1, 3, 4].toMemory());

        assertEq(tokenChild.getDailyReward(self), 2 * 5e18 + 77e18);
    }

    function test_setSpecialRewardRate2() public {
        upgradeToken();

        tokenRoot.startMigration(address(tokenChild));
        tokenRoot.stake(address(nft), [1, 3, 4].toMemory());
        tokenChild.setSpecialRewardRate(address(nft), [1].toMemory(), [7700].toMemory());

        assertEq(tokenChild.getDailyReward(self), 2 * 5e18 + 77e18);
    }

    /* ------------- migration() ------------- */

    uint256 constant MIGRATION_START_DATE = (1 << 42) - 1;

    function test_safeMigrate() public {
        token.stake(address(nft), [1, 4, 3].toMemory());

        skip(5 days);

        upgradeToken();

        tokenRoot.startMigration(address(tokenChild));

        assertEq(tokenRoot.fxChildTunnel(), address(tokenChild));
        assertEq(tokenRoot.rewardEndDate(), MIGRATION_START_DATE);

        uint256[][] memory ids = new uint256[][](1);
        ids[0] = tokenRoot.stakedIdsOf(address(nft), self, 77);

        uint256 migratedBalance = tokenRoot.totalBalanceOf(self);
        assertGt(migratedBalance, 0);

        tokenRoot.safeMigrate([address(nft)].toMemory(), ids);

        skip(10 days);

        assertEq(tokenRoot.balanceOf(self), 0);
        assertEq(tokenRoot.totalBalanceOf(self), 0);
        assertEq(tokenRoot.getDailyReward(self), 0);

        assertEq(tokenRoot.ownerOf(address(nft), 1), self);
        assertEq(tokenRoot.ownerOf(address(nft), 3), self);
        assertEq(tokenRoot.ownerOf(address(nft), 4), self);

        assertEq(tokenChild.ownerOf(address(nft), 1), self);
        assertEq(tokenChild.ownerOf(address(nft), 3), self);
        assertEq(tokenChild.ownerOf(address(nft), 4), self);

        assertEq(tokenChild.balanceOf(self), migratedBalance);
        assertEq(tokenChild.totalBalanceOf(self), migratedBalance + 10 * ids[0].length * 5e18);
        assertEq(tokenChild.getDailyReward(self), ids[0].length * 5e18);
    }

    /// user has already migrated and migrates further balances
    function test_safeMigrate2() public {
        test_safeMigrate();

        skip(10 days);

        address(tokenChild).balanceDiff(self);

        tokenRoot.safeMigrate(new address[](0), new uint256[][](0));

        assertEq(tokenRoot.balanceOf(self), 0);
        assertEq(tokenRoot.totalBalanceOf(self), 0);

        assertEq(address(tokenChild).balanceDiff(self), 0);

        skip(10 days);

        tokenRoot.mint(self, 333e18);
        tokenRoot.safeMigrate(new address[](0), new uint256[][](0));

        assertEq(tokenRoot.balanceOf(self), 0);
        assertEq(tokenRoot.totalBalanceOf(self), 0);

        assertEq(address(tokenChild).balanceDiff(self), 333e18);

        assertEq(tokenRoot.ownerOf(address(nft), 1), self);
        assertEq(tokenRoot.ownerOf(address(nft), 3), self);
        assertEq(tokenRoot.ownerOf(address(nft), 4), self);

        assertEq(tokenChild.ownerOf(address(nft), 1), self);
        assertEq(tokenChild.ownerOf(address(nft), 3), self);
        assertEq(tokenChild.ownerOf(address(nft), 4), self);
    }

    /// user has already migrated and migrates further balances
    function test_safeMigrate_balance_only() public {
        token.airdrop([self].toMemory(), [uint256(100e18)].toMemory());

        upgradeToken();

        tokenRoot.startMigration(address(tokenChild));

        address(token).balanceDiff(self);
        address(tokenChild).balanceDiff(self);

        tokenRoot.safeMigrate(new address[](0), new uint256[][](0));

        assertEq(tokenRoot.balanceOf(self), 0);
        assertEq(tokenRoot.totalBalanceOf(self), 0);

        assertEq(address(token).balanceDiff(self), -100e18);
        assertEq(address(tokenChild).balanceDiff(self), 100e18);
    }

    /// user migrates with incomplete ids
    function test_safeMigrate_revert_MigrationIncomplete() public {
        token.stake(address(nft), [1, 3, 4].toMemory());

        upgradeToken();

        tokenRoot.startMigration(address(tokenChild));

        uint256[][] memory ids = new uint256[][](1);
        ids[0] = [1, 4].toMemory();

        vm.expectRevert(RootErrors.MigrationIncomplete.selector);
        tokenRoot.safeMigrate([address(nft)].toMemory(), ids);
    }

    /// user has already migrated and tries safe migrate again
    function test_safeMigrate_revert_MigrationIncomplete2() public {
        test_safeMigrate();

        uint256[][] memory ids = new uint256[][](1);
        ids[0] = [1].toMemory();

        vm.expectRevert(RootErrors.MigrationIncomplete.selector);
        tokenRoot.safeMigrate([address(nft)].toMemory(), ids);
    }

    function test_safeMigrate_guard_exploit() public {
        token.stake(address(nft), [1, 3, 4].toMemory());

        upgradeToken();

        tokenRoot.startMigration(address(tokenChild));

        uint256[][] memory ids = new uint256[][](1);
        ids[0] = [1, 1, 1].toMemory();

        tokenRoot.safeMigrate([address(nft)].toMemory(), ids);

        skip(10 days);

        assertEq(tokenRoot.ownerOf(address(nft), 1), self);
        assertEq(tokenRoot.ownerOf(address(nft), 3), self);
        assertEq(tokenRoot.ownerOf(address(nft), 4), self);

        assertEq(tokenChild.ownerOf(address(nft), 1), self);
        assertEq(tokenChild.ownerOf(address(nft), 3), address(0));
        assertEq(tokenChild.ownerOf(address(nft), 4), address(0));
    }

    function test_safeMigrate_revert_MigrationNotStarted() public {
        upgradeToken();

        vm.expectRevert(RootErrors.MigrationNotStarted.selector);

        tokenRoot.safeMigrate(new address[](0), new uint256[][](0));
    }

    function test_synchronizeIdsWithChild_revert_MigrationNotStarted() public {
        upgradeToken();

        vm.expectRevert(RootErrors.MigrationNotStarted.selector);

        tokenRoot.synchronizeIdsWithChild(new address[](0), new uint256[][](0));
    }

    function test_revert_MigrationRequired() public {
        token.stake(address(nft), [1].toMemory());

        skip(10 days);

        upgradeToken();

        tokenRoot.startMigration(address(tokenChild));

        vm.expectRevert(RootErrors.MigrationRequired.selector);
        tokenRoot.stake(address(nft), [2].toMemory());

        vm.expectRevert(RootErrors.MigrationRequired.selector);
        tokenRoot.unstake(address(nft), [1].toMemory());

        vm.expectRevert(RootErrors.MigrationRequired.selector);
        tokenRoot.synchronizeIdsWithChild(new address[](0), new uint256[][](0));
    }
}

contract MockCRFTDStakingTokenRoot is CRFTDStakingTokenRoot {
    constructor(address checkpointManager, address fxRoot) CRFTDStakingTokenRoot(checkpointManager, fxRoot) {}

    function burn(address from, uint256 value) public {
        _burn(from, value);
    }

    function mint(address to, uint256 quantity) public {
        _mint(to, quantity);
    }
}
